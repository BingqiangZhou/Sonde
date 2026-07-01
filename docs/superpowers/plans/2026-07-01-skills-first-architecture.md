# Skills 为核心架构改造 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 PodcastInsight 从 v2（Next.js 全栈 + Get笔记 OpenAPI）改造成 v3（Agent Skills 为核心 + 数据存 git + 前端纯只读静态站）。

**Architecture:** 处理逻辑封装成 4 个独立 Agent Skills（fetch-rankings / parse-rss / scrape-episode / summarize），其中前三个是确定性脚本、由 GitHub Actions 定时执行，summarize 由 agent 实时调用。skill 产出结构化 JSON/MD 文件存于 `data/`（git 跟踪）。前端删除整个 BFF 层与状态管理，改为构建期通过 `loaders.ts` 读 `data/` 的只读静态站。

**Tech Stack:** TypeScript / Node（skills 脚本，tsx 运行）/ Next.js 16 App Router（SSG）/ fast-xml-parser / vitest / GitHub Actions

**Spec:** `docs/superpowers/specs/2026-07-01-skills-first-architecture-design.md`

---

## 文件结构总览

**新建：**

| 路径 | 职责 |
|------|------|
| `pnpm-workspace.yaml`（根） | 声明 frontend + skills 为 workspace 包 |
| `package.json`（根） | workspace 根，仅含公共脚本 |
| `tsconfig.base.json`（根） | 共享 TS 配置，被 frontend/skills 继承 |
| `.gitignore`（改） | 加入 `data/tmp/` 等中间产物 |
| `skills/_shared/package.json` | _shared 包声明 |
| `skills/_shared/tsconfig.json` | _shared TS 配置 |
| `skills/_shared/src/types.ts` | 所有共享 TS 类型（对应 spec §2） |
| `skills/_shared/src/paths.ts` | 数据布局路径解析（唯一真相来源） |
| `skills/_shared/src/fs.ts` | 原子读写 JSON/MD |
| `skills/_shared/src/http.ts` | fetch 封装（超时/重试/UA） |
| `skills/_shared/src/validate.ts` | 数据结构校验 |
| `skills/_shared/src/index.ts` | 入口聚合 |
| `skills/_shared/src/lock.ts` | 简易文件锁（防并发写） |
| `skills/_shared/src/__tests__/*.test.ts` | _shared 单测 |
| `skills/fetch-rankings/{SKILL.md,src/run.ts,src/index.ts,__tests__/run.test.ts,package.json}` | 抓排行榜 |
| `skills/parse-rss/{SKILL.md,src/run.ts,src/index.ts,__tests__/run.test.ts,package.json}` | 解析 RSS |
| `skills/scrape-episode/{SKILL.md,src/run.ts,src/index.ts,__tests__/run.test.ts,package.json}` | 抓剧集正文 |
| `skills/summarize/{SKILL.md,src/run.ts,src/index.ts,__tests__/run.test.ts,package.json}` | LLM 摘要 |
| `data/.gitkeep` | 占位使 data/ 入库 |
| `data/rankings/.gitkeep`、`data/podcasts/.gitkeep` | 占位 |
| `frontend/src/lib/loaders.ts` | 前端唯一数据读取层 |
| `frontend/src/lib/markdown.ts` | MD 渲染辅助 |
| `.github/workflows/refresh.yml` | 定时数据刷新 |
| `vitest.config.ts`（根） | 根级测试配置（可选，见 Task 0） |

**删除（在 Task 6 前端清理阶段一次性删除）：**

| 路径 | 原因 |
|------|------|
| `frontend/src/app/api/` 整个目录 | BFF 代理层，不再需要 |
| `frontend/src/lib/getnote-api.ts` | Get笔记 逻辑移除 |
| `frontend/src/lib/xyzrank-api.ts` | 逻辑迁移到 skills/fetch-rankings |
| `frontend/src/lib/rss-parser.ts` | 逻辑迁移到 skills/parse-rss |
| `frontend/src/lib/queries.ts` | TanStack Query，静态站不需要 |
| `frontend/src/lib/subscription-store.ts` | localStorage 订阅，改为 data/ 文件 |
| `frontend/src/stores/settings-store.ts` | 无 API Key |
| `frontend/src/app/settings/` | 设置页删除 |
| `frontend/src/lib/__tests__/subscription-store.test.ts` | 随 store 删除 |

**修改：**

| 路径 | 变更 |
|------|------|
| `frontend/package.json` | 移除 @tanstack/react-query、zustand；新增 _shared workspace 依赖；加 marked/markdown 依赖 |
| `frontend/src/components/providers.tsx` | 移除 QueryClientProvider |
| `frontend/src/components/layout/sidebar.tsx` | 移除「设置」导航项 |
| `frontend/src/app/layout.tsx` | 不变（Providers 仍提供主题） |
| `frontend/src/app/page.tsx` | 改为 async server component，读 loaders |
| `frontend/src/app/podcasts/page.tsx` | 改 server component，读 loaders |
| `frontend/src/app/podcasts/[id]/page.tsx` | 改 server component + generateStaticParams |
| `frontend/src/app/episodes/[id]/page.tsx` | 改 server component + generateStaticParams |
| `frontend/src/app/search/page.tsx` | 改 server component，读 search-index |
| `frontend/src/types/index.ts` | 移除 Get笔记 类型，保留展示用类型 |
| `frontend/tsconfig.json` | 路径别名加 _shared 引用（或用 workspace 包名） |
| `CLAUDE.md` | 更新为 v3 架构说明 |
| `README.md` | 更新为 v3 |

---

## Task 0: pnpm workspace 与 TypeScript 配置

**Files:**
- Create: `pnpm-workspace.yaml`
- Create: `package.json`
- Create: `tsconfig.base.json`
- Modify: `.gitignore`
- Create: `data/.gitkeep`, `data/rankings/.gitkeep`, `data/podcasts/.gitkeep`

- [ ] **Step 1: 创建根 `pnpm-workspace.yaml`**

```yaml
packages:
  - frontend
  - skills/*
```

- [ ] **Step 2: 创建根 `package.json`**

```json
{
  "name": "podcastinsight",
  "private": true,
  "packageManager": "pnpm@10.33.0",
  "scripts": {
    "dev": "pnpm --filter frontend dev",
    "build": "pnpm --filter frontend build",
    "lint": "pnpm -r lint",
    "test": "pnpm -r test"
  }
}
```

- [ ] **Step 3: 创建根 `tsconfig.base.json`**

skills 和 frontend 都继承它，保证 TS 配置一致。

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["esnext"],
    "module": "esnext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

- [ ] **Step 4: 更新 `.gitignore`，加入 skills/data 中间产物**

在 `.gitignore` 末尾追加：

```
# Skills 中间产物
data/tmp/
*.tsbuildinfo
```

注意：保留 `data/rankings/`、`data/podcasts/` 等真实产出（git 跟踪），仅忽略 `data/tmp/`。

- [ ] **Step 5: 创建 `data/` 占位文件**

```bash
mkdir -p data/rankings data/podcasts
touch data/.gitkeep data/rankings/.gitkeep data/podcasts/.gitkeep
```

- [ ] **Step 6: 验证 workspace 配置**

Run: `pnpm install`
Expected: 成功识别 frontend 包（skills 包尚未创建，会警告但不应失败）。

- [ ] **Step 7: Commit**

```bash
git add pnpm-workspace.yaml package.json tsconfig.base.json .gitignore data/
git commit -m "chore: set up pnpm workspace with frontend and skills"
```

---

## Task 1: skills/_shared 共享层 — 类型与路径

**Files:**
- Create: `skills/_shared/package.json`
- Create: `skills/_shared/tsconfig.json`
- Create: `skills/_shared/src/types.ts`
- Create: `skills/_shared/src/paths.ts`
- Test: `skills/_shared/src/__tests__/paths.test.ts`

- [ ] **Step 1: 创建 `skills/_shared/package.json`**

```json
{
  "name": "@podcastinsight/shared",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "test": "vitest run"
  },
  "dependencies": {
    "fast-xml-parser": "^5.8.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "vitest": "^2.1.0",
    "tsx": "^4.19.0"
  }
}
```

- [ ] **Step 2: 创建 `skills/_shared/tsconfig.json`**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src",
    "noEmit": true
  },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: 写 `skills/_shared/src/types.ts`（对应 spec §2 数据模型）**

```typescript
// ========== Rankings ==========

export interface RankingPodcast {
  id: string;
  name: string;
  rank: number;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  author: string;
}

export interface RankingsSnapshot {
  fetched_at: string; // ISO timestamp
  source: string; // "xyzrank.com"
  podcasts: RankingPodcast[];
}

// ========== Podcast Meta ==========

export interface PodcastMeta {
  id: string;
  name: string;
  author: string;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  xyzrank_rank: number;
  subscribed: boolean;
  subscribed_at?: string; // ISO date
}

// ========== Episode ==========

export type ScrapeStatus = "pending" | "done" | "failed";
export type SummaryStatus = "pending" | "done" | "skipped";

export interface EpisodeMeta {
  id: string;
  podcast_id: string;
  title: string;
  audio_url: string;
  duration: number;
  published_at: string; // ISO timestamp
  link: string;
  description?: string;
  scraped_content_path: string; // 相对路径，如 "episodes/<id>.md"
  scrape_status: ScrapeStatus;
  summary_status: SummaryStatus;
  tags: string[];
}

// ========== Episode Markdown frontmatter ==========

export interface EpisodeMarkdownFrontmatter {
  episode_id: string;
  title: string;
  summary_status: SummaryStatus;
  generated_at?: string;
  model?: string;
}

// ========== Index ==========

export interface IndexSubscribedPodcast {
  id: string;
  name: string;
  logo_url: string;
  category: string;
  episode_count: number;
}

export interface IndexRecentEpisode {
  episode_id: string;
  podcast_id: string;
  podcast_name: string;
  title: string;
  summary_status: SummaryStatus;
  published_at: string;
}

export interface DataIndex {
  updated_at: string;
  subscribed_podcasts: IndexSubscribedPodcast[];
  recent_summarized_episodes: IndexRecentEpisode[];
  rankings_updated_at: string;
}

// ========== Search Index ==========

export interface SearchIndexEntry {
  episode_id: string;
  podcast_id: string;
  podcast_name: string;
  title: string;
  summary: string;
  published_at: string;
}

export interface SearchIndex {
  updated_at: string;
  entries: SearchIndexEntry[];
}
```

- [ ] **Step 4: 写失败测试 `skills/_shared/src/__tests__/paths.test.ts`**

```typescript
import { describe, it, expect } from "vitest";
import path from "node:path";
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
```

- [ ] **Step 5: 运行测试确认失败**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/paths.test.ts`
Expected: FAIL — 模块 `../paths` 不存在。

- [ ] **Step 6: 实现 `skills/_shared/src/paths.ts`**

```typescript
import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * 数据布局唯一真相来源。前端 loaders.ts 和所有 skills 都通过这里解析路径。
 *
 * 数据根目录解析顺序：
 * 1. 环境变量 PODCASTINSIGHT_DATA_DIR（测试/CI 可覆盖）
 * 2. 仓库根的 data/ 目录（从本文件向上回溯到 monorepo 根）
 */
export function resolveDataRoot(): string {
  if (process.env.PODCASTINSIGHT_DATA_DIR) {
    return path.resolve(process.env.PODCASTINSIGHT_DATA_DIR);
  }
  // skills/_shared/src/paths.ts → 向上 4 层到 monorepo 根
  const here = path.dirname(fileURLToPath(import.meta.url));
  const repoRoot = path.resolve(here, "..", "..", "..", "..");
  return path.join(repoRoot, "data");
}

const DATA_ROOT = resolveDataRoot();

export const PODCASTS_DIR = path.join(DATA_ROOT, "podcasts");
export const RANKINGS_FILE = path.join(DATA_ROOT, "rankings", "latest.json");
export const INDEX_FILE = path.join(DATA_ROOT, "index.json");
export const SEARCH_INDEX_FILE = path.join(DATA_ROOT, "search-index.json");

export function podcastDir(podcastId: string): string {
  return path.join(PODCASTS_DIR, podcastId);
}

export function podcastMetaFile(podcastId: string): string {
  return path.join(podcastDir(podcastId), "meta.json");
}

export function episodesDir(podcastId: string): string {
  return path.join(podcastDir(podcastId), "episodes");
}

export function episodeMetaFile(podcastId: string, episodeId: string): string {
  return path.join(episodesDir(podcastId), `${episodeId}.json`);
}

export function episodeMarkdownFile(podcastId: string, episodeId: string): string {
  return path.join(episodesDir(podcastId), `${episodeId}.md`);
}
```

- [ ] **Step 7: 运行测试确认通过**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/paths.test.ts`
Expected: PASS（5 个测试全过）。

- [ ] **Step 8: Commit**

