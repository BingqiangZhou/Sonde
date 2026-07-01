import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import { fetchAndSaveRankings } from "../src/run";
import { rankingsFile, indexFile, readJsonFile } from "@podcastinsight/shared";
import type { RankingsSnapshot } from "@podcastinsight/shared";

let tmpDir: string;

beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-rank-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
  vi.restoreAllMocks();
});

const sampleXyzrankItem = (rank: number) => ({
  id: `id-${rank}`,
  name: `Podcast ${rank}`,
  rank,
  logoURL: `http://logo/${rank}`,
  primaryGenreName: "科技",
  authorsText: "Author",
  links: [{ name: "rss", url: `http://rss/${rank}` }],
  trackCount: 10,
  avgDuration: 1800,
  avgPlayCount: 1000,
});

describe("fetch-rankings run", () => {
  it("抓取并写入 latest.json，结构符合 RankingsSnapshot", async () => {
    vi.stubGlobal("fetch", vi.fn(async (url: string) => {
      const u = new URL(url);
      const offset = Number(u.searchParams.get("offset"));
      const limit = Number(u.searchParams.get("limit"));
      const items = Array.from({ length: limit }, (_, i) => sampleXyzrankItem(offset + i + 1));
      return { ok: true, status: 200, json: async () => ({ items, total: 2 }) };
    }));

    await fetchAndSaveRankings({ limit: 2 });

    const snap = await readJsonFile<RankingsSnapshot>(rankingsFile());
    expect(snap).not.toBeNull();
    expect(snap!.source).toBe("xyzrank.com");
    expect(snap!.podcasts).toHaveLength(2);
    expect(snap!.podcasts[0].id).toBe("id-1");
    expect(snap!.podcasts[0].rss_feed_url).toBe("http://rss/1");
  });

  it("抓取后重建 index.json", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true, status: 200, json: async () => ({ items: [sampleXyzrankItem(1)], total: 1 }),
    })));
    await fetchAndSaveRankings({ limit: 1 });
    const idx = await readJsonFile(indexFile());
    expect(idx).not.toBeNull();
    expect(typeof (idx as any).rankings_updated_at).toBe("string");
  });

  it("fetch 失败时不覆盖已有 latest.json", async () => {
    const { writeJsonAtomic } = await import("@podcastinsight/shared");
    await writeJsonAtomic(rankingsFile(), {
      fetched_at: "2020-01-01T00:00:00Z", source: "xyzrank.com", podcasts: [],
    });
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: false, status: 500 })));
    await expect(fetchAndSaveRankings({ limit: 1 })).rejects.toThrow();
    const snap = await readJsonFile<RankingsSnapshot>(rankingsFile());
    expect(snap!.fetched_at).toBe("2020-01-01T00:00:00Z");
  });
});
