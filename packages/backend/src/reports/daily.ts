/** 成刊：日报 / 周报 / 月报 共用一套流水线。
 *  时间窗内的入选单集 → 主编 prompt 生成刊头 → 分节结构化落库。
 *  content JSON：{ title, leadParagraph, highlights[], sections[{section, items[]}], stats }
 *  - 日报 report_key = 'YYYY-MM-DD'（昨天）
 *  - 周报 report_key = 覆盖周的周一 'YYYY-MM-DD'（上周一）
 *  - 月报 report_key = 'YYYY-MM'（上个月） */

import { z } from 'zod';

import { SELECTION, SITE, categoryLabel, sectionOrderFor } from '@sonde/industry';
import { promptsDir } from '@sonde/industry/paths';

import { loadConfig } from '../config.ts';
import { row, rows, sql } from '../db/db.ts';
import { loadPromptFiles } from '../prompts/loader.ts';
import { renderPrompt } from '../prompts/renderer.ts';
import { chatJson } from '../providers/llm.ts';
import {
  dayWindowUtc,
  lastMonthKeyInTz,
  lastWeekMondayKeyInTz,
  monthWindowUtc,
  weekWindowUtc,
  yesterdayKeyInTz,
} from '../util/time.ts';

export type ReportKind = 'daily' | 'weekly' | 'monthly';

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

interface KindSpec {
  prompt: string;
  maxItems: number;
  /** key 格式校验（周报额外要求是周一，见 weekWindowUtc） */
  keyRe: RegExp;
  /** 缺省 reportKey：昨天 / 上周一 / 上个月 */
  defaultKey: (now: Date, timeZone: string) => string;
  window: (key: string, timeZone: string) => { start: Date; end: Date };
  /** prompt 里的时间范围描述，如「9月21日–9月27日」 */
  rangeLabel: (key: string) => string;
}

const KINDS: Record<ReportKind, KindSpec> = {
  daily: {
    prompt: 'report-daily-lead',
    maxItems: SELECTION.maxReportItems,
    keyRe: /^\d{4}-\d{2}-\d{2}$/,
    defaultKey: yesterdayKeyInTz,
    window: dayWindowUtc,
    rangeLabel: (key) => key,
  },
  weekly: {
    prompt: 'report-weekly-lead',
    maxItems: SELECTION.maxWeeklyItems,
    keyRe: /^\d{4}-\d{2}-\d{2}$/,
    defaultKey: lastWeekMondayKeyInTz,
    window: weekWindowUtc,
    rangeLabel: (key) => {
      const [, end] = weekRange(key);
      return `${zhMonthDay(key)}–${zhMonthDay(end)}`;
    },
  },
  monthly: {
    prompt: 'report-monthly-lead',
    maxItems: SELECTION.maxMonthlyItems,
    keyRe: /^\d{4}-\d{2}$/,
    defaultKey: lastMonthKeyInTz,
    window: monthWindowUtc,
    rangeLabel: (key) => {
      const [y, m] = key.split('-').map((part) => Number.parseInt(part, 10));
      return `${y} 年 ${m} 月`;
    },
  },
};

export function isReportKind(value: string): value is ReportKind {
  return value === 'daily' || value === 'weekly' || value === 'monthly';
}

export interface ReportOptions {
  /** 日报/周报 'YYYY-MM-DD'（周报须为周一）、月报 'YYYY-MM'；缺省为上一期 */
  reportKey?: string;
  /** true = 已存在也重新生成（修订+1）；false = 已存在则跳过（catch-up 语义） */
  force?: boolean;
}

