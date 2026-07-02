import { describe, it, expect } from "vitest";
import {
  validateRankingsSnapshot,
  validatePodcastMeta,
  validateEpisodeMeta,
  ValidationError,
} from "../validate";

describe("validate", () => {
  it("validateRankingsSnapshot 通过合法数据", () => {
    const data = {
      fetched_at: "2026-07-01T00:00:00Z",
      source: "xyzrank.com",
      podcasts: [{ id: "1", name: "P", rank: 1, category: "科技", logo_url: "", rss_feed_url: "", author: "A" }],
    };
    expect(() => validateRankingsSnapshot(data)).not.toThrow();
  });

  it("validateRankingsSnapshot 拒绝缺字段", () => {
    expect(() => validateRankingsSnapshot({ fetched_at: "x" })).toThrow(ValidationError);
  });

  it("validatePodcastMeta 通过合法数据", () => {
    const meta = {
      id: "1", name: "P", author: "A", category: "科技",
      logo_url: "", rss_feed_url: "http://x", xyzrank_rank: 5,
      subscribed: true,
    };
    expect(() => validatePodcastMeta(meta)).not.toThrow();
  });

  it("validatePodcastMeta 拒绝非 boolean subscribed", () => {
    const meta = { id: "1", name: "P", author: "A", category: "c", logo_url: "", rss_feed_url: "", xyzrank_rank: 1, subscribed: "yes" };
    expect(() => validatePodcastMeta(meta)).toThrow(ValidationError);
  });

  it("validateEpisodeMeta 通过合法数据", () => {
    const ep = {
      id: "e1", podcast_id: "1", title: "T", audio_url: "http://a",
      duration: 60, published_at: "2026-07-01T00:00:00Z", link: "http://l",
      scraped_content_path: "episodes/e1.md",
      scrape_status: "pending", summary_status: "pending", tags: [],
    };
    expect(() => validateEpisodeMeta(ep)).not.toThrow();
  });

  it("validateEpisodeMeta 拒绝非法 status", () => {
    const ep = {
      id: "e1", podcast_id: "1", title: "T", audio_url: "", duration: 0,
      published_at: "", link: "", scraped_content_path: "",
      scrape_status: "weird", summary_status: "pending", tags: [],
    };
    expect(() => validateEpisodeMeta(ep)).toThrow(ValidationError);
  });
});