```bash
git add skills/_shared/package.json skills/_shared/tsconfig.json skills/_shared/src/
git commit -m "feat(skills): add _shared types and path resolution"
```

---

## Task 2: skills/_shared — 文件系统原子读写

**Files:**
- Create: `skills/_shared/src/fs.ts`
- Test: `skills/_shared/src/__tests__/fs.test.ts`

- [ ] **Step 1: 写失败测试 `skills/_shared/src/__tests__/fs.test.ts`**

```typescript
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
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/fs.test.ts`
Expected: FAIL — 模块 `../fs` 不存在。

- [ ] **Step 3: 实现 `skills/_shared/src/fs.ts`**

```typescript
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
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/fs.test.ts`
Expected: PASS（5 个测试全过）。

- [ ] **Step 5: Commit**

```bash
git add skills/_shared/src/fs.ts skills/_shared/src/__tests__/fs.test.ts
git commit -m "feat(skills): add atomic JSON/text read-write helpers"
```

---

## Task 3: skills/_shared — HTTP、validate、index 入口

**Files:**
- Create: `skills/_shared/src/http.ts`
- Create: `skills/_shared/src/validate.ts`
- Create: `skills/_shared/src/lock.ts`
- Create: `skills/_shared/src/index.ts`
- Test: `skills/_shared/src/__tests__/validate.test.ts`
- Test: `skills/_shared/src/__tests__/http.test.ts`

- [ ] **Step 1: 写失败测试 `skills/_shared/src/__tests__/validate.test.ts`**

```typescript
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
```

- [ ] **Step 2: 写失败测试 `skills/_shared/src/__tests__/http.test.ts`**

```typescript
import { describe, it, expect, vi, afterEach } from "vitest";
import { fetchText, fetchJson } from "../http";

afterEach(() => vi.restoreAllMocks());

describe("http", () => {
  it("fetchText 成功返回文本", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => "<rss>hi</rss>",
    })));
    const text = await fetchText("http://example.com/feed");
    expect(text).toBe("<rss>hi</rss>");
  });

  it("fetchText 非 2xx 抛错含状态码", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: false, status: 503, text: async () => "" })));
    await expect(fetchText("http://example.com")).rejects.toThrow(/503/);
  });

  it("fetchJson 解析 JSON", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true, status: 200, json: async () => ({ a: 1 }),
    })));
    const data = await fetchJson<{ a: number }>("http://example.com");
    expect(data).toEqual({ a: 1 });
  });
});
```

- [ ] **Step 3: 运行测试确认失败**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/validate.test.ts src/__tests__/http.test.ts`
Expected: FAIL — 模块不存在。

- [ ] **Step 4: 实现 `skills/_shared/src/validate.ts`**

```typescript
import type {
  RankingsSnapshot,
  PodcastMeta,
  EpisodeMeta,
  ScrapeStatus,
  SummaryStatus,
} from "./types.js";

const SCRAPE_STATUSES: ScrapeStatus[] = ["pending", "done", "failed"];
const SUMMARY_STATUSES: SummaryStatus[] = ["pending", "done", "skipped"];

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function requireFields(obj: Record<string, unknown>, fields: string[], ctx: string): void {
  for (const f of fields) {
    if (!(f in obj) || obj[f] === undefined || obj[f] === null) {
      throw new ValidationError(`${ctx}: 缺少必填字段 "${f}"`);
    }
  }
}

export function validateRankingsSnapshot(data: unknown): asserts data is RankingsSnapshot {
  if (!isObject(data)) throw new ValidationError("rankings: 期望对象");
  requireFields(data, ["fetched_at", "source", "podcasts"], "rankings");
  if (typeof data.fetched_at !== "string") throw new ValidationError('rankings: "fetched_at" 须为字符串');
  if (typeof data.source !== "string") throw new ValidationError('rankings: "source" 须为字符串');
  if (!Array.isArray(data.podcasts)) throw new ValidationError('rankings: "podcasts" 须为数组');
  for (const p of data.podcasts) {
    if (!isObject(p)) throw new ValidationError("rankings.podcasts[]: 期望对象");
    requireFields(p, ["id", "name", "rank", "category", "logo_url", "rss_feed_url", "author"], "rankings.podcasts[]");
  }
}

export function validatePodcastMeta(data: unknown): asserts data is PodcastMeta {
  if (!isObject(data)) throw new ValidationError("meta: 期望对象");
  requireFields(
    data,
    ["id", "name", "author", "category", "logo_url", "rss_feed_url", "xyzrank_rank", "subscribed"],
    "meta"
  );
  if (typeof data.xyzrank_rank !== "number") throw new ValidationError('meta: "xyzrank_rank" 须为数字');
  if (typeof data.subscribed !== "boolean") throw new ValidationError('meta: "subscribed" 须为布尔');
}

export function validateEpisodeMeta(data: unknown): asserts data is EpisodeMeta {
  if (!isObject(data)) throw new ValidationError("episode: 期望对象");
  requireFields(
    data,
    ["id", "podcast_id", "title", "audio_url", "duration", "published_at", "link", "scraped_content_path", "scrape_status", "summary_status", "tags"],
    "episode"
  );
  if (typeof data.duration !== "number") throw new ValidationError('episode: "duration" 须为数字');
  if (!SCRAPE_STATUSES.includes(data.scrape_status as ScrapeStatus)) {
    throw new ValidationError(`episode: "scrape_status" 非法，允许 ${SCRAPE_STATUSES.join("/")}`);
  }
  if (!SUMMARY_STATUSES.includes(data.summary_status as SummaryStatus)) {
    throw new ValidationError(`episode: "summary_status" 非法，允许 ${SUMMARY_STATUSES.join("/")}`);
  }
  if (!Array.isArray(data.tags)) throw new ValidationError('episode: "tags" 须为数组');
}
```

- [ ] **Step 5: 实现 `skills/_shared/src/http.ts`**

```typescript
/**
 * HTTP 封装：统一 User-Agent、超时、错误处理。
 * 用于所有 skills 的网络抓取。
 */
const DEFAULT_UA =
  "PodcastInsight/3.0 (+https://github.com/BingqiangZhou/PodcastInsight)";
const DEFAULT_TIMEOUT_MS = 30_000;

export interface FetchOptions {
  headers?: Record<string, string>;
  timeoutMs?: number;
  accept?: string;
}

function buildHeaders(opts: FetchOptions = {}): Record<string, string> {
  return {
    "User-Agent": DEFAULT_UA,
    ...(opts.accept ? { Accept: opts.accept } : {}),
    ...(opts.headers ?? {}),
  };
}

async function withTimeout(
  input: string,
  init: RequestInit,
  timeoutMs: number
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchText(url: string, opts: FetchOptions = {}): Promise<string> {
  const res = await withTimeout(
    url,
    { headers: buildHeaders(opts) },
    opts.timeoutMs ?? DEFAULT_TIMEOUT_MS
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return res.text();
}

export async function fetchJson<T = unknown>(url: string, opts: FetchOptions = {}): Promise<T> {
  const res = await withTimeout(
    url,
    { headers: buildHeaders(opts) },
    opts.timeoutMs ?? DEFAULT_TIMEOUT_MS
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return (await res.json()) as T;
}
```

- [ ] **Step 6: 实现 `skills/_shared/src/lock.ts`**

简单的进程内串行锁，防止同一 skill 内并发写同一文件。CI 单进程内已足够。

```typescript
const locks = new Map<string, Promise<unknown>>();

/**
 * 串行化对同一 key 的异步操作。CI 单进程内避免并发写冲突。
 * （非跨进程锁；跨进程场景需用 OS 文件锁，本项目暂不需要。）
 */
export async function withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
  const prev = locks.get(key) ?? Promise.resolve();
  let release!: () => void;
  const next = new Promise<void>((resolve) => {
    release = resolve;
  });
  locks.set(key, prev.then(() => next));
  await prev;
  try {
    return await fn();
  } finally {
    release();
    if (locks.get(key) === next) locks.delete(key);
  }
}
```

- [ ] **Step 7: 实现 `skills/_shared/src/index.ts`（聚合入口）**

```typescript
export * from "./types.js";
export * from "./paths.js";
export * from "./fs.js";
export * from "./http.js";
export * from "./validate.js";
export * from "./lock.js";
```

- [ ] **Step 8: 运行全部 _shared 测试确认通过**

Run: `cd skills/_shared && pnpm vitest run`
Expected: PASS（paths 5 + fs 5 + validate 6 + http 3 = 19 个测试全过）。

- [ ] **Step 9: Commit**

```bash
git add skills/_shared/src/http.ts skills/_shared/src/validate.ts skills/_shared/src/lock.ts skills/_shared/src/index.ts skills/_shared/src/__tests__/
git commit -m "feat(skills): add http, validate, lock and _shared entry"
```

---

## Task 4: skills/_shared — 索引重建（index.json + search-index.json）

**Files:**
- Create: `skills/_shared/src/index-builder.ts`
- Test: `skills/_shared/src/__tests__/index-builder.test.ts`

各 skill 写完数据后调用 `rebuildIndexes()` 重建前端入口索引。这是 spec §3.6 的核心。

- [ ] **Step 1: 写失败测试 `skills/_shared/src/__tests__/index-builder.test.ts`**

```typescript
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
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/index-builder.test.ts`
Expected: FAIL — 模块不存在。

- [ ] **Step 3: 实现 `skills/_shared/src/index-builder.ts`**

```typescript
import { promises as fsp } from "node:fs";
import {
  PODCASTS_DIR,
  RANKINGS_FILE,
  INDEX_FILE,
  SEARCH_INDEX_FILE,
  podcastMetaFile,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
  readJsonFile,
  writeJsonAtomic,
  readTextFile,
} from "./index.js";
import type {
  PodcastMeta,
  EpisodeMeta,
  DataIndex,
  IndexSubscribedPodcast,
  IndexRecentEpisode,
  SearchIndex,
  SearchIndexEntry,
  RankingsSnapshot,
} from "./types.js";

const RECENT_EPISODE_LIMIT = 20;

/** 提取 .md 中 `## AI 摘要` 段落纯文本，用于搜索索引。 */
function extractSummaryFromMarkdown(md: string): string {
  const match = md.match(/##\s*AI\s*摘要[\s\S]*?(?=\n##\s|$)/i);
  if (!match) return "";
  return match[0].replace(/^##\s*AI\s*摘要\s*/i, "").trim();
}

/** 扫描整个 data/，重建 index.json 与 search-index.json。幂等。 */
export async function rebuildIndexes(): Promise<DataIndex> {
  const updated_at = new Date().toISOString();

  const rankings = await readJsonFile<RankingsSnapshot>(RANKINGS_FILE);
  const rankings_updated_at = rankings?.fetched_at ?? "";

  const subscribed: IndexSubscribedPodcast[] = [];
  const recentEpisodes: IndexRecentEpisode[] = [];
  const searchEntries: SearchIndexEntry[] = [];

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(PODCASTS_DIR);
  } catch {
    podcastIds = [];
  }

  for (const pid of podcastIds) {
    const meta = await readJsonFile<PodcastMeta>(podcastMetaFile(pid));
    if (!meta) continue;

    let episodeIds: string[] = [];
    try {
      episodeIds = await fsp.readdir(episodesDir(pid));
    } catch {
      episodeIds = [];
    }
    const jsonEpisodeIds = episodeIds.filter((f) => f.endsWith(".json"));

    if (meta.subscribed) {
      subscribed.push({
        id: meta.id,
        name: meta.name,
        logo_url: meta.logo_url,
        category: meta.category,
        episode_count: jsonEpisodeIds.length,
      });
    }

    for (const jf of jsonEpisodeIds) {
      const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, jf.replace(/\.json$/, "")));
      if (!ep) continue;

      if (ep.summary_status === "done") {
        recentEpisodes.push({
          episode_id: ep.id,
          podcast_id: pid,
          podcast_name: meta.name,
          title: ep.title,
          summary_status: ep.summary_status,
          published_at: ep.published_at,
        });

        const md = await readTextFile(episodeMarkdownFile(pid, ep.id));
        const summary = md ? extractSummaryFromMarkdown(md) : "";
        searchEntries.push({
          episode_id: ep.id,
          podcast_id: pid,
          podcast_name: meta.name,
          title: ep.title,
          summary,
          published_at: ep.published_at,
        });
      }
    }
  }

  recentEpisodes.sort((a, b) => b.published_at.localeCompare(a.published_at));
  const recent = recentEpisodes.slice(0, RECENT_EPISODE_LIMIT);

  const index: DataIndex = {
    updated_at,
    subscribed_podcasts: subscribed,
    recent_summarized_episodes: recent,
    rankings_updated_at,
  };
  await writeJsonAtomic(INDEX_FILE, index);

  const searchIndex: SearchIndex = { updated_at, entries: searchEntries };
  await writeJsonAtomic(SEARCH_INDEX_FILE, searchIndex);

  return index;
}

export async function loadSearchIndexSnapshot(): Promise<SearchIndex | null> {
  return readJsonFile<SearchIndex>(SEARCH_INDEX_FILE);
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd skills/_shared && pnpm vitest run src/__tests__/index-builder.test.ts`
Expected: PASS（4 个测试全过）。

- [ ] **Step 5: 运行全部 _shared 测试**

Run: `cd skills/_shared && pnpm vitest run`
Expected: PASS（所有 _shared 测试）。

- [ ] **Step 6: Commit**

```bash
git add skills/_shared/src/index-builder.ts skills/_shared/src/__tests__/index-builder.test.ts
git commit -m "feat(skills): add index and search-index rebuilder"
```

---

## Task 5: skill — fetch-rankings（抓排行榜）

**Files:**
- Create: `skills/fetch-rankings/package.json`, `tsconfig.json`
- Create: `skills/fetch-rankings/src/xyzrank-client.ts`
- Create: `skills/fetch-rankings/src/run.ts`, `src/index.ts`
- Create: `skills/fetch-rankings/SKILL.md`
- Test: `skills/fetch-rankings/__tests__/run.test.ts`

逻辑来源：移植 `frontend/src/lib/xyzrank-api.ts`（分页抓取 Top 排行）。

- [ ] **Step 1: 创建 `skills/fetch-rankings/package.json`**

```json
{
  "name": "@podcastinsight/skill-fetch-rankings",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "run": "tsx src/run.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@podcastinsight/shared": "workspace:*"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: 创建 `skills/fetch-rankings/tsconfig.json`**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "noEmit": true },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: 写失败测试 `skills/fetch-rankings/__tests__/run.test.ts`**

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import { fetchAndSaveRankings } from "../src/run";
import { RANKINGS_FILE, INDEX_FILE, readJsonFile } from "@podcastinsight/shared";
import type { RankingsSnapshot } from "@podcastinsight/shared";

let tmpDir: string;

beforeEach(async () => {
  tmpDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-rank-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpDir;
});
afterEach(async () => {
  await fsp.rm(tmpDir, { recursive: true, force: true });
  vi.restoreAllMocks();
});

const sampleXyzrankItem = (rank: number) => ({
  id: `id-${rank}`,
  name: `Podcast ${rank}`,
  rank,
  logoURL: `http://logo/${rank}`,
  primaryGenreName: "科技",
  authorsText: "Author",
  links: [{ name: "rss", url: `http://rss/${rank}` }],
  trackCount: 10,
  avgDuration: 1800,
  avgPlayCount: 1000,
});

describe("fetch-rankings run", () => {
  it("抓取并写入 latest.json，结构符合 RankingsSnapshot", async () => {
    vi.stubGlobal("fetch", vi.fn(async (url: string) => {
      const u = new URL(url);
      const offset = Number(u.searchParams.get("offset"));
      const limit = Number(u.searchParams.get("limit"));
      const items = Array.from({ length: limit }, (_, i) => sampleXyzrankItem(offset + i + 1));
      return { ok: true, status: 200, json: async () => ({ items, total: 2 }) };
    }));

    await fetchAndSaveRankings({ limit: 2 });

    const snap = await readJsonFile<RankingsSnapshot>(RANKINGS_FILE);
    expect(snap).not.toBeNull();
    expect(snap!.source).toBe("xyzrank.com");
    expect(snap!.podcasts).toHaveLength(2);
    expect(snap!.podcasts[0].id).toBe("id-1");
    expect(snap!.podcasts[0].rss_feed_url).toBe("http://rss/1");
  });

  it("抓取后重建 index.json", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true, status: 200, json: async () => ({ items: [sampleXyzrankItem(1)], total: 1 }),
    })));
    await fetchAndSaveRankings({ limit: 1 });
    const idx = await readJsonFile(INDEX_FILE);
    expect(idx).not.toBeNull();
    expect(typeof (idx as any).rankings_updated_at).toBe("string");
  });

  it("fetch 失败时不覆盖已有 latest.json", async () => {
    const { writeJsonAtomic } = await import("@podcastinsight/shared");
    await writeJsonAtomic(RANKINGS_FILE, {
      fetched_at: "2020-01-01T00:00:00Z", source: "xyzrank.com", podcasts: [],
    });
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: false, status: 500 })));
    await expect(fetchAndSaveRankings({ limit: 1 })).rejects.toThrow();
    const snap = await readJsonFile<RankingsSnapshot>(RANKINGS_FILE);
    expect(snap!.fetched_at).toBe("2020-01-01T00:00:00Z");
  });
});
```

- [ ] **Step 4: 运行测试确认失败**

Run: `cd skills/fetch-rankings && pnpm vitest run`
Expected: FAIL — 模块不存在。

- [ ] **Step 5: 实现 `skills/fetch-rankings/src/xyzrank-client.ts`**（移植自 frontend xyzrank-api.ts）

```typescript
import { fetchJson } from "@podcastinsight/shared";
import type { RankingPodcast } from "@podcastinsight/shared";

