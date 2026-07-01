import { describe, it, expect } from "vitest";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import {
  PODCASTS_DIR,
  RANKINGS_FILE,
  INDEX_FILE,
  SEARCH_INDEX_FILE,
  podcastDir,
  podcastMetaFile,
  episodeMetaFile,
  episodeMarkdownFile,
  resolveDataRoot,
} from "../paths";

describe("paths", () => {
  it("resolveDataRoot 默认指向仓库根的 data/ 目录", () => {
    // 防止 spec 中 "向上回溯层数" 的 off-by-one 回归：
    // 从本测试文件向上找到包含 pnpm-workspace.yaml 的真实仓库根。
    const here = path.dirname(fileURLToPath(import.meta.url));
    let repoRoot = here;
    for (let i = 0; i < 10; i++) {
      if (fs.existsSync(path.join(repoRoot, "pnpm-workspace.yaml"))) break;
      repoRoot = path.dirname(repoRoot);
    }
    expect(fs.existsSync(path.join(repoRoot, "pnpm-workspace.yaml"))).toBe(true);
    expect(resolveDataRoot()).toBe(path.join(repoRoot, "data"));
  });
  it("rankings/index/search 路径为 data/ 下固定相对路径", () => {
    const root = resolveDataRoot();
    expect(RANKINGS_FILE).toBe(path.join(root, "rankings", "latest.json"));
    expect(INDEX_FILE).toBe(path.join(root, "index.json"));
    expect(SEARCH_INDEX_FILE).toBe(path.join(root, "search-index.json"));
    expect(PODCASTS_DIR).toBe(path.join(root, "podcasts"));
  });

  it("podcastDir 用 xyzrank id 定位", () => {
    expect(podcastDir("abc123")).toBe(path.join(resolveDataRoot(), "podcasts", "abc123"));
  });

  it("podcastMetaFile 指向 meta.json", () => {
    expect(podcastMetaFile("abc123")).toBe(
      path.join(resolveDataRoot(), "podcasts", "abc123", "meta.json")
    );
  });

  it("episodeMetaFile 指向 episodes/<id>.json", () => {
    expect(episodeMetaFile("abc123", "ep1")).toBe(
      path.join(resolveDataRoot(), "podcasts", "abc123", "episodes", "ep1.json")
    );
  });

  it("episodeMarkdownFile 指向 episodes/<id>.md", () => {
    expect(episodeMarkdownFile("abc123", "ep1")).toBe(
      path.join(resolveDataRoot(), "podcasts", "abc123", "episodes", "ep1.md")
    );
  });
});
