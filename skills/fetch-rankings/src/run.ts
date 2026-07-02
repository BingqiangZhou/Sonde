import {
  rankingsFile,
  writeJsonAtomic,
  validateRankingsSnapshot,
  rebuildIndexes,
} from "@podcastinsight/shared";
import type { RankingsSnapshot } from "@podcastinsight/shared";
import { fetchAllRankings } from "./xyzrank-client.js";

export interface FetchRankingsOptions {
  /** 每页大小，默认 50。 */
  limit?: number;
}

/** 抓取 xyzrank 全量排行并落盘。失败时保留旧快照。 */
export async function fetchAndSaveRankings(
  opts: FetchRankingsOptions = {}
): Promise<RankingsSnapshot> {
  const podcasts = await fetchAllRankings(opts.limit);
  const snapshot: RankingsSnapshot = {
    fetched_at: new Date().toISOString(),
    source: "xyzrank.com",
    podcasts,
  };
  validateRankingsSnapshot(snapshot);
  await writeJsonAtomic(rankingsFile(), snapshot);
  await rebuildIndexes();
  return snapshot;
}

async function main() {
  try {
    const snap = await fetchAndSaveRankings();
    console.log(`✓ fetch-rankings: ${snap.podcasts.length} 个播客已写入`);
  } catch (e) {
    console.error("✗ fetch-rankings 失败:", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  }
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