const BASE_URL = "https://xyzrank.com/api/podcasts";

interface RawItem {
  id: string;
  name: string;
  rank: number;
  logoURL?: string;
  primaryGenreName?: string;
  authorsText?: string;
  links?: { name: string; url: string }[];
}

function mapItem(raw: RawItem): RankingPodcast {
  const rssLink = raw.links?.find((l) => l.name === "rss");
  return {
    id: raw.id,
    name: raw.name,
    rank: raw.rank,
    logo_url: raw.logoURL ?? "",
    category: raw.primaryGenreName ?? "",
    author: raw.authorsText ?? "",
    rss_feed_url: rssLink?.url ?? "",
  };
}

export async function fetchRankingsPage(
  offset = 0,
  limit = 50
): Promise<{ podcasts: RankingPodcast[]; total: number }> {
  const json = await fetchJson<{ items?: RawItem[]; total?: number }>(
    `${BASE_URL}?offset=${offset}&limit=${limit}`
  );
  const items = json.items ?? [];
  const total = json.total ?? items.length;
  return { podcasts: items.map(mapItem), total };
}

export async function fetchAllRankings(batchSize = 50): Promise<RankingPodcast[]> {
  const all: RankingPodcast[] = [];
  const first = await fetchRankingsPage(0, batchSize);
  all.push(...first.podcasts);
  let offset = batchSize;
  while (all.length < first.total) {
    const batch = await fetchRankingsPage(offset, batchSize);
    all.push(...batch.podcasts);
    offset += batchSize;
  }
  return all;
}
```

- [ ] **Step 6: 实现 `skills/fetch-rankings/src/run.ts`**

```typescript
import {
  RANKINGS_FILE,
  writeJsonAtomic,
  validateRankingsSnapshot,
  rebuildIndexes,
} from "@podcastinsight/shared";
import type { RankingsSnapshot } from "@podcastinsight/shared";
import { fetchAllRankings } from "./xyzrank-client.js";

export interface FetchRankingsOptions {
  /** 每页大小，默认 50。 */
  limit?: number;
}

/** 抓取 xyzrank 全量排行并落盘。失败时保留旧快照。 */
export async function fetchAndSaveRankings(
  opts: FetchRankingsOptions = {}
): Promise<RankingsSnapshot> {
  const podcasts = await fetchAllRankings(opts.limit);
  const snapshot: RankingsSnapshot = {
    fetched_at: new Date().toISOString(),
    source: "xyzrank.com",
    podcasts,
  };
  validateRankingsSnapshot(snapshot);
  await writeJsonAtomic(RANKINGS_FILE, snapshot);
  await rebuildIndexes();
  return snapshot;
}

