import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import { writeJsonAtomic, ensureDir } from "../fs";
import {
  podcastMetaFile,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
} from "../paths";
import { rebuildIndexes, loadSearchIndexSnapshot } from "../index-builder";
import type { PodcastMeta, EpisodeMeta } from "../types";

let tmpDir: string;

async function seedPodcast(meta: PodcastMeta) {
  await writeJsonAtomic(podcastMetaFile(meta.id), meta);
}
async function seedEpisode(podcastId: string, ep: EpisodeMeta) {
  await ensureDir(episodesDir(podcastId));
  await writeJsonAtomic(episodeMetaFile(podcastId, ep.id), ep);
}

beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-idx-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
});

describe("index-builder", () => {
  it("rebuildIndexes 聚合已订阅播客到 index", async () => {
    await seedPodcast({
      id: "p1", name: "播客一", author: "A", category: "科技",
      logo_url: "http://logo", rss_feed_url: "http://rss", xyzrank_rank: 3,
      subscribed: true, subscribed_at: "2026-07-01",
    });
    await seedPodcast({
      id: "p2", name: "未订阅", author: "B", category: "x",
      logo_url: "", rss_feed_url: "", xyzrank_rank: 10,
      subscribed: false,
    });
    const idx = await rebuildIndexes();
    expect(idx.subscribed_podcasts.map((p) => p.id)).toEqual(["p1"]);
    expect(idx.subscribed_podcasts[0].episode_count).toBe(0);
  });

  it("rebuildIndexes 统计每个已订阅播客的剧集数", async () => {
    await seedPodcast({
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    });
    await seedEpisode("p1", {
      id: "e1", podcast_id: "p1", title: "T1", audio_url: "", duration: 0,
      published_at: "2026-07-01T00:00:00Z", link: "", scraped_content_path: "",
      scrape_status: "pending", summary_status: "pending", tags: [],
    });
    await seedEpisode("p1", {
      id: "e2", podcast_id: "p1", title: "T2", audio_url: "", duration: 0,
      published_at: "2026-07-02T00:00:00Z", link: "", scraped_content_path: "",
      scrape_status: "done", summary_status: "done", tags: ["AI"],
    });
    const idx = await rebuildIndexes();
    expect(idx.subscribed_podcasts[0].episode_count).toBe(2);
  });

  it("rebuildIndexes 聚合已摘要剧集到 recent_summarized_episodes", async () => {
    await seedPodcast({
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    });
    await seedEpisode("p1", {
      id: "e1", podcast_id: "p1", title: "T1", audio_url: "", duration: 0,
      published_at: "2026-07-01T00:00:00Z", link: "", scraped_content_path: "episodes/e1.md",
      scrape_status: "done", summary_status: "done", tags: [],
    });
    await ensureDir(episodesDir("p1"));
    await fsp.writeFile(episodeMarkdownFile("p1", "e1"), "---\nepisode_id: e1\n---\n## AI 摘要\n\n这是摘要。\n");
    const idx = await rebuildIndexes();
    expect(idx.recent_summarized_episodes).toHaveLength(1);
    expect(idx.recent_summarized_episodes[0].episode_id).toBe("e1");
  });

  it("loadSearchIndexSnapshot 读取 search-index.json", async () => {
    await rebuildIndexes();
    const snap = await loadSearchIndexSnapshot();
    expect(snap).not.toBeNull();
    expect(Array.isArray(snap!.entries)).toBe(true);
  });
});
