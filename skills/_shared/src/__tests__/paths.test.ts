import { describe, it, expect } from "vitest";
import path from "node:path";
import os from "node:os";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import {
  podcastsDir,
  rankingsFile,
  indexFile,
  searchIndexFile,
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
    expect(rankingsFile()).toBe(path.join(root, "rankings", "latest.json"));
    expect(indexFile()).toBe(path.join(root, "index.json"));
    expect(searchIndexFile()).toBe(path.join(root, "search-index.json"));
    expect(podcastsDir()).toBe(path.join(root, "podcasts"));
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

  it("路径在运行时尊重 PODCASTINSIGHT_DATA_DIR 的变更", () => {
    // 回归保护：路径必须每次实时解析，不能缓存为模块级常量，
    // 否则测试在 beforeEach 改 env 后仍指向旧目录，造成跨测试状态泄漏。
    const prev = process.env.PODCASTINSIGHT_DATA_DIR;
    const first = path.join(os.tmpdir(), "pi-paths-first");
    const second = path.join(os.tmpdir(), "pi-paths-second");
    try {
      process.env.PODCASTINSIGHT_DATA_DIR = first;
      expect(resolveDataRoot()).toBe(path.resolve(first));
      process.env.PODCASTINSIGHT_DATA_DIR = second;
      expect(resolveDataRoot()).toBe(path.resolve(second));
      expect(indexFile()).toBe(path.join(path.resolve(second), "index.json"));
      expect(podcastDir("x")).toBe(path.join(path.resolve(second), "podcasts", "x"));
    } finally {
      if (prev === undefined) delete process.env.PODCASTINSIGHT_DATA_DIR;
      else process.env.PODCASTINSIGHT_DATA_DIR = prev;
    }
  });
});
