/** 单集分析：评分（全部）→（过 tier 门槛）写作。结果追加进 analyses，当前判定 is_current=true。 */

import { z } from 'zod';

import { CATEGORIES, DEFAULT_CATEGORY, SELECTION, SITE, thresholdFor } from '@sonde/industry';
import { promptsDir } from '@sonde/industry/paths';

import { row, rows, sql, withTx } from '../db/db.ts';
import { loadPromptFiles } from '../prompts/loader.ts';
import { renderPrompt } from '../prompts/renderer.ts';
import { chatJson } from '../providers/llm.ts';

const scoringSchema = z.object({
  score: z.coerce.number().int().min(0).max(100),
  reason: z.string().min(1),
  category: z.string(),
  tags: z.array(z.string()).default([]),
});

const writingSchema = z.object({
  titleZh: z.string().min(1),
  summaryZh: z.string().min(1),
  reasonZh: z.string().min(1),
});

/** 评分材料中的转录截断（评分不需要全文，控制 token 成本） */
const SCORING_TRANSCRIPT_LIMIT = 10_000;
/** 写作时的转录截断（需要更完整的上下文） */
const WRITING_TRANSCRIPT_LIMIT = 30_000;

interface EpisodeForAnalysis {
  id: number;
  title: string;
  shownotes: string | null;
  duration_seconds: number | null;
  published_at: Date | null;
  body_text: string | null;
  body_status: string;
  podcast_name: string;
  tier: string;
}

export async function analyzeEpisode(episodeId: number): Promise<{ selected: boolean; score: number }> {
  const episode = await row<EpisodeForAnalysis>(sql`
    SELECT e.id, e.title, e.shownotes, e.duration_seconds, e.published_at,
           e.body_text, e.body_status,
           s.name AS podcast_name, s.tier
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    WHERE e.id = ${episodeId}
  `);
  if (!episode) {
    console.warn(`[analyze] episode ${episodeId} not found`);
    return { selected: false, score: 0 };
  }
  if (episode.body_status !== 'ok' || !episode.body_text) {
    console.warn(`[analyze] episode ${episodeId} has no transcript (body_status=${episode.body_status})`);
    return { selected: false, score: 0 };
  }

  const files = loadPromptFiles(promptsDir);
  const interestProfile = SELECTION.interestProfile.trim() || '（未配置，按通用重度播客听众评估）';

  // ① 评分
  const scoring = renderPrompt(files, 'scoring', {
    siteName: SITE.name,
    interestProfile,
    categories: CATEGORIES.map((c) => `${c.key}=${c.label}`).join('\n'),
    episode: buildEpisodeMaterial(episode, SCORING_TRANSCRIPT_LIMIT),
  });
  const scored = await chatJson<z.infer<typeof scoringSchema>>({
    system: '你是严谨的播客内容主编，只输出 JSON。',
    user: scoring.text,
    operation: 'score',
    schema: scoringSchema,
  });

  const category = CATEGORIES.some((c) => c.key === scored.data.category)
    ? scored.data.category
    : DEFAULT_CATEGORY;
  const threshold = thresholdFor(episode.tier);
  const selected = scored.data.score >= threshold;

  // ② 过门槛才写作
  let written: z.infer<typeof writingSchema> | null = null;
  let writingVersion: string | null = null;
  if (selected) {
    const writing = renderPrompt(files, 'writing', {
      siteName: SITE.name,
      interestProfile,
      podcast: episode.podcast_name,
      title: episode.title,
      transcript: clip(episode.body_text, WRITING_TRANSCRIPT_LIMIT),
    });
    const writtenResult = await chatJson<z.infer<typeof writingSchema>>({
      system: '你是严谨的中文编辑，只输出 JSON。',
      user: writing.text,
      operation: 'write',
      schema: writingSchema,
    });
    written = writtenResult.data;
    writingVersion = writing.version;
  }

  // ③ 落库：旧判定失效 + 插入当前判定 + 单集状态收尾（同一事务）
  await withTx(async (client) => {
    await client.query('UPDATE analyses SET is_current = false WHERE episode_id = $1 AND is_current', [episodeId]);
    await client.query(
      `INSERT INTO analyses
         (episode_id, score, selected, reason, tags, category,
          title_zh, summary_zh, reason_zh, model, prompt_version, is_current)
       VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9, $10, $11, true)`,
      [
        episodeId,
        scored.data.score,
        selected,
        scored.data.reason,
        JSON.stringify(scored.data.tags),
        category,
        written?.titleZh ?? null,
        written?.summaryZh ?? null,
        written?.reasonZh ?? null,
        scored.model,
        `${scoring.version}${writingVersion ? `+${writingVersion}` : ''}`,
      ],
    );
    await client.query("UPDATE episodes SET transcribe_status = 'done', updated_at = now() WHERE id = $1", [episodeId]);
  });

  console.log(
    `[analyze] episode=${episodeId} score=${scored.data.score}/${threshold} selected=${selected} category=${category}`,
  );
  return { selected, score: scored.data.score };
}

/** 兜底扫描：转写完成但丢失分析任务的单集（事件驱动之外的补救，30 分钟 cron）。 */
export async function sweepPendingAnalyses(): Promise<number> {
  const pending = await rows<{ id: number }>(sql`
    SELECT e.id
    FROM episodes e
    WHERE e.body_status = 'ok' AND e.transcribe_status = 'analyzing'
      AND NOT EXISTS (
        SELECT 1 FROM analyses a WHERE a.episode_id = e.id AND a.is_current
      )
    LIMIT 50
  `);
  const { sendJob } = await import('../queue/boss.ts');
  let sent = 0;
  for (const { id } of pending) {
    await sendJob('episodes.analyze', { episodeId: id }, { singletonKey: `analyze:${id}` });
    sent++;
  }
  if (sent > 0) {
    console.log(`[analyze] sweep dispatched ${sent} episode(s)`);
  }
  return sent;
}

function buildEpisodeMaterial(episode: EpisodeForAnalysis, transcriptLimit: number): string {
  const lines = [
    `播客：${episode.podcast_name}`,
    `单集标题：${episode.title}`,
    `时长：${episode.duration_seconds ? formatDuration(episode.duration_seconds) : '未知'}`,
    `发布时间：${episode.published_at ? episode.published_at.toISOString().slice(0, 10) : '未知'}`,
  ];
  if (episode.shownotes) {
    lines.push(`Shownotes：${clip(episode.shownotes, 2000)}`);
  }
  lines.push(`转录文本：\n${clip(episode.body_text as string, transcriptLimit)}`);
  return lines.join('\n');
}

function clip(text: string, limit: number): string {
  if (text.length <= limit) {
    return text;
  }
  return `${text.slice(0, limit)}\n…（长度超限已截断）`;
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h}小时${m}分` : `${m}分钟`;
}
