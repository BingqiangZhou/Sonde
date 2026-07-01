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
import { generateSummary, loadLlmConfig } from "./llm-client.js";

export interface SummarizeResult {
  ok: boolean;
  reason?: string;
}

export interface BatchResult {
  summarized: number;
  skipped: number;
  failed: number;
  errors: string[];
}

/** 从 .md 中提取 `## 正文` 段落内容。 */
function extractBody(md: string): string {
  const match = md.match(/##\s*正文[\s\S]*?(?=\n##\s|$)/i);
  if (!match) return "";
  return match[0].replace(/^##\s*正文\s*/i, "").trim();
}

/** 用新摘要重写整个 .md：frontmatter + AI 摘要 + 标签 + 原正文。 */
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
    model: frontmatter.model ?? process.env.LLM_MODEL ?? "",
  }).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join("\n");

  const body = extractBody(oldMd) || "(无正文)";
  const tagsLine = tags.length > 0 ? tags.map((t) => `#${t}`).join(" ") : "";

  return `---\n${fm}\n---\n\n## AI 摘要\n\n${summary}\n${tagsLine ? `\n## 标签\n\n${tagsLine}\n` : ""}## 正文\n\n${body}\n`;
}

/** 对单集生成摘要。 */
export async function summarizeEpisode(
  podcastId: string,
  episodeId: string
): Promise<SummarizeResult> {
  const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(podcastId, episodeId));
  if (!ep) return { ok: false, reason: "not-found" };
  if (ep.summary_status === "done") return { ok: false, reason: "already-done" };

  const md = await readTextFile(episodeMarkdownFile(podcastId, episodeId));
  if (!md) return { ok: false, reason: "no-content" };
  const body = extractBody(md);
  if (!body) return { ok: false, reason: "no-content" };

  const config = loadLlmConfig();
  const { summary, tags } = await generateSummary(config, ep.title, body);

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
  return { ok: true };
}

/** 批量处理所有 pending 且有正文的剧集。 */
export async function summarizePending(): Promise<BatchResult> {
  const result: BatchResult = { summarized: 0, skipped: 0, failed: 0, errors: [] };

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(podcastsDir());
  } catch {
    return result;
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
      if (!ep || ep.summary_status !== "pending") {
        result.skipped++;
        continue;
      }
      try {
        const r = await summarizeEpisode(pid, eid);
        if (r.ok) result.summarized++;
        else result.skipped++;
      } catch (e) {
        result.failed++;
        result.errors.push(`${pid}/${eid}: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }

  await rebuildIndexes();
  return result;
}

/** CLI 入口：支持 `--episode <podcastId>/<episodeId>` 或无参数批量。 */
async function main() {
  const arg = process.argv.find((a) => a.startsWith("--episode="));
  try {
    if (arg) {
      const target = arg.replace("--episode=", "");
      const [pid, eid] = target.split("/");
      if (!pid || !eid) throw new Error("用法: --episode=<podcastId>/<episodeId>");
      const r = await summarizeEpisode(pid, eid);
      console.log(r.ok ? `✓ summarize: ${pid}/${eid} 完成` : `⊘ summarize: ${pid}/${eid} 跳过 (${r.reason})`);
      process.exitCode = r.ok ? 0 : 0;
    } else {
      const r = await summarizePending();
      console.log(`✓ summarize: 生成 ${r.summarized}，跳过 ${r.skipped}，失败 ${r.failed}`);
      for (const e of r.errors) console.error("  -", e);
      process.exitCode = r.failed > 0 ? 1 : 0;
    }
  } catch (e) {
    console.error("✗ summarize 失败:", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  }
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
