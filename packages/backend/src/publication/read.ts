/** 站点读层：web 唯一的数据出口（精选时间线、单集详情、日报读取）。 */

import { categoryLabel } from '@sonde/industry';

import { row, rows, sql } from '../db/db.ts';

export interface SelectedEpisodeItem {
  id: number;
  podcast: string;
  originalTitle: string;
  titleZh: string;
  summaryZh: string;
  reasonZh: string;
  category: string;
  categoryLabel: string;
  score: number;
  url: string | null;
  publishedAt: Date | null;
  durationSeconds: number | null;
}

export async function listSelectedEpisodes(limit = 20): Promise<SelectedEpisodeItem[]> {
  const safeLimit = Math.min(Math.max(limit, 1), 100);
  const result = await rows(sql`
    SELECT e.id, s.name AS podcast, e.title AS original_title, e.url,
           e.published_at AS "publishedAt", e.duration_seconds AS "durationSeconds",
           a.title_zh, a.summary_zh, a.reason_zh, a.category, a.score
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    JOIN analyses a ON a.episode_id = e.id AND a.is_current AND a.selected
    WHERE e.published_at IS NOT NULL
    ORDER BY e.published_at DESC, e.id DESC
    LIMIT ${safeLimit}
  `);
  return result.map((r: Record<string, unknown>) => toEpisodeItem(r));
}

export async function getSelectedEpisode(episodeId: number): Promise<SelectedEpisodeItem | null> {
  const result = await row(sql`
    SELECT e.id, s.name AS podcast, e.title AS original_title, e.url,
           e.published_at AS "publishedAt", e.duration_seconds AS "durationSeconds",
           a.title_zh, a.summary_zh, a.reason_zh, a.category, a.score
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    JOIN analyses a ON a.episode_id = e.id AND a.is_current AND a.selected
    WHERE e.id = ${episodeId}
  `);
  return result ? toEpisodeItem(result as Record<string, unknown>) : null;
}

export interface AnalyzedEpisodeItem extends SelectedEpisodeItem {
  /** 评分理由（入选与落选均写；未入选单集没有 titleZh/summaryZh） */
  reason: string;
  selected: boolean;
}

/** 全部动态：所有已完成分析的单集（含未入选），按发布时间倒序。 */
export async function listAllAnalyzedEpisodes(
  limit = 50,
  offset = 0,
): Promise<{ items: AnalyzedEpisodeItem[]; total: number }> {
  const safeLimit = Math.min(Math.max(limit, 1), 100);
  const safeOffset = Math.max(offset, 0);

  const total = (await row<{ count: number }>(sql`
    SELECT count(*)::int AS count
    FROM episodes e
    JOIN analyses a ON a.episode_id = e.id AND a.is_current
    WHERE e.published_at IS NOT NULL
  `))?.count ?? 0;

  const result = await rows(sql`
    SELECT e.id, s.name AS podcast, e.title AS original_title, e.url,
           e.published_at AS "publishedAt", e.duration_seconds AS "durationSeconds",
           a.title_zh, a.summary_zh, a.reason_zh, a.category, a.score,
           a.reason, a.selected
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    JOIN analyses a ON a.episode_id = e.id AND a.is_current
    WHERE e.published_at IS NOT NULL
    ORDER BY e.published_at DESC, e.id DESC
    LIMIT ${safeLimit} OFFSET ${safeOffset}
  `);

  const items = result.map((r: Record<string, unknown>) => ({
    ...toEpisodeItem(r),
    reason: (r.reason as string) ?? '',
    selected: Boolean(r.selected),
  }));
  return { items, total };
}

function toEpisodeItem(r: Record<string, unknown>): SelectedEpisodeItem {
  const category = (r.category as string | null) ?? 'general';
  return {
    id: r.id as number,
    podcast: (r.podcast as string) ?? '',
    originalTitle: (r.original_title as string) ?? '',
    titleZh: (r.title_zh as string) ?? '',
    summaryZh: (r.summary_zh as string) ?? '',
    reasonZh: (r.reason_zh as string) ?? '',
    category,
    categoryLabel: categoryLabel(category),
    score: r.score as number,
    url: (r.url as string | null) ?? null,
    publishedAt: (r.publishedAt as Date | null) ?? null,
    durationSeconds: (r.durationSeconds as number | null) ?? null,
  };
}