async function main() {
  try {
    const snap = await fetchAndSaveRankings();
    console.log(`✓ fetch-rankings: ${snap.podcasts.length} 个播客已写入`);
  } catch (e) {
    console.error("✗ fetch-rankings 失败:", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  }
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
```

- [ ] **Step 7: 实现 `skills/fetch-rankings/src/index.ts`**

```typescript
export { fetchAndSaveRankings } from "./run.js";
export { fetchAllRankings, fetchRankingsPage } from "./xyzrank-client.js";
export type { FetchRankingsOptions } from "./run.js";
```

- [ ] **Step 8: 运行测试确认通过**

Run: `cd skills/fetch-rankings && pnpm vitest run`
Expected: PASS（3 个测试全过）。

- [ ] **Step 9: 创建 `skills/fetch-rankings/SKILL.md`**

````markdown
---
name: fetch-rankings
description: 从 xyzrank.com 抓取中文播客 Top 排行榜，写入 data/rankings/latest.json。由 GitHub Actions 每周定时执行，也可手动触发。
---

# fetch-rankings

抓取 xyzrank.com 的播客排行榜（Top 1000），规范化后写入 `data/rankings/latest.json`。

## 何时使用

- GitHub Actions 每周一 08:00 UTC 自动执行
- agent 手动触发：用户说"更新排行榜""抓一下排行"时
- 排行榜数据过期需要刷新时

## 如何执行

```bash
cd skills/fetch-rankings
pnpm run
```

## 输入

无。全量抓取。

## 输出

- `data/rankings/latest.json` — 完整排行榜快照（整体覆写）
- `data/index.json` — 自动重建（更新 rankings_updated_at）

## 失败处理

抓取失败时保留上一次快照，不删除旧数据。退出码 1。

## 幂等

整体覆写，重复执行安全。
````

- [ ] **Step 10: Commit**

```bash
git add skills/fetch-rankings/
git commit -m "feat(skills): add fetch-rankings skill (xyzrank top rankings)"
```

---

## Task 6: skill — parse-rss（解析订阅播客 RSS）

**Files:**
- Create: `skills/parse-rss/{package.json,tsconfig.json}`
- Create: `skills/parse-rss/src/rss-parser.ts`
- Create: `skills/parse-rss/src/run.ts`, `src/index.ts`
- Create: `skills/parse-rss/SKILL.md`
- Test: `skills/parse-rss/__tests__/run.test.ts`

逻辑来源：移植 `frontend/src/lib/rss-parser.ts`（改用 fast-xml-parser 替代正则）+ 新增剧集落盘逻辑。

- [ ] **Step 1: 创建 `skills/parse-rss/package.json`**

```json
{
  "name": "@podcastinsight/skill-parse-rss",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "run": "tsx src/run.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@podcastinsight/shared": "workspace:*",
    "fast-xml-parser": "^5.8.0"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: 创建 `skills/parse-rss/tsconfig.json`**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "noEmit": true },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: 写失败测试 `skills/parse-rss/__tests__/run.test.ts`**

```typescript
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
```

- [ ] **Step 4: 运行测试确认失败**

Run: `cd skills/parse-rss && pnpm vitest run`
Expected: FAIL — 模块不存在。

- [ ] **Step 5: 实现 `skills/parse-rss/src/rss-parser.ts`**（用 fast-xml-parser）

```typescript
import { XMLParser } from "fast-xml-parser";
import { fetchText } from "@podcastinsight/shared";

export interface ParsedEpisode {
  title: string;
  link: string;
  guid?: string;
  description: string;
  audio_url: string;
  duration: number;
  published_at: string;
}

export interface ParsedFeed {
  title: string;
  description: string;
  episodes: ParsedEpisode[];
}

function toArray(v: unknown): unknown[] {
  if (v === undefined || v === null) return [];
  return Array.isArray(v) ? v : [v];
}

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim();
  if (v && typeof v === "object" && "#text" in (v as Record<string, unknown>)) {
    return String((v as Record<string, unknown>)["#text"]).trim();
  }
  return "";
}

function normalizeDate(raw: string): string {
  const d = new Date(raw);
  return isNaN(d.getTime()) ? raw : d.toISOString();
}

export async function parseRssFeed(feedUrl: string): Promise<ParsedFeed> {
  const xml = await fetchText(feedUrl, { accept: "application/xml, text/xml, application/rss+xml" });
  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: "@_" });
  const doc = parser.parse(xml) as Record<string, unknown>;
  const channel = (doc.rss?.channel ?? doc.channel ?? {}) as Record<string, unknown>;

  const title = toText(channel.title);
  const description = toText(channel.description);
  const rawItems = toArray(channel.item) as Record<string, unknown>[];

  const episodes: ParsedEpisode[] = [];
  for (const item of rawItems) {
    const enclosures = toArray(item.enclosure) as Record<string, unknown>[];
    const audioEnc = enclosures.find(
      (e) => typeof e["@_type"] === "string" && e["@_type"].startsWith("audio/")
    );
    const audio_url = String(audioEnc?.["@_url"] ?? "");
    if (!audio_url) continue;

    const durationRaw = toText(item["itunes:duration"] ?? item.duration);
    let duration = 0;
    const parsed = parseInt(durationRaw, 10);
    if (!isNaN(parsed)) duration = parsed;

    episodes.push({
      title: toText(item.title) || "(无标题)",
      link: toText(item.link),
      guid: toText(item.guid) || undefined,
      description: toText(item.description),
      audio_url,
      duration,
      published_at: normalizeDate(toText(item.pubDate)),
    });
  }

  return { title, description, episodes };
}
```

- [ ] **Step 6: 实现 `skills/parse-rss/src/run.ts`**

```typescript
import { createHash } from "node:crypto";
import { promises as fsp } from "node:fs";
import {
  PODCASTS_DIR,
  podcastMetaFile,
  episodeMetaFile,
  episodesDir,
  readJsonFile,
  writeJsonAtomic,
  ensureDir,
  rebuildIndexes,
} from "@podcastinsight/shared";
import type { PodcastMeta, EpisodeMeta } from "@podcastinsight/shared";
import { parseRssFeed } from "./rss-parser.js";

export interface ParseRssResult {
  newEpisodes: number;
  skipped: number;
  errors: string[];
}

/** 计算 episode id：优先 guid，否则用 audio_url 的 SHA-1 前 12 位。 */
export function computeEpisodeId(guid: string | undefined, audioUrl: string): string {
  if (guid && guid.trim()) return guid.trim();
  return createHash("sha1").update(audioUrl).digest("hex").slice(0, 12);
}

/** 扫描所有已订阅播客，解析 RSS，为新剧集写 meta。幂等。 */
export async function processSubscriptions(): Promise<ParseRssResult> {
  const result: ParseRssResult = { newEpisodes: 0, skipped: 0, errors: [] };

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(PODCASTS_DIR);
  } catch {
    return result;
  }

  for (const pid of podcastIds) {
    const meta = await readJsonFile<PodcastMeta>(podcastMetaFile(pid));
    if (!meta || !meta.subscribed || !meta.rss_feed_url) continue;

    try {
      const feed = await parseRssFeed(meta.rss_feed_url);
      for (const ep of feed.episodes) {
        const eid = computeEpisodeId(ep.guid, ep.audio_url);
        const existing = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, eid));
        if (existing) {
          result.skipped++;
          continue;
        }
        await ensureDir(episodesDir(pid));
        const episodeMeta: EpisodeMeta = {
          id: eid,
          podcast_id: pid,
          title: ep.title,
          audio_url: ep.audio_url,
          duration: ep.duration,
          published_at: ep.published_at,
          link: ep.link,
          description: ep.description,
          scraped_content_path: `episodes/${eid}.md`,
          scrape_status: "pending",
          summary_status: "pending",
          tags: [],
        };
        await writeJsonAtomic(episodeMetaFile(pid, eid), episodeMeta);
        result.newEpisodes++;
      }
    } catch (e) {
      result.errors.push(`${meta.name} (${pid}): ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  await rebuildIndexes();
  return result;
}

async function main() {
  const r = await processSubscriptions();
  console.log(`✓ parse-rss: 新增 ${r.newEpisodes}，跳过 ${r.skipped}，错误 ${r.errors.length}`);
  for (const e of r.errors) console.error("  -", e);
  process.exitCode = r.errors.length > 0 ? 1 : 0;
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
```

- [ ] **Step 7: 实现 `skills/parse-rss/src/index.ts`**

```typescript
export { processSubscriptions, computeEpisodeId } from "./run.js";
export type { ParseRssResult } from "./run.js";
export { parseRssFeed } from "./rss-parser.js";
export type { ParsedFeed, ParsedEpisode } from "./rss-parser.js";
```

- [ ] **Step 8: 运行测试确认通过**

Run: `cd skills/parse-rss && pnpm vitest run`
Expected: PASS（3 个测试全过）。

- [ ] **Step 9: 创建 `skills/parse-rss/SKILL.md`**

````markdown
---
name: parse-rss
description: 解析所有已订阅播客的 RSS feed，为新剧集写入 data/podcasts/<id>/episodes/*.json。由 GitHub Actions 每日定时执行。
---

# parse-rss

遍历 `data/podcasts/` 中所有 `subscribed: true` 的播客，抓取并解析其 RSS feed，为**新**剧集写入 episode meta。

## 何时使用

- GitHub Actions 每日 08:00 UTC 自动执行
- agent 手动触发：用户说"检查新剧集""解析一下订阅"时

## 如何执行

```bash
cd skills/parse-rss
pnpm run
```

## 输入

读取 `data/podcasts/*/meta.json` 中 `subscribed: true` 的播客及其 `rss_feed_url`。

## 输出

- 对每个新剧集：`data/podcasts/<id>/episodes/<eid>.json`（`summary_status: pending`）
- 重建 `data/index.json`

## 剧集 ID 计算

优先用 RSS `<guid>`；缺失时用 `audio_url` 的 SHA-1 前 12 位。保证幂等。

## 失败处理

单个播客 RSS 解析失败不影响其他播客；错误收集后汇总输出，退出码 1。

## 幂等

按 episode id 判断存在性，已存在的剧集跳过，只写增量。
````

- [ ] **Step 10: Commit**

```bash
git add skills/parse-rss/
git commit -m "feat(skills): add parse-rss skill (incremental episode discovery)"
```

---

## Task 7: skill — scrape-episode（抓剧集正文）

**Files:**
- Create: `skills/scrape-episode/{package.json,tsconfig.json}`
- Create: `skills/scrape-episode/src/extractor.ts`
- Create: `skills/scrape-episode/src/run.ts`, `src/index.ts`
- Create: `skills/scrape-episode/SKILL.md`
- Test: `skills/scrape-episode/__tests__/run.test.ts`

- [ ] **Step 1: 创建 `skills/scrape-episode/package.json`**

```json
{
  "name": "@podcastinsight/skill-scrape-episode",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "run": "tsx src/run.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@podcastinsight/shared": "workspace:*"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: 创建 `skills/scrape-episode/tsconfig.json`**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "noEmit": true },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: 写失败测试 `skills/scrape-episode/__tests__/run.test.ts`**

```typescript
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
```

- [ ] **Step 4: 运行测试确认失败**

Run: `cd skills/scrape-episode && pnpm vitest run`
Expected: FAIL — 模块不存在。

- [ ] **Step 5: 实现 `skills/scrape-episode/src/extractor.ts`**

```typescript
/**
 * 简易正文提取：剥离 script/style/nav，优先 article/main，否则取 body。
 * 不追求完美 readability，提供可摘要的文本即可。
 */
export function extractMainContent(html: string): string {
  let doc = html.replace(/<(script|style|nav|header|footer|noscript)[\s\S]*?<\/\1>/gi, "");
  doc = doc.replace(/<!--[\s\S]*?-->/g, "");

  const block = doc.match(/<(article|main)[\s\S]*?<\/\1>/i);
  const target = block ? block[0] : doc;

  const textParts: string[] = [];
  const tagRegex = /<(h[1-6]|p|li|blockquote|pre)[^>]*>([\s\S]*?)<\/\1>/gi;
  let m: RegExpExecArray | null;
  while ((m = tagRegex.exec(target)) !== null) {
    const text = m[2]
      .replace(/<[^>]+>/g, "")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/\s+/g, " ")
      .trim();
    if (text) textParts.push(text);
  }

  if (textParts.length === 0) {
    const fallback = target.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
    if (fallback.length > 100) return fallback.slice(0, 8000);
  }

  return textParts.join("\n\n").slice(0, 8000);
}
```

- [ ] **Step 6: 实现 `skills/scrape-episode/src/run.ts`**

```typescript
import { promises as fsp } from "node:fs";
import {
  PODCASTS_DIR,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
  readJsonFile,
  writeJsonAtomic,
  writeTextAtomic,
  ensureDir,
  rebuildIndexes,
  fetchText,
} from "@podcastinsight/shared";
import type { EpisodeMeta, EpisodeMarkdownFrontmatter } from "@podcastinsight/shared";
import { extractMainContent } from "./extractor.js";

export interface ScrapeResult {
  scraped: number;
  failed: number;
  skipped: number;
}

function buildMarkdown(frontmatter: EpisodeMarkdownFrontmatter, body: string): string {
  const fm = Object.entries({
    episode_id: frontmatter.episode_id,
    title: frontmatter.title,
    summary_status: frontmatter.summary_status,
    generated_at: frontmatter.generated_at ?? "",
    model: frontmatter.model ?? "",
  }).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join("\n");
  return `---\n${fm}\n---\n\n## 正文\n\n${body}\n`;
}

/** 扫描所有 pending 剧集，抓取网页正文写入 .md。幂等。 */
export async function scrapePending(): Promise<ScrapeResult> {
  const result: ScrapeResult = { scraped: 0, failed: 0, skipped: 0 };

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(PODCASTS_DIR);
  } catch {
    return result;
  }

  for (const pid of podcastIds) {
    let episodeFiles: string[] = [];
    try {
      episodeFiles = await fsp.readdir(episodesDir(pid));
    } catch {
      continue;
    }
    const jsonFiles = episodeFiles.filter((f) => f.endsWith(".json"));

    for (const jf of jsonFiles) {
      const eid = jf.replace(/\.json$/, "");
      const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, eid));
      if (!ep) continue;
      if (ep.scrape_status !== "pending") {
        result.skipped++;
        continue;
      }
      if (!ep.link) {
        await writeJsonAtomic(episodeMetaFile(pid, eid), { ...ep, scrape_status: "failed" });
        result.failed++;
        continue;
      }

      try {
        const html = await fetchText(ep.link);
        const body = extractMainContent(html);
        await ensureDir(episodesDir(pid));
        const md = buildMarkdown(
          { episode_id: ep.id, title: ep.title, summary_status: "pending" },
          body
        );
        await writeTextAtomic(episodeMarkdownFile(pid, eid), md);
        await writeJsonAtomic(episodeMetaFile(pid, eid), { ...ep, scrape_status: "done" });
        result.scraped++;
      } catch (e) {
        await writeJsonAtomic(episodeMetaFile(pid, eid), { ...ep, scrape_status: "failed" });
        result.failed++;
        console.error(`scrape 失败 ${pid}/${eid}: ${e instanceof Error ? e.message : e}`);
      }
    }
  }

  await rebuildIndexes();
  return result;
}

async function main() {
  const r = await scrapePending();
  console.log(`✓ scrape-episode: 抓取 ${r.scraped}，失败 ${r.failed}，跳过 ${r.skipped}`);
  process.exitCode = r.failed > 0 ? 1 : 0;
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
```

- [ ] **Step 7: 实现 `skills/scrape-episode/src/index.ts`**

```typescript
export { scrapePending } from "./run.js";
export type { ScrapeResult } from "./run.js";
export { extractMainContent } from "./extractor.js";
```

- [ ] **Step 8: 运行测试确认通过**

Run: `cd skills/scrape-episode && pnpm vitest run`
Expected: PASS（4 个测试全过）。

- [ ] **Step 9: 创建 `skills/scrape-episode/SKILL.md`**

````markdown
---
name: scrape-episode
description: 抓取 pending 剧集的网页正文，写入 data/podcasts/<id>/episodes/*.md。通常在 parse-rss 之后执行。
---

# scrape-episode

遍历所有 `scrape_status: pending` 的剧集，抓取其 `link` 网页，提取正文写入对应 `.md` 文件。

## 何时使用

- 在 parse-rss 之后链式执行（GitHub Actions 同一 workflow）
- agent 手动触发：用户说"抓正文""处理新剧集内容"时

## 如何执行

```bash
cd skills/scrape-episode
pnpm run
```

## 输入

`data/podcasts/*/episodes/*.json` 中 `scrape_status: pending` 的剧集。

## 输出

- 成功：写 `episodes/<eid>.md`（frontmatter + `## 正文`），更新 `scrape_status: done`
- 失败：`scrape_status: failed`，不写 .md（摘要步骤会跳过）
- 重建 `data/index.json`

## 正文提取

简易 readability：剥离 script/style/nav，优先 article/main，提取 h*/p/li 段落文本，截断 8000 字符。

## 幂等

已 done/failed 的剧集跳过；已存在的 .md 不重复写。
````

- [ ] **Step 10: Commit**

```bash
git add skills/scrape-episode/
git commit -m "feat(skills): add scrape-episode skill (web content extraction)"
```

---

## Task 8: skill — summarize（LLM 生成摘要）

**Files:**
- Create: `skills/summarize/{package.json,tsconfig.json}`
- Create: `skills/summarize/src/llm-client.ts`
- Create: `skills/summarize/src/run.ts`, `src/index.ts`
- Create: `skills/summarize/SKILL.md`
- Test: `skills/summarize/__tests__/run.test.ts`

注意：此 skill 由 agent 实时调用，**不在 CI 定时中执行**。需要环境变量 `LLM_API_KEY`。

- [ ] **Step 1: 创建 `skills/summarize/package.json`**

```json
{
  "name": "@podcastinsight/skill-summarize",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "run": "tsx src/run.ts",
    "test": "vitest run"
  },
  "dependencies": {
    "@podcastinsight/shared": "workspace:*"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2: 创建 `skills/summarize/tsconfig.json`**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "noEmit": true },
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 3: 写失败测试 `skills/summarize/__tests__/run.test.ts`**

```typescript
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
  // 写入已抓取的正文 md
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
    // 不写 md
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
```

- [ ] **Step 4: 运行测试确认失败**

Run: `cd skills/summarize && pnpm vitest run`
Expected: FAIL — 模块不存在。

- [ ] **Step 5: 实现 `skills/summarize/src/llm-client.ts`**

使用 OpenAI 兼容的 chat completions 接口（可对接 Claude/OpenAI/兼容网关）。配置走环境变量。

```typescript
import { fetchJson } from "@podcastinsight/shared";

export interface LlmConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
}

