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
