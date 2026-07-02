import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";

let tmpData: string;
const oldDataDir = process.env.PODCASTINSIGHT_DATA_DIR;

beforeEach(async () => {
  tmpData = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-fe-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpData;
});
afterEach(async () => {
  process.env.PODCASTINSIGHT_DATA_DIR = oldDataDir;
  await fsp.rm(tmpData, { recursive: true, force: true });
});

describe("loaders", () => {
  it("loadIndex 返回 DataIndex", async () => {
    // Use raw fs to write a fixture, then dynamically import loaders
    const idx = {
      updated_at: "2026-07-01T00:00:00Z",
      subscribed_podcasts: [],
      recent_summarized_episodes: [],
      rankings_updated_at: "2026-07-01T00:00:00Z",
    };
    await fsp.writeFile(path.join(tmpData, "index.json"), JSON.stringify(idx));

    // Re-import so the module picks up the new env var
    const { loadIndex } = await import("../loaders");
    const result = await loadIndex();
    expect(result.rankings_updated_at).toBe("2026-07-01T00:00:00Z");
  });
});
