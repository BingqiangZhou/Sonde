import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import {
  writeJsonAtomic,
  readJsonFile,
  readTextFile,
  podcastMetaFile,
  episodeMetaFile,
  episodeMarkdownFile,
  episodesDir,
  ensureDir,
} from "@podcastinsight/shared";
import type { PodcastMeta, EpisodeMeta } from "@podcastinsight/shared";
import { extractMainContent, scrapePending } from "../src/run";

let tmpDir: string;
beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-scrape-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
  vi.restoreAllMocks();
});

async function seed(podcastId: string, meta: PodcastMeta, ep: EpisodeMeta) {
  await writeJsonAtomic(podcastMetaFile(podcastId), meta);
  await ensureDir(episodesDir(podcastId));
  await writeJsonAtomic(episodeMetaFile(podcastId, ep.id), ep);
}

describe("extractor", () => {
  it("extractMainContent 从 HTML 提取 article 正文，剥离 script", () => {
    const html = `<html><body><script>bad()</script><article><p>正文内容</p></article></body></html>`;
    expect(extractMainContent(html)).toContain("正文内容");
    expect(extractMainContent(html)).not.toContain("bad");
  });
});

describe("scrapePending", () => {
  it("成功抓取：写 md 正文，更新 scrape_status=done", async () => {
    await seed("p1", {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    }, {
      id: "e1", podcast_id: "p1", title: "T", audio_url: "",
      duration: 0, published_at: "", link: "http://ep/1",
      scraped_content_path: "episodes/e1.md",
      scrape_status: "pending", summary_status: "pending", tags: [],
    });
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true, status: 200,
      text: async () => "<html><body><article><p>这是剧集正文。</p></article></body></html>",
    })));
    const r = await scrapePending();
    expect(r.scraped).toBe(1);
    expect(r.failed).toBe(0);
    const md = await readTextFile(episodeMarkdownFile("p1", "e1"));
    expect(md).not.toBeNull();
    expect(md).toContain("这是剧集正文");
    const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile("p1", "e1"));
    expect(ep!.scrape_status).toBe("done");
  });

  it("抓取失败：scrape_status=failed，不写 md", async () => {
    await seed("p1", {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    }, {
      id: "e1", podcast_id: "p1", title: "T", audio_url: "",
      duration: 0, published_at: "", link: "http://ep/1",
      scraped_content_path: "episodes/e1.md",
      scrape_status: "pending", summary_status: "pending", tags: [],
    });
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: false, status: 404 })));
    const r = await scrapePending();
    expect(r.failed).toBe(1);
    expect(r.scraped).toBe(0);
    const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile("p1", "e1"));
    expect(ep!.scrape_status).toBe("failed");
    const md = await readTextFile(episodeMarkdownFile("p1", "e1"));
    expect(md).toBeNull();
  });

  it("跳过已 done/failed 的剧集", async () => {
    await seed("p1", {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    }, {
      id: "e1", podcast_id: "p1", title: "T", audio_url: "",
      duration: 0, published_at: "", link: "http://ep/1",
      scraped_content_path: "episodes/e1.md",
      scrape_status: "done", summary_status: "pending", tags: [],
    });
    vi.stubGlobal("fetch", vi.fn());
    const r = await scrapePending();
    expect(r.scraped).toBe(0);
    expect(r.skipped).toBe(1);
    expect(vi.mocked(fetch)).not.toHaveBeenCalled();
  });
});
