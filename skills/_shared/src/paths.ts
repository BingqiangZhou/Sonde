import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * 数据布局唯一真相来源。前端 loaders.ts 和所有 skills 都通过这里解析路径。
 *
 * 数据根目录解析顺序：
 * 1. 环境变量 PODCASTINSIGHT_DATA_DIR（测试/CI 可覆盖）
 * 2. 仓库根的 data/ 目录（从本文件向上回溯到 monorepo 根）
 *
 * 注意：路径必须每次实时解析（不缓存为模块级常量），否则测试在 beforeEach
 * 里设置的 PODCASTINSIGHT_DATA_DIR 不会生效，不同测试会写到同一个 data/
 * 目录导致状态泄漏。因此根级路径用函数导出；与 episodesDir() 等保持一致。
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

/** data/podcasts 目录。 */
export function podcastsDir(): string {
  return path.join(resolveDataRoot(), "podcasts");
}

/** data/rankings/latest.json。 */
export function rankingsFile(): string {
  return path.join(resolveDataRoot(), "rankings", "latest.json");
}

/** data/index.json（前端入口聚合索引）。 */
export function indexFile(): string {
  return path.join(resolveDataRoot(), "index.json");
}

/** data/search-index.json（搜索索引）。 */
export function searchIndexFile(): string {
  return path.join(resolveDataRoot(), "search-index.json");
}

export function podcastDir(podcastId: string): string {
  return path.join(podcastsDir(), podcastId);
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