export function loadLlmConfig(): LlmConfig {
  const apiKey = process.env.LLM_API_KEY;
  if (!apiKey) throw new Error("环境变量 LLM_API_KEY 未设置");
  return {
    apiKey,
    baseUrl: process.env.LLM_BASE_URL ?? "https://api.openai.com/v1",
    model: process.env.LLM_MODEL ?? "gpt-4o-mini",
  };
}

const SYSTEM_PROMPT = `你是一个播客内容摘要助手。给定剧集正文，请：
1. 生成一段 150-300 字的中文摘要，提炼核心观点。
2. 提取 2-5 个标签（简短词语）。
严格只返回 JSON，格式：{"summary": "...", "tags": ["...", "..."]}。不要包含其他文字或代码块标记。`;

export interface SummarizeOutput {
  summary: string;
  tags: string[];
}

export async function generateSummary(
  config: LlmConfig,
  title: string,
  content: string
): Promise<SummarizeOutput> {
  const userPrompt = `标题：${title}\n\n正文：\n${content.slice(0, 6000)}`;

  const body = await fetchJson<{
    choices?: { message?: { content?: string } }[];
  }>(`${config.baseUrl}/chat/completions`, {
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
    },
    // fetchJson 用 GET 默认，这里需 POST
  }).catch(async () => {
    // fetchJson 不支持 POST，改用原生 fetch
    const res = await fetch(`${config.baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify({
        model: config.model,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.3,
      }),
    });
    if (!res.ok) throw new Error(`LLM 请求失败: ${res.status}`);
    return (await res.json()) as { choices?: { message?: { content?: string } }[] };
  });

  const content2 = body.choices?.[0]?.message?.content ?? "";
  const cleaned = content2.replace(/```json\s*|\s*```/g, "").trim();
  const parsed = JSON.parse(cleaned) as SummarizeOutput;
  return {
    summary: String(parsed.summary ?? "").trim(),
    tags: Array.isArray(parsed.tags) ? parsed.tags.map(String) : [],
  };
}
```

- [ ] **Step 6: 实现 `skills/summarize/src/run.ts`**

```typescript
import { promises as fsp } from "node:fs";
import {
  PODCASTS_DIR,
  episodesDir,
  episodeMetaFile,
  episodeMarkdownFile,
  readJsonFile,
  readTextFile,
  writeJsonAtomic,
  writeTextAtomic,
  ensureDir,
  rebuildIndexes,
} from "@podcastinsight/shared";
import type { EpisodeMeta, EpisodeMarkdownFrontmatter } from "@podcastinsight/shared";
import { generateSummary, loadLlmConfig } from "./llm-client.js";

export interface SummarizeResult {
  ok: boolean;
  reason?: string;
}

export interface BatchResult {
  summarized: number;
  skipped: number;
  failed: number;
  errors: string[];
}

/** 从 .md 中提取 `## 正文` 段落内容。 */
function extractBody(md: string): string {
  const match = md.match(/##\s*正文[\s\S]*?(?=\n##\s|$)/i);
  if (!match) return "";
  return match[0].replace(/^##\s*正文\s*/i, "").trim();
}

/** 用新摘要重写整个 .md：frontmatter + AI 摘要 + 标签 + 原正文。 */
function rewriteMarkdownWithSummary(
  oldMd: string,
  frontmatter: EpisodeMarkdownFrontmatter,
  summary: string,
  tags: string[]
): string {
  const fm = Object.entries({
    episode_id: frontmatter.episode_id,
    title: frontmatter.title,
    summary_status: "done",
    generated_at: frontmatter.generated_at ?? new Date().toISOString(),
    model: frontmatter.model ?? process.env.LLM_MODEL ?? "",
  }).map(([k, v]) => `${k}: ${JSON.stringify(v)}`).join("\n");

  const body = extractBody(oldMd) || "(无正文)";
  const tagsLine = tags.length > 0 ? tags.map((t) => `#${t}`).join(" ") : "";

  return `---\n${fm}\n---\n\n## AI 摘要\n\n${summary}\n${tagsLine ? `\n## 标签\n\n${tagsLine}\n` : ""}## 正文\n\n${body}\n`;
}

/** 对单集生成摘要。 */
export async function summarizeEpisode(
  podcastId: string,
  episodeId: string
): Promise<SummarizeResult> {
  const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(podcastId, episodeId));
  if (!ep) return { ok: false, reason: "not-found" };
  if (ep.summary_status === "done") return { ok: false, reason: "already-done" };

  const md = await readTextFile(episodeMarkdownFile(podcastId, episodeId));
  if (!md) return { ok: false, reason: "no-content" };
  const body = extractBody(md);
  if (!body) return { ok: false, reason: "no-content" };

  const config = loadLlmConfig();
  const { summary, tags } = await generateSummary(config, ep.title, body);

  const newMd = rewriteMarkdownWithSummary(
    md,
    { episode_id: ep.id, title: ep.title, summary_status: "done" },
    summary,
    tags
  );
  await writeTextAtomic(episodeMarkdownFile(podcastId, episodeId), newMd);
  await writeJsonAtomic(episodeMetaFile(podcastId, episodeId), {
    ...ep,
    summary_status: "done",
    tags,
  });
  return { ok: true };
}

/** 批量处理所有 pending 且有正文的剧集。 */
export async function summarizePending(): Promise<BatchResult> {
  const result: BatchResult = { summarized: 0, skipped: 0, failed: 0, errors: [] };

  let podcastIds: string[] = [];
  try {
    podcastIds = await fsp.readdir(PODCASTS_DIR);
  } catch {
    return result;
  }

  for (const pid of podcastIds) {
    let episodeFiles: string[] = [];
    try {
      episodeFiles = await fsp.readdir(episodesDir(pid));
    } catch {
      continue;
    }
    for (const jf of episodeFiles.filter((f) => f.endsWith(".json"))) {
      const eid = jf.replace(/\.json$/, "");
      const ep = await readJsonFile<EpisodeMeta>(episodeMetaFile(pid, eid));
      if (!ep || ep.summary_status !== "pending") {
        result.skipped++;
        continue;
      }
      try {
        const r = await summarizeEpisode(pid, eid);
        if (r.ok) result.summarized++;
        else result.skipped++;
      } catch (e) {
        result.failed++;
        result.errors.push(`${pid}/${eid}: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }

  await rebuildIndexes();
  return result;
}

/** CLI 入口：支持 `--episode <podcastId>/<episodeId>` 或无参数批量。 */
async function main() {
  const arg = process.argv.find((a) => a.startsWith("--episode="));
  try {
    if (arg) {
      const target = arg.replace("--episode=", "");
      const [pid, eid] = target.split("/");
      if (!pid || !eid) throw new Error("用法: --episode=<podcastId>/<episodeId>");
      const r = await summarizeEpisode(pid, eid);
      console.log(r.ok ? `✓ summarize: ${pid}/${eid} 完成` : `⊘ summarize: ${pid}/${eid} 跳过 (${r.reason})`);
      process.exitCode = r.ok ? 0 : 0;
    } else {
      const r = await summarizePending();
      console.log(`✓ summarize: 生成 ${r.summarized}，跳过 ${r.skipped}，失败 ${r.failed}`);
      for (const e of r.errors) console.error("  -", e);
      process.exitCode = r.failed > 0 ? 1 : 0;
    }
  } catch (e) {
    console.error("✗ summarize 失败:", e instanceof Error ? e.message : e);
    process.exitCode = 1;
  }
}

const isDirect = process.argv[1]?.endsWith("run.ts") || process.argv[1]?.endsWith("run.mjs");
if (isDirect) main();
```

- [ ] **Step 7: 实现 `skills/summarize/src/index.ts`**

```typescript
export { summarizeEpisode, summarizePending } from "./run.js";
export type { SummarizeResult, BatchResult } from "./run.js";
export { generateSummary, loadLlmConfig } from "./llm-client.js";
export type { LlmConfig, SummarizeOutput } from "./llm-client.js";
```

- [ ] **Step 8: 运行测试确认通过**

Run: `cd skills/summarize && pnpm vitest run`
Expected: PASS（4 个测试全过）。

- [ ] **Step 9: 创建 `skills/summarize/SKILL.md`**

````markdown
---
name: summarize
description: 为已抓取正文的剧集生成 AI 摘要和标签，写回 data/podcasts/<id>/episodes/*.md 与 *.json。由 agent 实时调用，需要 LLM_API_KEY。
---

# summarize

读取 pending 剧集的正文，调用 LLM 生成中文摘要和标签，写回 markdown 和 episode meta。

## 何时使用

- **由 agent 实时调用**（不在 CI 定时中）
- 用户说"生成摘要""处理 pending 剧集""给 XX 播客最近的剧集做摘要"时
- 不建议大批量调用（LLM 成本）；可先用 parse-rss + scrape-episode 准备好素材

## 前置条件

- 环境变量 `LLM_API_KEY` 必须设置（本地 .env 或运行环境注入）
- 可选：`LLM_BASE_URL`（默认 OpenAI，可指向兼容网关）、`LLM_MODEL`（默认 gpt-4o-mini）

## 如何执行

```bash
# 批量处理所有 pending 剧集
cd skills/summarize
pnpm run

# 处理单集
pnpm run -- --episode=<podcastId>/<episodeId>
```

## 输入

`scrape_status: done` 且 `summary_status: pending` 的剧集，及其 `.md` 中的 `## 正文`。

## 输出

- 在 `.md` 中插入 `## AI 摘要` 和 `## 标签` 段落，更新 frontmatter `summary_status: done`
- 在 `<eid>.json` 中更新 `summary_status: done` 和 `tags`
- 重建 `data/index.json` 和 `data/search-index.json`

## LLM 接口

使用 OpenAI 兼容的 chat completions 接口。System prompt 要求严格返回 `{"summary","tags"}` JSON。

## 失败处理

单集失败标记 failed 但不影响其他集；未抓取正文的剧集标记 skipped。

## 幂等

已 done 的剧集不重复处理。
````

- [ ] **Step 10: Commit**

```bash
git add skills/summarize/
git commit -m "feat(skills): add summarize skill (LLM summary generation)"
```

---

## Task 9: 前端改造 — 数据读取层与类型清理

**Files:**
- Create: `frontend/src/lib/loaders.ts`
- Create: `frontend/src/lib/markdown.ts`
- Modify: `frontend/src/types/index.ts`
- Modify: `frontend/package.json`
- Test: `frontend/src/lib/__tests__/loaders.test.ts`

这是前端从"动态 BFF"转向"静态读 data/"的核心改造。先做数据层，再做页面（Task 10）。

- [ ] **Step 1: 改造 `frontend/src/types/index.ts`**

移除所有 Get笔记 / xyzrank 原始类型，只保留前端展示用类型。整体替换为：

```typescript
// ========== 前端展示用类型（来自 data/） ==========

export interface RankingPodcast {
  id: string;
  name: string;
  rank: number;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  author: string;
}

export interface RankingsData {
  fetched_at: string;
  source: string;
  podcasts: RankingPodcast[];
}

export interface PodcastMeta {
  id: string;
  name: string;
  author: string;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  xyzrank_rank: number;
  subscribed: boolean;
  subscribed_at?: string;
}

export type ScrapeStatus = "pending" | "done" | "failed";
export type SummaryStatus = "pending" | "done" | "skipped";

export interface EpisodeMeta {
  id: string;
  podcast_id: string;
  title: string;
  audio_url: string;
  duration: number;
  published_at: string;
  link: string;
  description?: string;
  scraped_content_path: string;
  scrape_status: ScrapeStatus;
  summary_status: SummaryStatus;
  tags: string[];
}

export interface DataIndex {
  updated_at: string;
  subscribed_podcasts: {
    id: string;
    name: string;
    logo_url: string;
    category: string;
    episode_count: number;
  }[];
  recent_summarized_episodes: {
    episode_id: string;
    podcast_id: string;
    podcast_name: string;
    title: string;
    summary_status: SummaryStatus;
    published_at: string;
  }[];
  rankings_updated_at: string;
}

export interface SearchIndexEntry {
  episode_id: string;
  podcast_id: string;
  podcast_name: string;
  title: string;
  summary: string;
  published_at: string;
}

export interface SearchIndex {
  updated_at: string;
  entries: SearchIndexEntry[];
}

/** episode .md 解析结果（frontmatter + 摘要 + 正文） */
export interface EpisodeContent {
  frontmatter: {
    episode_id: string;
    title: string;
    summary_status: SummaryStatus;
    generated_at?: string;
    model?: string;
  };
  summary: string;
  tags: string[];
  body: string;
}
```

- [ ] **Step 2: 修改 `frontend/package.json`**

移除 `@tanstack/react-query`、`zustand`；新增 markdown 渲染依赖；添加 `@podcastinsight/shared` workspace 依赖用于类型。注意：前端只引用 shared 的**类型**，运行时逻辑不依赖。

将 dependencies 改为：

```json
{
  "dependencies": {
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-label": "^2.1.0",
    "@radix-ui/react-select": "^2.1.0",
    "@radix-ui/react-slot": "^1.1.0",
    "@radix-ui/react-tabs": "^1.1.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "marked": "^12.0.0",
    "lucide-react": "^0.460.0",
    "next": "^16.2.6",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "sonner": "^1.7.0",
    "tailwind-merge": "^2.6.0"
  }
}
```

移除项：`@tanstack/react-query`、`fast-xml-parser`、`zustand`。
新增项：`marked`。
fast-xml-parser 不再需要（RSS 解析在 skills 里）。

- [ ] **Step 3: 写失败测试 `frontend/src/lib/__tests__/loaders.test.ts`**

```typescript
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { promises as fsp } from "node:fs";
import path from "node:path";
import os from "node:os";
import { writeJsonAtomic } from "../../lib/fs-shim";

let tmpData: string;
const oldDataDir = process.env.PODCASTINSIGHT_DATA_DIR;

beforeEach(async () => {
  tmpData = await fsp.mkdtemp(path.join(os.tmpdir(), "pi-fe-"));
  process.env.PODCASTINSIGHT_DATA_DIR = tmpData;
});
afterEach(async () => {
  process.env.PODCASTINSIGHT_DATA_DIR = oldDataDir;
  await fsp.rm(tmpData, { recursive: true, force: true });
});

describe("loaders", () => {
  it("loadIndex 返回 DataIndex", async () => {
    const { writeJsonAtomic: wj } = await import("@podcastinsight/shared");
    await wj(path.join(tmpData, "index.json"), {
      updated_at: "2026-07-01T00:00:00Z",
      subscribed_podcasts: [],
      recent_summarized_episodes: [],
      rankings_updated_at: "2026-07-01T00:00:00Z",
    });
    const { loadIndex } = await import("../loaders");
    const idx = await loadIndex();
    expect(idx.rankings_updated_at).toBe("2026-07-01T00:00:00Z");
  });
});
```

注意：测试通过设置 `PODCASTINSIGHT_DATA_DIR` 让 loaders 读临时目录。`loaders.ts` 内部复用 shared 的 `resolveDataRoot()`。

- [ ] **Step 4: 运行测试确认失败**

Run: `cd frontend && pnpm vitest run src/lib/__tests__/loaders.test.ts`
Expected: FAIL — `loaders` 不存在。

- [ ] **Step 5: 实现 `frontend/src/lib/loaders.ts`**

```typescript
import { promises as fsp } from "node:fs";
import path from "node:path";
import type {
  RankingsData,
  PodcastMeta,
  EpisodeMeta,
  EpisodeContent,
  DataIndex,
  SearchIndex,
} from "@/types";

// 复用 _shared 的数据根解析逻辑（前端构建期在 Node 环境）
function dataRoot(): string {
  if (process.env.PODCASTINSIGHT_DATA_DIR) {
    return path.resolve(process.env.PODCASTINSIGHT_DATA_DIR);
  }
  // frontend/src/lib/ → 向上 4 层到 monorepo 根
  return path.resolve(process.cwd(), "..", "data");
}

const DR = dataRoot();
const PODCASTS_DIR = path.join(DR, "podcasts");

export async function loadIndex(): Promise<DataIndex> {
  const raw = await fsp.readFile(path.join(DR, "index.json"), "utf8");
  return JSON.parse(raw) as DataIndex;
}

export async function loadRankings(): Promise<RankingsData> {
  const raw = await fsp.readFile(path.join(DR, "rankings", "latest.json"), "utf8");
  return JSON.parse(raw) as RankingsData;
}

export async function loadSearchIndex(): Promise<SearchIndex> {
  const raw = await fsp.readFile(path.join(DR, "search-index.json"), "utf8");
  return JSON.parse(raw) as SearchIndex;
}

export async function loadPodcastMeta(id: string): Promise<PodcastMeta | null> {
  try {
    const raw = await fsp.readFile(path.join(PODCASTS_DIR, id, "meta.json"), "utf8");
    return JSON.parse(raw) as PodcastMeta;
  } catch {
    return null;
  }
}

export async function loadEpisodes(podcastId: string): Promise<EpisodeMeta[]> {
  const dir = path.join(PODCASTS_DIR, podcastId, "episodes");
  let files: string[] = [];
  try {
    files = await fsp.readdir(dir);
  } catch {
    return [];
  }
  const jsonFiles = files.filter((f) => f.endsWith(".json"));
  const episodes: EpisodeMeta[] = [];
  for (const f of jsonFiles) {
    const raw = await fsp.readFile(path.join(dir, f), "utf8");
    episodes.push(JSON.parse(raw) as EpisodeMeta);
  }
  // 按发布时间倒序
  return episodes.sort((a, b) => b.published_at.localeCompare(a.published_at));
}

export async function loadEpisodeContent(
  podcastId: string,
  episodeId: string
): Promise<EpisodeContent | null> {
  const metaPath = path.join(PODCASTS_DIR, podcastId, "episodes", `${episodeId}.json`);
  const mdPath = path.join(PODCASTS_DIR, podcastId, "episodes", `${episodeId}.md`);
  try {
    const meta = JSON.parse(await fsp.readFile(metaPath, "utf8")) as EpisodeMeta;
    let md = "";
    try {
      md = await fsp.readFile(mdPath, "utf8");
    } catch {
      md = "";
    }
    return parseEpisodeMarkdown(md, meta);
  } catch {
    return null;
  }
}

/** 枚举所有播客 id（用于 generateStaticParams）。 */
export async function listPodcastIds(): Promise<string[]> {
  try {
    const entries = await fsp.readdir(PODCASTS_DIR, { withFileTypes: true });
    return entries.filter((e) => e.isDirectory()).map((e) => e.name);
  } catch {
    return [];
  }
}

/** 枚举某播客下所有剧集 id。 */
export async function listEpisodeIds(podcastId: string): Promise<string[]> {
  const dir = path.join(PODCASTS_DIR, podcastId, "episodes");
  try {
    const files = await fsp.readdir(dir);
    return files.filter((f) => f.endsWith(".json")).map((f) => f.replace(/\.json$/, ""));
  } catch {
    return [];
  }
}

// 导入解析函数（在 markdown.ts 定义）
import { parseEpisodeMarkdown } from "./markdown";
```

- [ ] **Step 6: 实现 `frontend/src/lib/markdown.ts`**

```typescript
import { marked } from "marked";
import type { EpisodeContent, EpisodeMeta, SummaryStatus } from "@/types";

/** 解析 episode .md：分离 frontmatter、摘要、正文。 */
export function parseEpisodeMarkdown(md: string, meta: EpisodeMeta): EpisodeContent {
  let fmRaw = "";
  let body = md;
  const fmMatch = md.match(/^---\n([\s\S]*?)\n---\n/);
  if (fmMatch) {
    fmRaw = fmMatch[1];
    body = md.slice(fmMatch[0].length);
  }

  // 简易 YAML frontmatter 解析
  const fm: Record<string, string> = {};
  for (const line of fmRaw.split("\n")) {
    const m = line.match(/^(\w+):\s*(.*)$/);
    if (m) {
      fm[m[1]] = m[2].replace(/^"|"$/g, "");
    }
  }

  // 提取 AI 摘要段落
  const summaryMatch = body.match(/##\s*AI\s*摘要[\s\S]*?(?=\n##\s|$)/i);
  let summary = "";
  if (summaryMatch) {
    summary = summaryMatch[0].replace(/^##\s*AI\s*摘要\s*/i, "").trim();
  }

  // 提取标签段落
  const tagsMatch = body.match(/##\s*标签[\s\S]*?(?=\n##\s|$)/i);
  let tags: string[] = [];
  if (tagsMatch) {
    tags = tagsMatch[0]
      .replace(/^##\s*标签\s*/i, "")
      .split(/[#\s]+/)
      .map((t) => t.trim())
      .filter(Boolean);
  }

  // 提取正文段落
  const bodyMatch = body.match(/##\s*正文[\s\S]*$/i);
  const bodyText = bodyMatch ? bodyMatch[0].replace(/^##\s*正文\s*/i, "").trim() : "";

  return {
    frontmatter: {
      episode_id: fm.episode_id ?? meta.id,
      title: fm.title ?? meta.title,
      summary_status: (fm.summary_status as SummaryStatus) ?? meta.summary_status,
      generated_at: fm.generated_at || undefined,
      model: fm.model || undefined,
    },
    summary,
    tags: tags.length > 0 ? tags : meta.tags,
    body: bodyText,
  };
}

/** 把 markdown 文本渲染为 HTML。 */
export function renderMarkdown(md: string): string {
  return marked.parse(md, { async: false }) as string;
}
```

- [ ] **Step 7: 运行测试确认通过**

Run: `cd frontend && pnpm vitest run src/lib/__tests__/loaders.test.ts`
Expected: PASS。

- [ ] **Step 8: 删除不再需要的测试文件**

```bash
git rm frontend/src/lib/__tests__/subscription-store.test.ts
```

- [ ] **Step 9: Commit**

```bash
git add frontend/src/lib/loaders.ts frontend/src/lib/markdown.ts frontend/src/types/index.ts frontend/package.json frontend/src/lib/__tests__/loaders.test.ts
git rm frontend/src/lib/__tests__/subscription-store.test.ts
git commit -m "feat(frontend): add static data loaders and markdown parser"
```

---

## Task 10: 前端改造 — 删除动态层 + 改造页面

**Files:**
- Delete: `frontend/src/app/api/`（整个目录）
- Delete: `frontend/src/lib/{getnote-api,xyzrank-api,rss-parser,queries,subscription-store}.ts`
- Delete: `frontend/src/stores/`（整个目录）
- Delete: `frontend/src/app/settings/`（整个目录）
- Modify: `frontend/src/components/providers.tsx`
- Modify: `frontend/src/components/layout/sidebar.tsx`
- Modify: `frontend/src/app/page.tsx`
- Modify: `frontend/src/app/podcasts/page.tsx`
- Modify: `frontend/src/app/podcasts/[id]/page.tsx`
- Modify: `frontend/src/app/episodes/[id]/page.tsx`
- Modify: `frontend/src/app/search/page.tsx`

- [ ] **Step 1: 删除所有动态层文件**

```bash
git rm -r frontend/src/app/api
git rm frontend/src/lib/getnote-api.ts
git rm frontend/src/lib/xyzrank-api.ts
git rm frontend/src/lib/rss-parser.ts
git rm frontend/src/lib/queries.ts
git rm frontend/src/lib/subscription-store.ts
git rm -r frontend/src/stores
git rm -r frontend/src/app/settings
```

- [ ] **Step 2: 改造 `frontend/src/components/providers.tsx`**

移除 QueryClient。整体替换为：

```tsx
import { Toaster } from 'sonner';
import { Sidebar } from '@/components/layout/sidebar';
import { SidebarProvider } from '@/components/layout/sidebar-context';
import { ThemeProvider } from '@/components/layout/theme-provider';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <SidebarProvider>
        <div className="flex h-screen overflow-hidden">
          <Sidebar />
          <main className="flex-1 overflow-y-auto">
            <div className="container mx-auto max-w-7xl px-4 pt-20 pb-6 lg:px-8 lg:pt-6">
              {children}
            </div>
          </main>
        </div>
      </SidebarProvider>
      <Toaster position="top-right" richColors />
    </ThemeProvider>
  );
}
```

- [ ] **Step 3: 改造 `frontend/src/components/layout/sidebar.tsx`**

移除「设置」导航项。将 `navItems` 数组改为（删除 settings 项）：

```tsx
const navItems = [
  { label: '仪表盘', href: '/', icon: LayoutDashboard },
  { label: '播客', href: '/podcasts', icon: Podcast },
  { label: '搜索', href: '/search', icon: Search },
];
```

同时移除文件顶部 import 中不再使用的 `Settings` 图标，以及 footer 中 `v2` 改为 `v3`：

```tsx
<p className="text-[11px] text-sidebar-foreground/30">
  PodcastInsight v3
</p>
```

- [ ] **Step 4: 改造 `frontend/src/app/page.tsx`（仪表盘）**

改为 async server component，从 loaders 读数据。整体替换文件：

```tsx
import Link from 'next/link';
import Image from 'next/image';
import { Podcast, FileText, ArrowRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { loadIndex } from '@/lib/loaders';
import type { DataIndex } from '@/types';

export default async function DashboardPage() {
  let index: DataIndex | null = null;
  try {
    index = await loadIndex();
  } catch {
    index = null;
  }

  const subscriptions = index?.subscribed_podcasts ?? [];
  const recent = index?.recent_summarized_episodes ?? [];

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight">PodcastInsight</h1>
        <Link href="/podcasts" className="inline-flex items-center gap-1.5 text-sm text-primary hover:underline">
          <Podcast className="h-4 w-4" />
          发现播客
        </Link>
      </div>

      {/* 已订阅播客 */}
      <section className="space-y-4">
        <h2 className="flex items-center gap-2 text-lg font-semibold">
          <Podcast className="h-5 w-5 text-primary" />
          已订阅播客
        </h2>
        {subscriptions.length > 0 ? (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {subscriptions.map((sub) => (
              <Link key={sub.id} href={`/podcasts/${sub.id}`} className="group block">
                <Card className="overflow-hidden transition-all duration-200 hover:border-primary/20 hover:shadow-md">
                  <CardContent className="p-4">
                    <div className="flex items-start gap-3">
                      <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
                        {sub.logo_url ? (
                          <Image src={sub.logo_url} alt={sub.name} fill className="object-cover" sizes="56px" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-lg font-bold text-muted-foreground">
                            {sub.name.charAt(0)}
                          </div>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <h3 className="truncate text-sm font-semibold leading-tight group-hover:text-primary">
                          {sub.name}
                        </h3>
                        {sub.category && <p className="mt-1 truncate text-xs text-muted-foreground">{sub.category}</p>}
                        <p className="mt-1 text-xs text-muted-foreground">{sub.episode_count} 集</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-16">
            <Podcast className="h-10 w-10 text-muted-foreground/40" />
            <p className="mt-3 text-sm text-muted-foreground">还没有订阅任何播客</p>
            <p className="mt-1 text-xs text-muted-foreground/60">通过 skills 配置 data/podcasts/ 后显示</p>
          </div>
        )}
      </section>

      {/* 最近摘要 */}
      <section className="space-y-4">
        <h2 className="flex items-center gap-2 text-lg font-semibold">
          <FileText className="h-5 w-5 text-primary" />
          最近摘要
        </h2>
        {recent.length > 0 ? (
          <div className="divide-y rounded-lg border">
            {recent.map((ep) => (
              <Link
                key={ep.episode_id}
                href={`/podcasts/${ep.podcast_id}/${ep.episode_id}`}
                className="group flex items-center gap-4 px-4 py-3 transition-colors hover:bg-muted/30"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium group-hover:text-primary">{ep.title || '无标题'}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {ep.podcast_name} · {ep.published_at ? new Date(ep.published_at).toLocaleDateString('zh-CN') : ''}
                  </p>
                </div>
                <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
              </Link>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-16">
            <FileText className="h-10 w-10 text-muted-foreground/40" />
            <p className="mt-3 text-sm text-muted-foreground">暂无摘要</p>
            <p className="mt-1 text-xs text-muted-foreground/60">运行 summarize skill 后显示</p>
          </div>
        )}
      </section>
    </div>
  );
}
```

注意：剧集详情路由从 `/episodes/[id]` 改为 `/podcasts/[id]/[episodeId]`（嵌套，因为现在按播客目录组织数据）。见 Step 6-7。

- [ ] **Step 5: 改造 `frontend/src/app/podcasts/page.tsx`（排行榜）**

改为 server component，读 rankings。保留表格 UI，移除订阅按钮（订阅现在通过 skills 配置 meta.json）。整体替换：

```tsx
import Image from 'next/image';
import Link from 'next/link';
import { Trophy } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { loadRankings } from '@/lib/loaders';
import type { RankingsData } from '@/types';

export default async function PodcastsPage() {
  let data: RankingsData | null = null;
  try {
    data = await loadRankings();
  } catch {
    data = null;
  }
  const podcasts = data?.podcasts ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Trophy className="h-6 w-6 text-yellow-500" />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">播客排行榜</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            共 {podcasts.length} 个播客
            {data?.fetched_at && ` · 更新于 ${new Date(data.fetched_at).toLocaleDateString('zh-CN')}`}
          </p>
        </div>
      </div>

      {podcasts.length > 0 ? (
        <div className="rounded-xl border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-16 text-center">排名</TableHead>
                <TableHead className="w-12" />
                <TableHead>名称</TableHead>
                <TableHead className="hidden md:table-cell">作者</TableHead>
                <TableHead className="hidden sm:table-cell">分类</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {podcasts.map((p) => {
                const rank = p.rank;
                const rankDisplay = rank <= 3 ? (
                  <span className={`inline-flex h-7 w-7 items-center justify-center rounded-full text-sm font-bold ${
                    rank === 1 ? 'bg-yellow-500/15 text-yellow-600'
                      : rank === 2 ? 'bg-gray-400/15 text-gray-500'
                      : 'bg-orange-400/15 text-orange-600'
                  }`}>{rank}</span>
                ) : (
                  <span className="text-sm tabular-nums text-muted-foreground">{rank}</span>
                );
                return (
                  <TableRow key={p.id} className="cursor-pointer" >
                    <TableCell className="text-center">{rankDisplay}</TableCell>
                    <TableCell>
                      {p.logo_url ? (
                        <Image src={p.logo_url} alt={p.name} width={40} height={40} className="h-10 w-10 rounded object-cover" />
                      ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded bg-muted text-xs font-medium">{p.name.charAt(0)}</div>
                      )}
                    </TableCell>
                    <TableCell>
                      <Link href={`/podcasts/${p.id}`} className="font-medium line-clamp-1 hover:text-primary">{p.name}</Link>
                    </TableCell>
                    <TableCell className="hidden md:table-cell text-muted-foreground line-clamp-1">{p.author}</TableCell>
                    <TableCell className="hidden sm:table-cell">
                      {p.category ? <Badge variant="secondary">{p.category}</Badge> : <span className="text-muted-foreground">-</span>}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center rounded-xl border bg-card py-20">
          <p className="text-sm text-muted-foreground">暂无排行榜数据</p>
          <p className="mt-1 text-xs text-muted-foreground/60">运行 fetch-rankings skill 后显示</p>
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 6: 改造 `frontend/src/app/podcasts/[id]/page.tsx`（播客详情）**

改为 server component + `generateStaticParams`，显示播客信息和剧集列表：

```tsx
import Image from 'next/image';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Clock } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { loadPodcastMeta, loadEpisodes, listPodcastIds } from '@/lib/loaders';
import { formatDuration } from '@/lib/utils';

export async function generateStaticParams() {
  const ids = await listPodcastIds();
  return ids.map((id) => ({ id }));
}

function formatDate(s: string): string {
  try { return new Date(s).toLocaleDateString('zh-CN'); } catch { return s; }
}

export default async function PodcastDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const meta = await loadPodcastMeta(id);
  if (!meta) notFound();
  const episodes = await loadEpisodes(id);

  return (
    <div className="space-y-6">
      <Link href="/podcasts" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-4 w-4" />
        返回排行榜
      </Link>

      <Card>
        <CardContent className="p-6">
          <div className="flex flex-col gap-6 sm:flex-row sm:items-start">
            <div className="relative h-24 w-24 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
              {meta.logo_url ? (
                <Image src={meta.logo_url} alt={meta.name} fill className="object-cover" sizes="96px" />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-3xl font-bold text-muted-foreground">{meta.name.charAt(0)}</div>
              )}
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="text-xl font-bold">{meta.name}</h1>
              <p className="mt-1 text-sm text-muted-foreground">{meta.author}</p>
              <div className="mt-3 flex flex-wrap items-center gap-2">
                {meta.category && <Badge variant="outline">{meta.category}</Badge>}
                <Badge variant={meta.subscribed ? 'default' : 'secondary'}>
                  {meta.subscribed ? '已订阅' : '未订阅'}
                </Badge>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            剧集列表
            <span className="ml-2 text-sm font-normal text-muted-foreground">({episodes.length} 集)</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {episodes.length > 0 ? (
            <div className="space-y-3">
              {episodes.map((ep) => (
                <Link
                  key={ep.id}
                  href={`/podcasts/${id}/${ep.id}`}
                  className="block rounded-lg border p-4 transition-colors hover:bg-muted/50"
                >
                  <h3 className="font-medium leading-snug">{ep.title}</h3>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                    {ep.published_at && (
                      <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{formatDate(ep.published_at)}</span>
                    )}
                    {ep.duration > 0 && <span>{formatDuration(ep.duration)}</span>}
                    {ep.summary_status === 'done' && <Badge variant="secondary" className="text-xs">已摘要</Badge>}
                  </div>
                  {ep.tags.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1">
                      {ep.tags.map((t) => <Badge key={t} variant="outline" className="text-xs">{t}</Badge>)}
                    </div>
                  )}
                </Link>
              ))}
            </div>
          ) : (
            <p className="py-10 text-center text-sm text-muted-foreground">暂无剧集</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 7: 创建 `frontend/src/app/podcasts/[id]/[episodeId]/page.tsx`（剧集详情）**

替换原 `episodes/[id]` 路由。新路径为 `/podcasts/[id]/[episodeId]`：

```tsx
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Sparkles, Calendar, Tag } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  loadEpisodeContent, loadPodcastMeta, listPodcastIds, listEpisodeIds,
} from '@/lib/loaders';
import { renderMarkdown } from '@/lib/markdown';

export async function generateStaticParams() {
  const podcastIds = await listPodcastIds();
  const params: { id: string; episodeId: string }[] = [];
  for (const pid of podcastIds) {
    const epIds = await listEpisodeIds(pid);
    for (const eid of epIds) params.push({ id: pid, episodeId: eid });
  }
  return params;
}

function formatDate(s: string): string {
  try { return new Date(s).toLocaleString('zh-CN'); } catch { return s; }
}

export default async function EpisodeDetailPage({
  params,
}: {
  params: Promise<{ id: string; episodeId: string }>;
}) {
  const { id, episodeId } = await params;
  const content = await loadEpisodeContent(id, episodeId);
  const meta = await loadPodcastMeta(id);
  if (!content || !meta) notFound();

  return (
    <div className="space-y-6">
      <Link href={`/podcasts/${id}`} className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary">
        <ArrowLeft className="h-3.5 w-3.5" />
        返回 {meta.name}
      </Link>

      <div className="space-y-4">
        <h1 className="text-2xl font-semibold leading-snug tracking-tight">{content.frontmatter.title || '无标题'}</h1>
        <p className="text-sm text-muted-foreground">{meta.name}</p>
      </div>

      {content.summary && (
        <Card className="border-primary/20 bg-primary/5">
          <CardContent className="p-5">
            <div className="mb-2 flex items-center gap-2 text-sm font-medium text-primary">
              <Sparkles className="h-4 w-4" />
              AI 摘要
            </div>
            <div className="prose prose-sm dark:prose-invert max-w-none text-foreground/90" dangerouslySetInnerHTML={{ __html: renderMarkdown(content.summary) }} />
          </CardContent>
        </Card>
      )}

      {content.tags.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 text-sm text-muted-foreground"><Tag className="h-3.5 w-3.5" />标签</div>
          <div className="flex flex-wrap gap-2">
            {content.tags.map((t) => <Badge key={t} variant="secondary">{t}</Badge>)}
          </div>
        </div>
      )}

      {content.body && (
        <div className="rounded-xl border bg-card p-5">
          <article className="prose prose-sm dark:prose-invert max-w-none" dangerouslySetInnerHTML={{ __html: renderMarkdown(content.body) }} />
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 8: 删除旧的 episodes 路由**

```bash
git rm -r frontend/src/app/episodes
```

- [ ] **Step 9: 改造 `frontend/src/app/search/page.tsx`（搜索）**

改为 server component 读 search-index + 客户端组件做交互过滤。创建服务端壳 + 客户端搜索组件。

先改 `frontend/src/app/search/page.tsx`：

```tsx
import { loadSearchIndex } from '@/lib/loaders';
import { SearchClient } from './search-client';

export default async function SearchPage() {
  let entries: Awaited<ReturnType<typeof loadSearchIndex>>['entries'] = [];
  try {
    const idx = await loadSearchIndex();
    entries = idx.entries;
  } catch {
    entries = [];
  }
  return <SearchClient entries={entries} />;
}
```

再创建 `frontend/src/app/search/search-client.tsx`（客户端关键词过滤）：

```tsx
'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { Search, FileText } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import type { SearchIndexEntry } from '@/types';

export function SearchClient({ entries }: { entries: SearchIndexEntry[] }) {
  const [q, setQ] = useState('');

  const results = useMemo(() => {
    const query = q.trim().toLowerCase();
    if (!query) return [];
    return entries.filter(
      (e) =>
        e.title.toLowerCase().includes(query) ||
        e.summary.toLowerCase().includes(query) ||
        e.podcast_name.toLowerCase().includes(query)
    );
  }, [q, entries]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">搜索</h1>
        <p className="mt-1 text-sm text-muted-foreground">在已生成摘要的剧集中搜索</p>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input className="pl-9 h-11" placeholder="输入关键词..." value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      {!q ? (
        <div className="flex flex-col items-center justify-center py-20">
          <Search className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">输入关键词开始搜索</p>
        </div>
      ) : results.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20">
          <FileText className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">未找到相关内容</p>
        </div>
      ) : (
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">找到 {results.length} 条结果</p>
          {results.map((r) => (
            <Link key={r.episode_id} href={`/podcasts/${r.podcast_id}/${r.episode_id}`}>
              <Card className="transition-colors hover:bg-accent/50">
                <CardHeader>
                  <CardTitle className="text-base line-clamp-1">{r.title || '无标题'}</CardTitle>
                  <CardDescription className="text-xs">{r.podcast_name}</CardDescription>
                </CardHeader>
                {r.summary && (
                  <CardContent>
                    <p className="text-sm text-muted-foreground line-clamp-3">{r.summary.slice(0, 200)}</p>
                  </CardContent>
                )}
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 10: 重新安装依赖**

Run: `pnpm install`
Expected: 成功，移除 react-query/zustand，新增 marked。

- [ ] **Step 11: 运行 lint + build 验证**

Run: `cd frontend && pnpm lint && pnpm build`
Expected: lint 通过，build 成功（SSG 输出静态页面）。

若 build 因 `data/` 为空报错（generateStaticParams 返回空数组属正常，应生成空状态页）。若因图片域名报错，确认 `next.config.ts` 的 `remotePatterns` 已允许 `**`（现状已配置）。

- [ ] **Step 12: Commit**

```bash
git add -A frontend/
git commit -m "feat(frontend): convert to static read-only site reading from data/"
```

---

## Task 11: CI 定时刷新 + 文档更新

**Files:**
- Create: `.github/workflows/refresh.yml`
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: 创建 `.github/workflows/refresh.yml`**

```yaml
name: Refresh Data

on:
  schedule:
    - cron: '0 8 * * 1'   # 每周一 08:00 UTC: fetch-rankings
    - cron: '0 8 * * *'   # 每日 08:00 UTC: parse-rss + scrape-episode
  workflow_dispatch:
    inputs:
      skill:
        description: '要运行的 skill (rankings | rss | scrape | all)'
        required: false
        default: 'all'

permissions:
  contents: write

jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 10

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Determine skills to run
        id: plan
        run: |
          SKILL="${{ github.event.inputs.skill || 'all' }}"
          EVENT="${{ github.event_name }}"
          # 定时事件按 cron 对应 skill
          if [ "$EVENT" = "schedule" ]; then
            CRON="${{ github.event.schedule }}"
            case "$CRON" in
              "0 8 * * 1") SKILL="rankings" ;;
              "0 8 * * *") SKILL="rss" ;;
            esac
          fi
          echo "skill=$SKILL" >> $GITHUB_OUTPUT

      - name: Run fetch-rankings
        if: steps.plan.outputs.skill == 'rankings' || steps.plan.outputs.skill == 'all'
        run: pnpm --filter @podcastinsight/skill-fetch-rankings run

      - name: Run parse-rss
        if: steps.plan.outputs.skill == 'rss' || steps.plan.outputs.skill == 'all'
        run: pnpm --filter @podcastinsight/skill-parse-rss run

      - name: Run scrape-episode
        if: steps.plan.outputs.skill == 'rss' || steps.plan.outputs.skill == 'all'
        run: pnpm --filter @podcastinsight/skill-scrape-episode run

      - name: Commit data changes
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data/
          if git diff --cached --quiet; then
            echo "无数据变更"
          else
            git commit -m "chore(data): auto-refresh by refresh.yml [skip ci]"
            git push
          fi
```

注意：summarize 不在 CI 中（需 LLM_API_KEY，由 agent 实时调用）。如需手动触发 summarize，可单独建一个 `workflow_dispatch` 的 workflow 注入 secret。

- [ ] **Step 2: 验证 workflow YAML 语法**

Run: 在 GitHub Actions 页面或本地用 `actionlint`（若有）检查。
Expected: 无语法错误。（此步主要为人工审查 YAML。）

- [ ] **Step 3: 重写 `CLAUDE.md` 为 v3 架构**

整体替换 `CLAUDE.md`：

````markdown
# PodcastInsight v3 — Skills 为核心的播客洞察平台

处理逻辑封装为 Agent Skills，数据存 git，前端是只读静态站。

## 架构

```
PodcastInsight/
├── skills/                      # 核心：Agent Skills（SKILL.md + run.ts）
│   ├── _shared/                 # 共享类型/路径/IO/校验
│   ├── fetch-rankings/          # 抓 xyzrank 排行榜（定时）
│   ├── parse-rss/               # 解析订阅 RSS（定时）
│   ├── scrape-episode/          # 抓剧集正文（定时）
│   └── summarize/               # LLM 摘要（agent 实时）
├── data/                        # skill 产出，git 跟踪
│   ├── rankings/latest.json
│   ├── podcasts/<id>/{meta.json, episodes/*.json, episodes/*.md}
│   ├── index.json               # 前端首页索引
│   └── search-index.json        # 搜索索引
├── frontend/                    # 只读静态站（SSG）
│   └── src/lib/loaders.ts       # 唯一数据读取层
└── .github/workflows/refresh.yml  # 定时数据刷新
```

## 命令

```bash
pnpm install                       # 安装（workspace）
pnpm dev                           # 前端开发服务器
pnpm build                         # 前端构建
pnpm test                          # 所有包测试

# 运行单个 skill
pnpm --filter @podcastinsight/skill-fetch-rankings run
pnpm --filter @podcastinsight/skill-parse-rss run
pnpm --filter @podcastinsight/skill-scrape-episode run
pnpm --filter @podcastinsight/skill-summarize run   # 需 LLM_API_KEY
```

## 约定

- **Skills 是核心**：处理逻辑 = SKILL.md + 确定性 run.ts 脚本，TDD
- **数据布局单一真相**：路径一律走 `skills/_shared/src/paths.ts`
- **原子写入**：经 `_shared/fs.ts`（写 .tmp 再 rename）
- **幂等**：所有 skill 重复执行安全，按 id 去重
- **前端只读**：删了 BFF/API Routes/状态管理，构建期读 data/，无运行时写入
- **无 Get笔记 / 无数据库 / 无后端服务**：数据即 git 文件
- Next.js App Router（NOT Pages Router）
- shadcn/ui 组件（NOT 自定义 UI）

## 注意事项

| 错误 | 正确 |
|------|------|
| 在前端写数据获取逻辑 | 前端只通过 loaders.ts 读 data/ |
| skill 直接拼路径 | 用 _shared/paths.ts |
| 非 .tmp 原子写 | 用 _shared/fs.ts |
| 前端用 TanStack Query | 静态数据，server component 直接 await |
````

- [ ] **Step 4: 重写 `README.md` 为 v3**

更新功能特性、技术栈、快速开始、项目结构、命令。要点：

```markdown
# PodcastInsight — Skills 为核心的播客洞察平台

播客排行榜监控 + AI 摘要，基于 Agent Skills 架构。处理逻辑封装为可复用的 skill 脚本，数据存 git，前端是只读静态站。

## 功能特性
- 播客排行榜（xyzrank Top 1000）
- RSS 解析 + 剧集正文抓取
- AI 摘要生成（agent 实时调用）
- 关键词搜索
- 响应式界面 + 深色/浅色主题

## 架构
（同 CLAUDE.md 的架构图）

## 技术栈
- Agent Skills（SKILL.md + TypeScript 脚本，tsx 运行）
- Next.js 16 (App Router, SSG) / React 19 / TypeScript 5
- TailwindCSS 4 / shadcn/ui
- fast-xml-parser / marked / vitest
- GitHub Actions（定时数据刷新）

## 快速开始
### 前置要求
- Node.js 20+ & pnpm 10

### 安装与运行
git clone ... && cd PodcastInsight
pnpm install
pnpm dev   # 前端 http://localhost:3000

### 运行 skill 生成数据
pnpm --filter @podcastinsight/skill-fetch-rankings run
# 在 data/podcasts/<id>/meta.json 中设 subscribed:true 后：
pnpm --filter @podcastinsight/skill-parse-rss run
pnpm --filter @podcastinsight/skill-scrape-episode run
# 生成摘要（需 LLM_API_KEY）：
LLM_API_KEY=xxx pnpm --filter @podcastinsight/skill-summarize run
```

（按现有 README.md 的详细程度补全项目结构、Skill 列表、API/命令表格。）

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/refresh.yml CLAUDE.md README.md
git commit -m "docs: update to v3 skills-first architecture and add refresh workflow"
```

- [ ] **Step 6: 清理临时计划文件**

```bash
rm -f docs/superpowers/plans/_task5.md docs/superpowers/plans/_task6.md docs/superpowers/plans/_task7.md docs/superpowers/plans/_task8.md docs/superpowers/plans/_task9.md
```

---

## 完成验证清单

全部任务完成后，运行以下验证：

- [ ] **所有测试通过**：`pnpm -r test`
- [ ] **前端 lint + build 通过**：`cd frontend && pnpm lint && pnpm build`
- [ ] **端到端冒烟测试**：
  1. `pnpm --filter @podcastinsight/skill-fetch-rankings run` → 检查 `data/rankings/latest.json` 生成
  2. 手动在 `data/podcasts/<某id>/meta.json` 设 `subscribed:true, rss_feed_url:"<真实rss>"`
  3. `pnpm --filter @podcastinsight/skill-parse-rss run` → 检查 episodes/*.json 生成
  4. `pnpm --filter @podcastinsight/skill-scrape-episode run` → 检查 *.md 正文生成
  5. `pnpm build` → 前端能渲染排行榜和播客详情
- [ ] **CI 检查**：推送后 `refresh.yml` 可手动 dispatch 触发

---

## 自检（Self-Review）

**1. Spec 覆盖检查：**
- §1 目录结构 → Task 0（workspace/data 目录）+ 各 skill Task（5-8）+ 前端 Task 9-10 ✓
- §2 数据模型 → Task 1（types.ts 定义全部类型）+ 各 skill 落盘 ✓
- §2.6 ID 命名约定 → Task 6（computeEpisodeId）✓
- §3.1 共用层 → Task 1-4 ✓
- §3.2 fetch-rankings → Task 5 ✓
- §3.3 parse-rss → Task 6 ✓
- §3.4 scrape-episode → Task 7 ✓
- §3.5 summarize → Task 8 ✓
- §3.6 索引维护 → Task 4 ✓
- §3.7 skill 形态约定 → 每个 skill 都有 SKILL.md + run.test.ts ✓
- §4.1 删除项 → Task 10 Step 1 ✓
- §4.2 保留项 → Task 9-10（providers/sidebar 改造保留组件）✓
- §4.3 loaders.ts → Task 9 ✓
- §4.4 页面改造 → Task 10 ✓
- §4.5 技术点（SSG/generateStaticParams/搜索降级/MD 渲染）→ Task 9-10 ✓
- §5 CI → Task 11 ✓
- §6 测试策略 → 每个 Task 都有 TDD ✓
- §7 迁移阶段 → Task 顺序对应阶段 1-7 ✓

**2. 类型一致性检查：**
- `EpisodeMeta.tags`：Task 1 定义为 `string[]`，Task 7/8 读写一致 ✓
- `scrape_status`/`summary_status`：Task 1 定义 union 类型，Task 7/8 使用一致 ✓
- `rebuildIndexes`：Task 4 定义，Task 5/6/7/8 都 import 自 `@podcastinsight/shared` ✓
- `computeEpisodeId`：Task 6 定义，前端 loaders 不需要（只用现成 id）✓
- 路由变更：剧集详情从 `/episodes/[id]` → `/podcasts/[id]/[episodeId]`，所有页面 Link 在 Task 10 中统一 ✓

**3. 占位符扫描：** 无 TODO/TBD，所有代码块完整 ✓

**4. 已知简化项（与 spec 一致的合理简化）：**
- summarize 的 LLM 调用使用 OpenAI 兼容接口（spec 未限定具体提供商，用环境变量配置 baseUrl 可对接任意兼容网关）
- scrape-episode 正文提取用正则而非完整 readability 库（spec §3.4 明确"简易 readability"，降级为正则足够）
- 搜索为纯客户端关键词过滤（spec §4.5 明确"语义搜索下线，改客户端关键词过滤"）
