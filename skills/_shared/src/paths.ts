import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * 数据布局唯一真相来源。前端 loaders.ts 和所有 skills 都通过这里解析路径。
 *
 * 数据根目录解析顺序：
 * 1. 环境变量 PODCASTINSIGHT_DATA_DIR（测试/CI 可覆盖）
 * 2. 仓库根的 data/ 目录（从本文件向上回溯到 monorepo 根）
 */
export function resolveDataRoot(): string {
  if (process.env.PODCASTINSIGHT_DATA_DIR) {
    return path.resolve(process.env.PODCASTINSIGHT_DATA_DIR);
  }
  // skills/_shared/src/paths.ts → 向上 3 层到 monorepo 根
  // (src → _shared → skills → <repoRoot>)
  const here = path.dirname(fileURLToPath(import.meta.url));
  const repoRoot = path.resolve(here, "..", "..", "..");
  return path.join(repoRoot, "data");
}

const DATA_ROOT = resolveDataRoot();

export const PODCASTS_DIR = path.join(DATA_ROOT, "podcasts");
export const RANKINGS_FILE = path.join(DATA_ROOT, "rankings", "latest.json");
export const INDEX_FILE = path.join(DATA_ROOT, "index.json");
export const SEARCH_INDEX_FILE = path.join(DATA_ROOT, "search-index.json");

export function podcastDir(podcastId: string): string {
  return path.join(PODCASTS_DIR, podcastId);
}

export function podcastMetaFile(podcastId: string): string {
  return path.join(podcastDir(podcastId), "meta.json");
}

export function episodesDir(podcastId: string): string {
  return path.join(podcastDir(podcastId), "episodes");
}

export function episodeMetaFile(podcastId: string, episodeId: string): string {
  return path.join(episodesDir(podcastId), `${episodeId}.json`);
}

export function episodeMarkdownFile(podcastId: string, episodeId: string): string {
  return path.join(episodesDir(podcastId), `${episodeId}.md`);
}
