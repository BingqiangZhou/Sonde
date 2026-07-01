import { promises as fsp } from "node:fs";
import path from "node:path";

/** 递归确保目录存在，幂等。 */
export async function ensureDir(dir: string): Promise<void> {
  await fsp.mkdir(dir, { recursive: true });
}

/**
 * 原子写入：先写到同目录临时文件，再 rename。
 * 保证读到的是完整内容，不会读到半截写入。
 */
export async function writeTextAtomic(filePath: string, content: string): Promise<void> {
  await ensureDir(path.dirname(filePath));
  const tmp = `${filePath}.${process.pid}.${Date.now()}.tmp`;
  await fsp.writeFile(tmp, content, "utf8");
  await fsp.rename(tmp, filePath);
}

/** 原子写入 JSON（pretty print，便于 git diff）。 */
export async function writeJsonAtomic(filePath: string, data: unknown): Promise<void> {
  await writeTextAtomic(filePath, JSON.stringify(data, null, 2) + "\n");
}

/** 读 JSON；文件不存在返回 null。 */
export async function readJsonFile<T = unknown>(filePath: string): Promise<T | null> {
  try {
    const text = await fsp.readFile(filePath, "utf8");
    return JSON.parse(text) as T;
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw e;
  }
}

/** 读文本；文件不存在返回 null。 */
export async function readTextFile(filePath: string): Promise<string | null> {
  try {
    return await fsp.readFile(filePath, "utf8");
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw e;
  }
}

/** 判断文件是否存在。 */
export async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fsp.access(filePath);
    return true;
  } catch {
    return false;
  }
}
