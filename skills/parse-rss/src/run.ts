import { createHash } from "node:crypto";
import { promises as fsp } from "node:fs";
import {
  podcastsDir,
  podcastMetaFile,
  episodeMetaFile,
  episodesDir,
  readJsonFile,
  writeJsonAtomic,
  ensureDir,
  rebuildIndexes,
} from "@podcastinsight/shared";
import type { PodcastMeta, EpisodeMeta } from "@podcastinsight/shared";
import { parseRssFeed } from "./rss-parser.js";

export { parseRssFeed } from "./rss-parser.js";
export type { ParsedFeed, ParsedEpisode } from "./rss-parser.js";

export interface ParseRssResult {
  newEpisodes: number;
  skipped: number;
  errors: string[];
}

/** 计算 episode id：优先 guid，否则用 audio_url 的 SHA-1 前 12 位。 */
export function computeEpisodeId(guid: string | undefined, audioUrl: string): string {
  if (guid && guid.trim()) return guid.trim();
  return createHash("sha1").update(audioUrl).digest("hex").slice(0, 12);
}

/** 扫描所有已订阅播客，解析 RSS，为新剧集写 meta。幂等。 */
export async function processSubscriptions(): Promise<ParseRssResult> {
  const result: ParseRssResult = { newEpisodes: 0, skipped: 0, errors: [] };

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(podcastsDir());
  } catch {
    return result;
  }

  for (const pid of podcastIds) {
    const meta = await readJsonFile<PodcastMeta>(podcastMetaFile(pid));
    if (!meta || !meta.subscribed || !meta.rss_feed_url) continue;

    try {
      const feed = await parseRssFeed(meta.rss_feed_url);
      for (const ep of feed.episodes) {
        const eid = computeEpisodeId(ep.guid, ep.audio_url);
        const existing = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, eid));
        if (existing) {
          result.skipped++;
          continue;
        }
        await ensureDir(episodesDir(pid));
        const episodeMeta: EpisodeMeta = {
          id: eid,
          podcast_id: pid,
          title: ep.title,
          audio_url: ep.audio_url,
          duration: ep.duration,
          published_at: ep.published_at,
          link: ep.link,
          description: ep.description,
          scraped_content_path: `episodes/${eid}.md`,
          scrape_status: "pending",
          summary_status: "pending",
          tags: [],
        };
        await writeJsonAtomic(episodeMetaFile(pid, eid), episodeMeta);
        result.newEpisodes++;
      }
    } catch (e) {
      result.errors.push(`${meta.name} (${pid}): ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  await rebuildIndexes();
  return result;
}

async function main() {
  const r = await processSubscriptions();
  console.log(`✓ parse-rss: 新增 ${r.newEpisodes}，跳过 ${r.skipped}，错误 ${r.errors.length}`);
  for (const e of r.errors) console.error("  -", e);
  process.exitCode = r.errors.length > 0 ? 1 : 0;
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
