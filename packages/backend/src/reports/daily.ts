/** 日报成刊：昨日（REPORT_TIMEZONE 日历）入选单集 → 主编 prompt 生成刊头 → 结构化落库。
 *  content JSON：{ title, leadParagraph, highlights[], sections[{section, items[]}], stats } */

import { z } from 'zod';

import { SELECTION, SITE, categoryLabel, sectionOrderFor } from '@sonde/industry';
import { promptsDir } from '@sonde/industry/paths';

import { loadConfig } from '../config.ts';
import { row, rows, sql } from '../db/db.ts';
import { loadPromptFiles } from '../prompts/loader.ts';
import { renderPrompt } from '../prompts/renderer.ts';
import { chatJson } from '../providers/llm.ts';
import { dayWindowUtc, yesterdayKeyInTz } from '../util/time.ts';

const leadSchema = z.object({
  title: z.string().min(1),
  leadParagraph: z.string().min(1),
  highlights: z.array(z.string()).min(1).max(8),
});

interface SelectedEpisode {
  episode_id: number;
  podcast_name: string;
  original_title: string;
  title_zh: string;
  summary_zh: string;
  reason_zh: string;
  category: string;
  score: number;
  url: string | null;
  published_at: Date | null;
  duration_seconds: number | null;
}

export interface DailyReportOptions {
  /** YYYY-MM-DD（REPORT_TIMEZONE 日历）；缺省为昨天 */
  reportKey?: string;
  /** true = 已存在也重新生成（修订+1）；false = 已存在则跳过（catch-up 语义） */
  force?: boolean;
}

export async function generateDailyReport(options: DailyReportOptions = {}): Promise<{
  reportKey: string;
  created: boolean;
  skipped?: string;
}> {
  const config = loadConfig();
  const reportKey = options.reportKey ?? yesterdayKeyInTz(new Date(), config.reportTimezone);
  const { start, end } = dayWindowUtc(reportKey, config.reportTimezone);

  const existing = await row<{ revision: number }>(sql`
    SELECT revision FROM daily_reports WHERE kind = 'daily' AND report_key = ${reportKey}
  `);
  if (existing && !options.force) {
    return { reportKey, created: false, skipped: 'already exists' };
  }

  const candidates = await rows<SelectedEpisode>(sql`
    SELECT e.id AS episode_id, s.name AS podcast_name, e.title AS original_title,
           a.title_zh, a.summary_zh, a.reason_zh, a.category, a.score,
           e.url, e.published_at, e.duration_seconds
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    JOIN analyses a ON a.episode_id = e.id AND a.is_current AND a.selected
    WHERE e.published_at >= ${start} AND e.published_at < ${end}
    ORDER BY a.score DESC, e.published_at ASC
    LIMIT ${SELECTION.maxReportItems}
  `);

  if (candidates.length === 0) {
    console.log(`[report] ${reportKey}: no selected episodes, skip`);
    return { reportKey, created: false, skipped: 'no candidates' };
  }

  // 刊头（主编 prompt）
  const files = loadPromptFiles(promptsDir);
  const lead = renderPrompt(files, 'report-daily-lead', {
    siteName: SITE.name,
    subject: SITE.subject,
    dateKey: reportKey,
    items: candidates.map((c, i) => `${i + 1}. 【${categoryLabel(c.category)}】${c.title_zh}\n   摘要：${c.summary_zh}\n   推荐理由：${c.reason_zh}`).join('\n'),
  });
  const head = await chatJson<z.infer<typeof leadSchema>>({
    system: '你是严谨的中文日报主编，只输出 JSON。',
    user: lead.text,
    operation: 'report',
    schema: leadSchema,
  });

  // 分节（taxonomy section 排序）
  const sections = sectionOrderFor(candidates.map((c) => c.category)).map(({ section, categories }) => ({
    section,
    items: candidates
      .filter((c) => categories.includes(c.category))
      .map((c) => ({
        episodeId: c.episode_id,
        podcast: c.podcast_name,
        originalTitle: c.original_title,
        titleZh: c.title_zh,
        summaryZh: c.summary_zh,
        reasonZh: c.reason_zh,
        category: c.category,
        categoryLabel: categoryLabel(c.category),
        score: c.score,
        url: c.url,
        publishedAt: c.published_at,
        durationSeconds: c.duration_seconds,
      })),
  })).filter((s) => s.items.length > 0);

  const content = {
    title: head.data.title,
    leadParagraph: head.data.leadParagraph,
    highlights: head.data.highlights,
    sections,
    stats: { selected: candidates.length, maxItems: SELECTION.maxReportItems },
  };

  await rows(sql`
    INSERT INTO daily_reports (kind, report_key, window_start, window_end, content, model, revision, generated_at)
    VALUES ('daily', ${reportKey}, ${start}, ${end}, ${JSON.stringify(content)}::jsonb, ${head.model}, 1, now())
    ON CONFLICT (kind, report_key) DO UPDATE
      SET content = EXCLUDED.content,
          model = EXCLUDED.model,
          revision = daily_reports.revision + 1,
          window_start = EXCLUDED.window_start,
          window_end = EXCLUDED.window_end,
          generated_at = now()
  `);

  console.log(`[report] ${reportKey}: ${candidates.length} items, title="${head.data.title}"`);
  return { reportKey, created: true };
}

export async function getDailyReport(reportKey: string): Promise<{
  reportKey: string;
  generatedAt: Date;
  revision: number;
  content: unknown;
} | null> {
  return row(sql`
    SELECT report_key AS "reportKey", generated_at AS "generatedAt",
           revision, content
    FROM daily_reports
    WHERE kind = 'daily' AND report_key = ${reportKey}
  `);
}

export async function getLatestDailyReport(): Promise<{
  reportKey: string;
  generatedAt: Date;
  revision: number;
  content: unknown;
} | null> {
  return row(sql`
    SELECT report_key AS "reportKey", generated_at AS "generatedAt",
           revision, content
    FROM daily_reports
    WHERE kind = 'daily'
    ORDER BY report_key DESC
    LIMIT 1
  `);
}

export async function listDailyReportKeys(page = 1, size = 30): Promise<{
  keys: { reportKey: string; generatedAt: Date; revision: number }[];
  total: number;
}> {
  const safePage = Math.max(1, page);
  const safeSize = Math.min(Math.max(1, size), 100);
  const total = (await row<{ count: number }>(sql`
    SELECT count(*)::int AS count FROM daily_reports WHERE kind = 'daily'
  `))?.count ?? 0;
  const keys = await rows<{ reportKey: string; generatedAt: Date; revision: number }>(sql`
    SELECT report_key AS "reportKey", generated_at AS "generatedAt", revision
    FROM daily_reports
    WHERE kind = 'daily'
    ORDER BY report_key DESC
    LIMIT ${safeSize} OFFSET ${(safePage - 1) * safeSize}
  `);
  return { keys, total };
}