export async function generateReport(
  kind: ReportKind,
  options: ReportOptions = {},
): Promise<{
  reportKey: string;
  created: boolean;
  skipped?: string;
}> {
  const config = loadConfig();
  const spec = KINDS[kind];
  const reportKey = options.reportKey ?? spec.defaultKey(new Date(), config.reportTimezone);
  if (!spec.keyRe.test(reportKey)) {
    throw new Error(`invalid ${kind} report key: ${reportKey}`);
  }
  const { start, end } = spec.window(reportKey, config.reportTimezone);

  const existing = await row<{ revision: number }>(sql`
    SELECT revision FROM daily_reports WHERE kind = ${kind} AND report_key = ${reportKey}
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
    LIMIT ${spec.maxItems}
  `);

  if (candidates.length === 0) {
    console.log(`[report] ${kind} ${reportKey}: no selected episodes, skip`);
    return { reportKey, created: false, skipped: 'no candidates' };
  }

  // 刊头（主编 prompt）
  const files = loadPromptFiles(promptsDir);
  const lead = renderPrompt(files, spec.prompt, {
    siteName: SITE.name,
    subject: SITE.subject,
    dateKey: reportKey,
    rangeLabel: spec.rangeLabel(reportKey),
    items: candidates.map((c, i) => `${i + 1}. 【${categoryLabel(c.category)}】${c.title_zh}\n   摘要：${c.summary_zh}\n   推荐理由：${c.reason_zh}`).join('\n'),
  });
  const head = await chatJson<z.infer<typeof leadSchema>>({
    system: '你是严谨的中文报刊主编，只输出 JSON。',
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
    stats: { selected: candidates.length, maxItems: spec.maxItems },
  };

  await rows(sql`
    INSERT INTO daily_reports (kind, report_key, window_start, window_end, content, model, revision, generated_at)
    VALUES (${kind}, ${reportKey}, ${start}, ${end}, ${JSON.stringify(content)}::jsonb, ${head.model}, 1, now())
    ON CONFLICT (kind, report_key) DO UPDATE
    SET content = EXCLUDED.content,
        model = EXCLUDED.model,
        revision = daily_reports.revision + 1,
        window_start = EXCLUDED.window_start,
        window_end = EXCLUDED.window_end,
        generated_at = now()
  `);

  console.log(`[report] ${kind} ${reportKey}: ${candidates.length} items, title="${head.data.title}"`);
  return { reportKey, created: true };
}

/** 兼容旧名：日报生成。 */
export function generateDailyReport(options: ReportOptions = {}) {
  return generateReport('daily', options);
}

export interface ReportRow {
  reportKey: string;
  generatedAt: Date;
  revision: number;
  content: unknown;
}

export async function getReport(kind: ReportKind, reportKey: string): Promise<ReportRow | null> {
  return row(sql`
    SELECT report_key AS "reportKey", generated_at AS "generatedAt",
           revision, content
    FROM daily_reports
    WHERE kind = ${kind} AND report_key = ${reportKey}
  `);
}

export async function getLatestReport(kind: ReportKind): Promise<ReportRow | null> {
  return row(sql`
    SELECT report_key AS "reportKey", generated_at AS "generatedAt",
           revision, content
    FROM daily_reports
    WHERE kind = ${kind}
    ORDER BY report_key DESC
    LIMIT 1
  `);
}

export async function listReportKeys(
  kind: ReportKind,
  page = 1,
  size = 30,
): Promise<{
  keys: { reportKey: string; generatedAt: Date; revision: number }[];
  total: number;
}> {
  const safePage = Math.max(1, page);
  const safeSize = Math.min(Math.max(1, size), 100);
  const total = (await row<{ count: number }>(sql`
    SELECT count(*)::int AS count FROM daily_reports WHERE kind = ${kind}
  `))?.count ?? 0;
  const keys = await rows<{ reportKey: string; generatedAt: Date; revision: number }>(sql`
    SELECT report_key AS "reportKey", generated_at AS "generatedAt", revision
    FROM daily_reports
    WHERE kind = ${kind}
    ORDER BY report_key DESC
    LIMIT ${safeSize} OFFSET ${(safePage - 1) * safeSize}
  `);
  return { keys, total };
}

/** 周报 key（周一）→ [起, 止] 的日期 key（纯日期数学，与时区无关）。 */
function weekRange(mondayKey: string): [string, string] {
  const [y, m, d] = mondayKey.split('-').map((part) => Number.parseInt(part, 10));
  const noon = Date.UTC((y as number), (m as number) - 1, (d as number)) + 12 * 60 * 60 * 1000;
  const startKey = ymd(new Date(noon));
  const endKey = ymd(new Date(noon + 6 * 24 * 60 * 60 * 1000));
  return [startKey, endKey];
}

function ymd(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** 'YYYY-MM-DD' → 'M月D日'（去掉前导零）。 */
function zhMonthDay(key: string): string {
  const [, m, d] = key.split('-').map((part) => Number.parseInt(part, 10));
  return `${m}月${d}日`;
}
