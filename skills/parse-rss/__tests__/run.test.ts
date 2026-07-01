import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import { writeJsonAtomic, readJsonFile, podcastMetaFile, episodeMetaFile } from "@podcastinsight/shared";
import type { PodcastMeta, EpisodeMeta } from "@podcastinsight/shared";
import { parseRssFeed, processSubscriptions } from "../src/run";

const sampleRss = `<?xml version="1.0"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>测试播客</title>
    <description>描述</description>
    <item>
      <title>第1集</title>
      <link>http://ep/1</link>
      <guid>guid-1</guid>
      <pubDate>Mon, 28 Jun 2026 10:00:00 GMT</pubDate>
      <itunes:duration>3600</itunes:duration>
      <enclosure url="http://audio/1.mp3" type="audio/mpeg"/>
    </item>
    <item>
      <title>第2集（无 audio enclosure，应被跳过）</title>
      <guid>guid-2</guid>
      <enclosure url="http://video/2.mp4" type="video/mp4"/>
    </item>
  </channel>
</rss>`;

let tmpDir: string;
beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-rss-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
  vi.restoreAllMocks();
});

describe("rss-parser", () => {
  it("parseRssFeed 解析出频道标题和剧集", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true, status: 200, text: async () => sampleRss })));
    const feed = await parseRssFeed("http://feed");
    expect(feed.title).toBe("测试播客");
    expect(feed.episodes).toHaveLength(1);
    expect(feed.episodes[0].title).toBe("第1集");
    expect(feed.episodes[0].duration).toBe(3600);
  });
});

describe("processSubscriptions", () => {
  it("为新剧集写 episode meta（summary_status=pending），跳过已存在", async () => {
    const meta: PodcastMeta = {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "http://feed", xyzrank_rank: 1, subscribed: true,
    };
    await writeJsonAtomic(podcastMetaFile("p1"), meta);
    await writeJsonAtomic(episodeMetaFile("p1", "guid-1"), {
      id: "guid-1", podcast_id: "p1", title: "旧", audio_url: "",
      duration: 0, published_at: "", link: "", scraped_content_path: "",
      scrape_status: "pending", summary_status: "pending", tags: [],
    } satisfies EpisodeMeta);

    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true, status: 200, text: async () => sampleRss })));
    const result = await processSubscriptions();
    expect(result.newEpisodes).toBe(0);
    expect(result.skipped).toBe(1);
  });

  it("guid 缺失时用 audio_url hash 作 id", async () => {
    const noGuidRss = sampleRss.replace(/<guid>guid-1<\/guid>\s*/, "");
    const meta: PodcastMeta = {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "http://feed", xyzrank_rank: 1, subscribed: true,
    };
    await writeJsonAtomic(podcastMetaFile("p1"), meta);
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true, status: 200, text: async () => noGuidRss })));
    const result = await processSubscriptions();
    expect(result.newEpisodes).toBe(1);
    const files = await fsp.readdir(path.join(tmpDir, "podcasts", "p1", "episodes"));
    const jsonFile = files.find((f) => f.endsWith(".json"))!;
    expect(jsonFile).toBeTruthy();
    const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile("p1", jsonFile.replace(/\.json$/, "")));
    expect(ep!.audio_url).toBe("http://audio/1.mp3");
  });
});
