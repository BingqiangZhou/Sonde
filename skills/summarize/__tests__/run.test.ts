import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import {
  writeJsonAtomic,
  readJsonFile,
  readTextFile,
  writeTextAtomic,
  podcastMetaFile,
  episodeMetaFile,
  episodeMarkdownFile,
  episodesDir,
  ensureDir,
} from "@podcastinsight/shared";
import type { PodcastMeta, EpisodeMeta } from "@podcastinsight/shared";
import { summarizePending, summarizeEpisode } from "../src/run";

let tmpDir: string;
beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-sum-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
  process.env.LLM_API_KEY = "test-key";
  process.env.LLM_BASE_URL = "http://mock-llm";
  process.env.LLM_MODEL = "test-model";
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
  vi.restoreAllMocks();
});

async function seedEpisodeWithContent(podcastId: string, ep: EpisodeMeta) {
  await ensureDir(episodesDir(podcastId));
  await writeJsonAtomic(episodeMetaFile(podcastId, ep.id), ep);
  await writeTextAtomic(
    episodeMarkdownFile(podcastId, ep.id),
    `---\nepisode_id: ${ep.id}\ntitle: ${ep.title}\nsummary_status: pending\n---\n\n## 正文\n\n这是正文内容，关于人工智能的讨论。\n`
  );
}

function mockLlmOnce(summary: string, tags: string[]) {
  vi.stubGlobal("fetch", vi.fn(async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [
        { message: { content: JSON.stringify({ summary, tags }) } },
      ],
    }),
  })));
}

describe("summarize", () => {
  it("summarizeEpisode 生成摘要写回 md 和 json", async () => {
    const meta: PodcastMeta = {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    };
    await writeJsonAtomic(podcastMetaFile("p1"), meta);
    await seedEpisodeWithContent("p1", {
      id: "e1", podcast_id: "p1", title: "T", audio_url: "",
      duration: 0, published_at: "2026-07-01T00:00:00Z", link: "http://ep/1",
      scraped_content_path: "episodes/e1.md",
      scrape_status: "done", summary_status: "pending", tags: [],
    });
    mockLlmOnce("这是一篇关于AI的摘要。", ["人工智能", "科技"]);

    const result = await summarizeEpisode("p1", "e1");
    expect(result.ok).toBe(true);

    const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile("p1", "e1"));
    expect(ep!.summary_status).toBe("done");
    expect(ep!.tags).toEqual(["人工智能", "科技"]);

    const md = await readTextFile(episodeMarkdownFile("p1", "e1"));
    expect(md).toContain("这是一篇关于AI的摘要。");
    expect(md).toContain("## AI 摘要");
  });

  it("summarizeEpisode 正文不存在时返回 skipped", async () => {
    await writeJsonAtomic(podcastMetaFile("p1"), {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    } satisfies PodcastMeta);
    await writeJsonAtomic(episodeMetaFile("p1", "e1"), {
      id: "e1", podcast_id: "p1", title: "T", audio_url: "",
      duration: 0, published_at: "", link: "", scraped_content_path: "episodes/e1.md",
      scrape_status: "pending", summary_status: "pending", tags: [],
    } satisfies EpisodeMeta);
    mockLlmOnce("x", []);
    const result = await summarizeEpisode("p1", "e1");
    expect(result.ok).toBe(false);
    expect(result.reason).toBe("no-content");
  });

  it("summarizePending 批量处理所有 pending 且有正文的剧集", async () => {
    await writeJsonAtomic(podcastMetaFile("p1"), {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    } satisfies PodcastMeta);
    await seedEpisodeWithContent("p1", {
      id: "e1", podcast_id: "p1", title: "T1", audio_url: "",
      duration: 0, published_at: "2026-07-01T00:00:00Z", link: "http://ep/1",
      scraped_content_path: "episodes/e1.md",
      scrape_status: "done", summary_status: "pending", tags: [],
    } satisfies EpisodeMeta);
    mockLlmOnce("摘要1", ["科技"]);
    const r = await summarizePending();
    expect(r.summarized).toBe(1);
    expect(r.skipped).toBe(0);
  });

  it("已 done 的剧集不重复处理", async () => {
    await writeJsonAtomic(podcastMetaFile("p1"), {
      id: "p1", name: "P", author: "A", category: "c", logo_url: "",
      rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
    } satisfies PodcastMeta);
    await seedEpisodeWithContent("p1", {
      id: "e1", podcast_id: "p1", title: "T", audio_url: "",
      duration: 0, published_at: "", link: "", scraped_content_path: "episodes/e1.md",
      scrape_status: "done", summary_status: "done", tags: ["x"],
    } satisfies EpisodeMeta);
    vi.stubGlobal("fetch", vi.fn());
    const r = await summarizePending();
    expect(r.summarized).toBe(0);
    expect(r.skipped).toBe(1);
    expect(vi.mocked(fetch)).not.toHaveBeenCalled();
  });
});
