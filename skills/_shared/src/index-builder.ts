import { promises as fsp } from "node:fs";
import {
  podcastsDir,
  rankingsFile,
  indexFile,
  searchIndexFile,
  podcastMetaFile,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
  readJsonFile,
  writeJsonAtomic,
  readTextFile,
} from "./index.js";
import type {
  PodcastMeta,
  EpisodeMeta,
  DataIndex,
  IndexSubscribedPodcast,
  IndexRecentEpisode,
  SearchIndex,
  SearchIndexEntry,
  RankingsSnapshot,
} from "./types.js";

const RECENT_EPISODE_LIMIT = 20;

/** 提取 .md 中 `## AI 摘要` 段落纯文本，用于搜索索引。 */
function extractSummaryFromMarkdown(md: string): string {
  const match = md.match(/##\s*AI\s*摘要[\s\S]*?(?=\n##\s|$)/i);
  if (!match) return "";
  return match[0].replace(/^##\s*AI\s*摘要\s*/i, "").trim();
}

/** 扫描整个 data/，重建 index.json 与 search-index.json。幂等。 */
export async function rebuildIndexes(): Promise<DataIndex> {
  const updated_at = new Date().toISOString();

  const rankings = await readJsonFile<RankingsSnapshot>(rankingsFile());
  const rankings_updated_at = rankings?.fetched_at ?? "";

  const subscribed: IndexSubscribedPodcast[] = [];
  const recentEpisodes: IndexRecentEpisode[] = [];
  const searchEntries: SearchIndexEntry[] = [];

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(podcastsDir());
  } catch {
    podcastIds = [];
  }

  for (const pid of podcastIds) {
    const meta = await readJsonFile<PodcastMeta>(podcastMetaFile(pid));
    if (!meta) continue;

    let episodeIds: string[] = [];
    try {
      episodeIds = await fsp.readdir(episodesDir(pid));
    } catch {
      episodeIds = [];
    }
    const jsonEpisodeIds = episodeIds.filter((f) => f.endsWith(".json"));

    if (meta.subscribed) {
      subscribed.push({
        id: meta.id,
        name: meta.name,
        logo_url: meta.logo_url,
        category: meta.category,
        episode_count: jsonEpisodeIds.length,
      });
    }

    for (const jf of jsonEpisodeIds) {
      const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, jf.replace(/\.json$/, "")));
      if (!ep) continue;

      if (ep.summary_status === "done") {
        recentEpisodes.push({
          episode_id: ep.id,
          podcast_id: pid,
          podcast_name: meta.name,
          title: ep.title,
          summary_status: ep.summary_status,
          published_at: ep.published_at,
        });

        const md = await readTextFile(episodeMarkdownFile(pid, ep.id));
        const summary = md ? extractSummaryFromMarkdown(md) : "";
        searchEntries.push({
          episode_id: ep.id,
          podcast_id: pid,
          podcast_name: meta.name,
          title: ep.title,
          summary,
          published_at: ep.published_at,
        });
      }
    }
  }

  recentEpisodes.sort((a, b) => b.published_at.localeCompare(a.published_at));
  const recent = recentEpisodes.slice(0, RECENT_EPISODE_LIMIT);

  const index: DataIndex = {
    updated_at,
    subscribed_podcasts: subscribed,
    recent_summarized_episodes: recent,
    rankings_updated_at,
  };
  await writeJsonAtomic(indexFile(), index);

  const searchIndex: SearchIndex = { updated_at, entries: searchEntries };
  await writeJsonAtomic(searchIndexFile(), searchIndex);

  return index;
}

export async function loadSearchIndexSnapshot(): Promise<SearchIndex | null> {
  return readJsonFile<SearchIndex>(searchIndexFile());
}
