import { promises as fsp } from "node:fs";
import {
  podcastsDir,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
  readJsonFile,
  writeJsonAtomic,
  writeTextAtomic,
  ensureDir,
  rebuildIndexes,
  fetchText,
} from "@podcastinsight/shared";
import type { EpisodeMeta, EpisodeMarkdownFrontmatter } from "@podcastinsight/shared";
import { extractMainContent } from "./extractor.js";

export { extractMainContent } from "./extractor.js";

export interface ScrapeResult {
  scraped: number;
  failed: number;
  skipped: number;
}

function buildMarkdown(frontmatter: EpisodeMarkdownFrontmatter, body: string): string {
  const fm = Object.entries({
    episode_id: frontmatter.episode_id,
    title: frontmatter.title,
    summary_status: frontmatter.summary_status,
    generated_at: frontmatter.generated_at ?? "",
    model: frontmatter.model ?? "",
  }).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join("\n");
  return `---\n${fm}\n---\n\n## 正文\n\n${body}\n`;
}

/** 扫描所有 pending 剧集，抓取网页正文写入 .md。幂等。 */
export async function scrapePending(): Promise<ScrapeResult> {
  const result: ScrapeResult = { scraped: 0, failed: 0, skipped: 0 };

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
    const jsonFiles = episodeFiles.filter((f) => f.endsWith(".json"));

    for (const jf of jsonFiles) {
      const eid = jf.replace(/\.json$/, "");
      const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, eid));
      if (!ep) continue;
      if (ep.scrape_status !== "pending") {
        result.skipped++;
        continue;
      }
      if (!ep.link) {
        await writeJsonAtomic(episodeMetaFile(pid, eid), { ...ep, scrape_status: "failed" });
        result.failed++;
        continue;
      }

      try {
        const html = await fetchText(ep.link);
        const body = extractMainContent(html);
        await ensureDir(episodesDir(pid));
        const md = buildMarkdown(
          { episode_id: ep.id, title: ep.title, summary_status: "pending" },
          body
        );
        await writeTextAtomic(episodeMarkdownFile(pid, eid), md);
        await writeJsonAtomic(episodeMetaFile(pid, eid), { ...ep, scrape_status: "done" });
        result.scraped++;
      } catch (e) {
        await writeJsonAtomic(episodeMetaFile(pid, eid), { ...ep, scrape_status: "failed" });
        result.failed++;
        console.error(`scrape 失败 ${pid}/${eid}: ${e instanceof Error ? e.message : e}`);
      }
    }
  }

  await rebuildIndexes();
  return result;
}

async function main() {
  const r = await scrapePending();
  console.log(`✓ scrape-episode: 抓取 ${r.scraped}，失败 ${r.failed}，跳过 ${r.skipped}`);
  process.exitCode = r.failed > 0 ? 1 : 0;
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
