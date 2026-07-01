import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import { readJsonFile, writeJsonAtomic, writeTextAtomic, readTextFile, ensureDir } from "../fs";

let tmpDir: string;

beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-fs-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});

afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
});

describe("fs atomic writes", () => {
  it("writeJsonAtomic 写入并创建不存在的目录", async () => {
    const filePath = path.join(tmpDir, "a", "b", "data.json");
    await writeJsonAtomic(filePath, { x: 1 });
    const got = await readJsonFile<{ x: number }>(filePath);
    expect(got).toEqual({ x: 1 });
  });

  it("writeTextAtomic 原子写入文本", async () => {
    const filePath = path.join(tmpDir, "note.md");
    await writeTextAtomic(filePath, "# hello");
    const got = await readTextFile(filePath);
    expect(got).toBe("# hello");
  });

  it("readJsonFile 文件不存在时返回 null", async () => {
    const got = await readJsonFile(path.join(tmpDir, "nope.json"));
    expect(got).toBeNull();
  });

  it("readTextFile 文件不存在时返回 null", async () => {
    const got = await readTextFile(path.join(tmpDir, "nope.md"));
    expect(got).toBeNull();
  });

  it("ensureDir 幂等创建目录", async () => {
    const dir = path.join(tmpDir, "deep", "nested");
    await ensureDir(dir);
    await ensureDir(dir); // 不应抛错
    const stat = await fsp.stat(dir);
    expect(stat.isDirectory()).toBe(true);
  });
});
