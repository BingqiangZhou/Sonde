import { promises as fsp } from "node:fs";
import path from "node:path";
import type {
  RankingsData,
  PodcastMeta,
  EpisodeMeta,
  EpisodeContent,
  DataIndex,
  SearchIndex,
} from "@/types";
import { parseEpisodeMarkdown } from "./markdown";

// Resolve data root lazily (at call time) so env-var overrides work in tests.
// Mirrors _shared/paths.ts logic but standalone (frontend doesn't import _shared at runtime).
function dataRoot(): string {
  if (process.env.PODCASTINSIGHT_DATA_DIR) {
    return path.resolve(process.env.PODCASTINSIGHT_DATA_DIR);
  }
  // frontend/ → ../data  (data is at repo root)
  return path.resolve(process.cwd(), "..", "data");
}

export async function loadIndex(): Promise<DataIndex> {
  const raw = await fsp.readFile(path.join(dataRoot(), "index.json"), "utf8");
  return JSON.parse(raw) as DataIndex;
}

export async function loadRankings(): Promise<RankingsData> {
  const raw = await fsp.readFile(path.join(dataRoot(), "rankings", "latest.json"), "utf8");
  return JSON.parse(raw) as RankingsData;
}

export async function loadSearchIndex(): Promise<SearchIndex> {
  const raw = await fsp.readFile(path.join(dataRoot(), "search-index.json"), "utf8");
  return JSON.parse(raw) as SearchIndex;
}

export async function loadPodcastMeta(id: string): Promise<PodcastMeta | null> {
  try {
    const raw = await fsp.readFile(path.join(dataRoot(), "podcasts", id, "meta.json"), "utf8");
    return JSON.parse(raw) as PodcastMeta;
  } catch {
    return null;
  }
}

export async function loadEpisodes(podcastId: string): Promise<EpisodeMeta[]> {
  const dir = path.join(dataRoot(), "podcasts", podcastId, "episodes");
  let files: string[] = [];
  try {
    files = await fsp.readdir(dir);
  } catch {
    return [];
  }
  const jsonFiles = files.filter((f) => f.endsWith(".json"));
  const episodes: EpisodeMeta[] = [];
  for (const f of jsonFiles) {
    const raw = await fsp.readFile(path.join(dir, f), "utf8");
    episodes.push(JSON.parse(raw) as EpisodeMeta);
  }
  return episodes.sort((a, b) => b.published_at.localeCompare(a.published_at));
}

export async function loadEpisodeContent(
  podcastId: string,
  episodeId: string
): Promise<EpisodeContent | null> {
  const metaPath = path.join(dataRoot(), "podcasts", podcastId, "episodes", `${episodeId}.json`);
  const mdPath = path.join(dataRoot(), "podcasts", podcastId, "episodes", `${episodeId}.md`);
  try {
    const meta = JSON.parse(await fsp.readFile(metaPath, "utf8")) as EpisodeMeta;
    let md = "";
    try {
      md = await fsp.readFile(mdPath, "utf8");
    } catch {
      md = "";
    }
    return parseEpisodeMarkdown(md, meta);
  } catch {
    return null;
  }
}

export async function listPodcastIds(): Promise<string[]> {
  try {
    const entries = await fsp.readdir(path.join(dataRoot(), "podcasts"), { withFileTypes: true });
    return entries.filter((e) => e.isDirectory()).map((e) => e.name);
  } catch {
    return [];
  }
}

export async function listEpisodeIds(podcastId: string): Promise<string[]> {
  const dir = path.join(dataRoot(), "podcasts", podcastId, "episodes");
  try {
    const files = await fsp.readdir(dir);
    return files.filter((f) => f.endsWith(".json")).map((f) => f.replace(/\.json$/, ""));
  } catch {
    return [];
  }
}
