import { promises as fsp } from "node:fs";
import {
  podcastsDir,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
  readJsonFile,
  readTextFile,
  writeJsonAtomic,
  writeTextAtomic,
  rebuildIndexes,
} from "@podcastinsight/shared";
import type { EpisodeMeta, EpisodeMarkdownFrontmatter } from "@podcastinsight/shared";

// 本 skill 不调用任何外部 LLM API —— 摘要由 agent 自身生成。
// 职责拆分：
//   prepareEpisode()  读正文，交给 agent 看
//   writeSummary()    接收 agent 生成的摘要，原子写回 .md/.json + 重建索引
//   listPending()     列出待处理剧集，供 agent 决策

export interface PrepareSuccess {
  ok: true;
  podcast_id: string;
  episode_id: string;
  title: string;
  body: string;
}

export interface PrepareFailure {
  ok: false;
  reason: "not-found" | "no-content" | "already-done";
}

export type PrepareResult = PrepareSuccess | PrepareFailure;

export interface WriteSummaryResult {
  ok: boolean;
  reason?: string;
}

export interface PendingItem {
  podcast_id: string;
  episode_id: string;
  title: string;
}

/** 从 .md 中提取 `## 正文` 段落内容。 */
function extractBody(md: string): string {
  const match = md.match(/##\s*正文[\s\S]*?(?=\n##\s|$)/i);
  if (!match) return "";
  return match[0].replace(/^##\s*正文\s*/i, "").trim();
}

/**
 * 用新摘要重写整个 .md：frontmatter + AI 摘要 + 标签 + 原正文。
 * 格式契约：下游 index-builder 用 `## AI 摘要` 正则提取摘要，
 * 前端 markdown.ts 用 `## 正文` 正则提取正文。两段标题必须保持不变。
 */
function rewriteMarkdownWithSummary(
  oldMd: string,
  frontmatter: EpisodeMarkdownFrontmatter,
  summary: string,
  tags: string[]
): string {
  const fm = Object.entries({
    episode_id: frontmatter.episode_id,
    title: frontmatter.title,
    summary_status: "done",
    generated_at: frontmatter.generated_at ?? new Date().toISOString(),
    model: "agent",
  }).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join("\n");

  const body = extractBody(oldMd) || "(无正文)";
  const tagsLine = tags.length > 0 ? tags.map((t) => `#${t}`).join(" ") : "";

  return `---\n${fm}\n---\n\n## AI 摘要\n\n${summary}\n${tagsLine ? `\n## 标签\n\n${tagsLine}\n` : ""}## 正文\n\n${body}\n`;
}

/**
 * 读取单集正文，返回给 agent 生成摘要。
 * 已 done 或无正文的剧集返回 reason。
 */
export async function prepareEpisode(
  podcastId: string,
  episodeId: string
): Promise<PrepareResult> {
  const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(podcastId, episodeId));
  if (!ep) return { ok: false, reason: "not-found" };
  if (ep.summary_status === "done") return { ok: false, reason: "already-done" };

  const md = await readTextFile(episodeMarkdownFile(podcastId, episodeId));
  if (!md) return { ok: false, reason: "no-content" };
  const body = extractBody(md);
  if (!body) return { ok: false, reason: "no-content" };

  return {
    ok: true,
    podcast_id: podcastId,
    episode_id: episodeId,
    title: ep.title,
    body,
  };
}

/**
 * 接收 agent 生成的摘要和标签，原子写回 .md 和 .json，重建索引。
 * 幂等：对已 done 的剧集返回 already-done，不重复写。
 */
export async function writeSummary(
  podcastId: string,
  episodeId: string,
  summary: string,
  tags: string[]
): Promise<WriteSummaryResult> {
  const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(podcastId, episodeId));
  if (!ep) return { ok: false, reason: "not-found" };
  if (ep.summary_status === "done") return { ok: false, reason: "already-done" };

  const md = await readTextFile(episodeMarkdownFile(podcastId, episodeId));
  if (!md) return { ok: false, reason: "no-content" };

  const newMd = rewriteMarkdownWithSummary(
    md,
    { episode_id: ep.id, title: ep.title, summary_status: "done" },
    summary,
    tags
  );
  await writeTextAtomic(episodeMarkdownFile(podcastId, episodeId), newMd);
  await writeJsonAtomic(episodeMetaFile(podcastId, episodeId), {
    ...ep,
    summary_status: "done",
    tags,
  });
  await rebuildIndexes();
  return { ok: true };
}

/** 列出所有 summary_status: pending 且有正文的剧集。供 agent 决策处理多少。 */
export async function listPending(): Promise<PendingItem[]> {
  const items: PendingItem[] = [];

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(podcastsDir());
  } catch {
    return items;
  }

  for (const pid of podcastIds) {
    let episodeFiles: string[] = [];
    try {
      episodeFiles = await fsp.readdir(episodesDir(pid));
    } catch {
      continue;
    }
    for (const jf of episodeFiles.filter((f) => f.endsWith(".json"))) {
      const eid = jf.replace(/\.json$/, "");
      const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, eid));
      if (!ep || ep.summary_status !== "pending") continue;
      items.push({ podcast_id: pid, episode_id: eid, title: ep.title });
    }
  }

  return items;
}

/** CLI 入口：列出待处理剧集（辅助 agent 和人工查看）。 */
async function main() {
  try {
    const items = await listPending();
    if (items.length === 0) {
      console.log("✓ summarize: 无待处理剧集");
    } else {
      console.log(`✓ summarize: ${items.length} 集待处理`);
      for (const it of items) {
        console.log(`  ${it.podcast_id}/${it.episode_id}  ${it.title}`);
      }
      console.log("\n请通过 agent 对话生成摘要（agent 原生能力，无需 API Key）。");
    }
  } catch (e) {
    console.error("✗ summarize 失败:", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  }
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
