import { describe, it, expect, beforeEach, afterEach } from "vitest";
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
import { prepareEpisode, writeSummary, listPending } from "../src/run";

let tmpDir: string;
beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-sum-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
});

async function seedPodcast(id: string) {
  const meta: PodcastMeta = {
    id, name: `P-${id}`, author: "A", category: "c", logo_url: "",
    rss_feed_url: "", xyzrank_rank: 1, subscribed: true,
  };
  await writeJsonAtomic(podcastMetaFile(id), meta);
}

async function seedEpisodeWithContent(podcastId: string, ep: EpisodeMeta, body: string) {
  await ensureDir(episodesDir(podcastId));
  await writeJsonAtomic(episodeMetaFile(podcastId, ep.id), ep);
  await writeTextAtomic(
    episodeMarkdownFile(podcastId, ep.id),
    `---\nepisode_id: ${ep.id}\ntitle: ${ep.title}\nsummary_status: pending\n---\n\n## 正文\n\n${body}\n`
  );
}

const baseEp = (id: string): EpisodeMeta => ({
  id, podcast_id: "p1", title: `T-${id}`, audio_url: "",
  duration: 0, published_at: "2026-07-01T00:00:00Z", link: "http://ep",
  scraped_content_path: `episodes/${id}.md`,
  scrape_status: "done", summary_status: "pending", tags: [],
});

describe("prepareEpisode", () => {
  it("读取正文返回 title 和 body", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", baseEp("e1"), "这是关于人工智能的讨论正文。");
    const r = await prepareEpisode("p1", "e1");
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.title).toBe("T-e1");
      expect(r.body).toContain("人工智能");
    }
  });

  it("无正文时返回 no-content", async () => {
    await seedPodcast("p1");
    await ensureDir(episodesDir("p1"));
    await writeJsonAtomic(episodeMetaFile("p1", "e1"), baseEp("e1"));
    // 不写 .md
    const r = await prepareEpisode("p1", "e1");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.reason).toBe("no-content");
  });

  it("meta 不存在时返回 not-found", async () => {
    const r = await prepareEpisode("p1", "ghost");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.reason).toBe("not-found");
  });

  it("已 done 的剧集返回 already-done", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", { ...baseEp("e1"), summary_status: "done" }, "正文");
    const r = await prepareEpisode("p1", "e1");
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.reason).toBe("already-done");
  });
});

describe("writeSummary", () => {
  it("写回 md（含 ## AI 摘要）和 json（summary_status=done, tags）", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", baseEp("e1"), "原始正文内容。");
    const r = await writeSummary("p1", "e1", "这是 AI 摘要。", ["人工智能", "科技"]);
    expect(r.ok).toBe(true);

    const md = await readTextFile(episodeMarkdownFile("p1", "e1"));
    expect(md).toContain("## AI 摘要");
    expect(md).toContain("这是 AI 摘要。");
    expect(md).toContain("#人工智能 #科技");
    expect(md).toContain("原始正文内容。"); // 原正文保留

    const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile("p1", "e1"));
    expect(ep!.summary_status).toBe("done");
    expect(ep!.tags).toEqual(["人工智能", "科技"]);
  });

  it("frontmatter model 字段写为 agent", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", baseEp("e1"), "正文");
    await writeSummary("p1", "e1", "摘要", []);
    const md = await readTextFile(episodeMarkdownFile("p1", "e1"));
    expect(md).toContain('model: "agent"');
  });

  it("幂等：已 done 的剧集返回 already-done 不重复写", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", { ...baseEp("e1"), summary_status: "done" }, "正文");
    const r = await writeSummary("p1", "e1", "新摘要", []);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.reason).toBe("already-done");
  });

  it("无 tags 时不写 ## 标签 段落", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", baseEp("e1"), "正文");
    await writeSummary("p1", "e1", "摘要", []);
    const md = await readTextFile(episodeMarkdownFile("p1", "e1"));
    expect(md).not.toContain("## 标签");
  });
});

describe("listPending", () => {
  it("返回所有 summary_status=pending 的剧集", async () => {
    await seedPodcast("p1");
    await seedEpisodeWithContent("p1", baseEp("e1"), "正文1");
    await seedEpisodeWithContent("p1", baseEp("e2"), "正文2");
    await seedEpisodeWithContent("p1", { ...baseEp("e3"), summary_status: "done" }, "正文3");
    const items = await listPending();
    expect(items).toHaveLength(2);
    expect(items.map((i) => i.episode_id).sort()).toEqual(["e1", "e2"]);
  });

  it("无数据时返回空数组", async () => {
    const items = await listPending();
    expect(items).toEqual([]);
  });
});
