# PodcastInsight v3 — Skills 为核心架构改造

**日期**: 2026-07-01
**状态**: Implemented (2026-07-02)

## 背景

PodcastInsight v2 是一个纯 Next.js 全栈应用，核心依赖 Get笔记 OpenAPI 作为数据引擎（网页抓取 + AI 摘要 + 打标签 + 语义搜索 + 知识库），前端通过 BFF 代理层（`app/api/`）转发请求，Get笔记知识库充当数据库。

v2 架构存在以下问题：

- **强依赖外部黑盒服务**：所有数据（笔记、摘要、搜索）锁在 Get笔记，不可离线、不可版本化、不可自控。
- **前端职责过重**：既是展示层又是 BFF + 状态管理（TanStack Query + Zustand + API Key 管理），耦合度高。
- **无法纳入 agent 工作流**：处理逻辑以 API Route 形式耦合在 Next.js 中，AI agent 难以复用、编排。

## 目标

将仓库改造成 **以 Agent Skills 为核心** 的架构：

- 处理逻辑封装成独立的 Agent Skills（`SKILL.md` + 确定性脚本），可由 AI agent 编排调用。
- 数据以结构化文件形式存于 git 仓库，天然带版本历史。
- 前端退化为纯只读静态站，仅做信息展示。
- 移除 Get笔记 OpenAPI 依赖，AI 摘要改由 agent 实时生成并写回 git。

## 关键决策

| # | 决策 | 选择 | 理由 |
|---|------|------|------|
| 1 | skills 形态 | Agent Skills 模块（SKILL.md + 脚本） | 对齐 superpowers/skill-creator 模式，可被 agent 编排 |
| 2 | 执行模型 | 确定性脚本 + 定时执行 | 稳定可靠，agent 只做编排和异常处理 |
| 3 | 数据存储 | git 仓库内结构化文件 | 有版本历史，无外部依赖，契合 skills 产出 |
| 4 | Get笔记 去留 | 完全移除 | 消除黑盒依赖，数据自控 |
| 5 | AI 摘要 | agent 实时生成，写回 git | 摘要需 LLM，交给 agent；写回保证前端静态站可见 |
| 6 | 前端边界 | 只读静态站（SSG） | 仅展示，删 BFF/API Routes/状态管理 |
| 7 | 仓库形态 | 单 monorepo（skills + data + frontend 同仓库） | 数据与消费方同仓库，前端构建直接读文件，CI 简单 |
| 8 | scrape-episode 独立 | 单独成 skill | 与 parse-rss 失败模式不同，独立测试重试 |
| 9 | summarize 形态 | `run.ts --episode <id>` 脚本（内部调 LLM API） | prompt 可版本化、逻辑可测试，agent 调用此脚本 |

## 设计

### 1. 目录结构

```
PodcastInsight/
├── skills/                      # 核心：Agent Skills
│   ├── _shared/                 # 跨 skill 共用工具
│   │   ├── lib/
│   │   │   ├── http.ts          # fetch 封装（超时/重试/User-Agent）
│   │   │   ├── fs.ts            # 原子读写 JSON/MD（写临时文件再 rename）
│   │   │   ├── validate.ts      # 数据结构校验
│   │   │   ├── paths.ts         # 统一路径解析（数据布局唯一真相来源）
│   │   │   ├── types.ts         # 共享 TS 类型
│   │   │   └── index.ts         # 入口聚合
│   │   ├── tsconfig.json        # skills 子项目配置
│   │   └── package.json         # 依赖（fast-xml-parser 等）
│   ├── fetch-rankings/
│   │   ├── SKILL.md
│   │   ├── run.ts
│   │   └── run.test.ts
│   ├── parse-rss/
│   │   ├── SKILL.md
│   │   ├── run.ts
│   │   └── run.test.ts
│   ├── scrape-episode/
│   │   ├── SKILL.md
│   │   ├── run.ts
│   │   └── run.test.ts
│   └── summarize/
│       ├── SKILL.md
│       ├── run.ts               # 接受 --episode <id>，内部调 LLM API
│       └── run.test.ts
│
├── data/                        # skill 产出，git 跟踪
│   ├── rankings/
│   │   └── latest.json
│   ├── podcasts/
│   │   └── <xyzrank-id>/
│   │       ├── meta.json
│   │       └── episodes/
│   │           ├── <episode-id>.json
│   │           └── <episode-id>.md
│   ├── search-index.json        # 关键词搜索索引（构建期消费）
│   └── index.json               # 前端首页导航索引
│
├── frontend/                    # 只读静态站
│   └── src/
│       ├── app/                 # App Router 页面，构建期读 data/ 渲染
│       ├── components/          # shadcn/ui + layout（保留）
│       └── lib/
│           └── loaders.ts       # 唯一数据读取层（fs 读 data/）
│
├── .github/workflows/
│   ├── refresh.yml              # 定时跑 fetch/parse/scrape skills
│   └── release.yml              # 构建部署前端（已有，保留）
├── pnpm-workspace.yaml          # workspace 配置（frontend + skills）
└── CLAUDE.md
```

### 2. 数据模型

#### 2.1 `data/rankings/latest.json` — 排行榜快照

```json
{
  "fetched_at": "2026-07-01T08:00:00Z",
  "source": "xyzrank.com",
  "podcasts": [
    {
      "id": "string",
      "name": "string",
      "rank": 1,
      "category": "string",
      "logo_url": "string",
      "rss_feed_url": "string",
      "author": "string"
    }
  ]
}
```

#### 2.2 `data/podcasts/<id>/meta.json` — 单个播客

```json
{
  "id": "string",
  "name": "string",
  "author": "string",
  "category": "string",
  "logo_url": "string",
  "rss_feed_url": "string",
  "xyzrank_rank": 12,
  "subscribed": true,
  "subscribed_at": "2026-07-01"
}
```

#### 2.3 `data/podcasts/<id>/episodes/<eid>.json` — 剧集元数据（脚本写）

```json
{
  "id": "string",
  "title": "string",
  "audio_url": "string",
  "duration": 3600,
  "published_at": "2026-06-28T00:00:00Z",
  "link": "string",
  "scraped_content_path": "episodes/<eid>.md",
  "scrape_status": "pending | done | failed",
  "summary_status": "pending | done | skipped",
  "tags": ["科技", "AI"]
}
```

#### 2.4 `data/podcasts/<id>/episodes/<eid>.md` — 正文 + 摘要（脚本写正文，agent 写摘要）

```markdown
---
episode_id: "string"
title: "string"
summary_status: "pending | done"
generated_at: "2026-07-01T00:00:00Z"
model: "claude-..."
---

## AI 摘要

<agent 生成的摘要>

## 标签

#科技 #AI

## 正文

<抓取的网页/转录正文>
```

#### 2.5 `data/index.json` — 前端首页索引

```json
{
  "updated_at": "2026-07-01T08:00:00Z",
  "subscribed_podcasts": [
    { "id": "...", "name": "...", "logo_url": "...", "category": "...", "episode_count": 42 }
  ],
  "recent_summarized_episodes": [
    { "episode_id": "...", "podcast_id": "...", "podcast_name": "...", "title": "...", "summary_status": "done", "published_at": "..." }
  ],
  "rankings_updated_at": "2026-07-01T08:00:00Z"
}
```

#### 2.6 ID 命名约定（幂等基础）

- **播客 id**：xyzrank 提供的 id
- **剧集 id**：优先 RSS `<guid>`；若缺失，用 `audio_url` 的 SHA-1 hash 前 12 位
- 重复执行时按 id 判断存在性，已存在则跳过

### 3. Skills 设计

#### 3.1 共用层 `skills/_shared/`

| 模块 | 职责 |
|------|------|
| `http.ts` | fetch 封装：超时、重试、User-Agent |
| `fs.ts` | 原子读写：写 `.tmp` 再 rename；读写 JSON/MD |
| `validate.ts` | 产出数据校验，符合 §2 模型才落盘 |
| `paths.ts` | 统一路径解析，前端和 skill 共用（数据布局唯一真相来源） |
| `types.ts` | 共享 TS 类型（Meta、Episode、Ranking 等） |

#### 3.2 `fetch-rankings`

- **触发**：GitHub Actions 每周定时（周一 08:00 UTC）+ agent 手动
- **输入**：无
- **输出**：覆写 `data/rankings/latest.json`，更新 `data/index.json` 的 `rankings_updated_at`
- **流程**：GET xyzrank API → 校验规范化 → 原子写 latest.json → 更新 index.json
- **幂等**：整体覆写
- **失败处理**：抓取失败保留上一次快照，不删除旧数据

#### 3.3 `parse-rss`

- **触发**：GitHub Actions 每日定时 + agent 手动
- **输入**：所有 `meta.json` 中 `subscribed: true` 的播客
- **输出**：为新剧集写 `episodes/<eid>.json`（`summary_status: pending`），更新 index.json 剧集计数
- **流程**：
  1. 扫描 `data/podcasts/*` 中 subscribed 的目录
  2. 对每个：fetch RSS → fast-xml-parser 解析 → 提取剧集
  3. 对每集：按 §2.6 计算 id
  4. 已存在 → 跳过；否则写 `<eid>.json`（summary_status=pending）
  5. 更新 index.json
- **幂等**：按 episode id 判断，只写增量

#### 3.4 `scrape-episode`

- **触发**：parse-rss 之后链式执行（同一 workflow job）+ agent 手动
- **输入**：所有 `scrape_status: pending` 的剧集
- **输出**：写 `episodes/<eid>.md` 的 frontmatter + `## 正文` 部分
- **流程**：
  1. 扫描所有 `scrape_status: pending` 剧集
  2. fetch episode.link 网页 → readability 提取正文
  3. 写 `<eid>.md`（frontmatter summary_status 仍 pending）
  4. 更新 `<eid>.json` 的 `scrape_status: done`
- **幂等**：.md 正文已存在则跳过
- **降级**：抓取失败时 `scrape_status: failed`，summary 阶段跳过该集

#### 3.5 `summarize`

- **触发**：agent 对话中实时调用（不在定时 CI 中）
- **输入**：`--episode <episode-id>` 指定单集，或无参数处理所有 pending
- **输出**：在 `<eid>.md` 补写 `## AI 摘要` + `## 标签`，更新 `<eid>.json` 的 `summary_status: done` 和 `tags`，更新 index.json
- **流程**：读取素材 → 调 LLM API 生成摘要和标签 → 原子写回 .md/.json → 更新 index.json
- **幂等**：已 done 的剧集不重复处理；失败留 pending 可重试
- **环境变量**：`LLM_API_KEY`（本地 / 手动 workflow），不进仓库

#### 3.6 索引维护（index.json 与 search-index.json）

`data/index.json` 和 `data/search-index.json` 是前端入口，必须随数据变化保持最新。维护策略：

- 各产出 skill（fetch-rankings、parse-rss、scrape-episode、summarize）在写完自己的数据后，调用 `_shared` 提供的统一 `rebuildIndexes()` 函数重建这两个文件。
- `rebuildIndexes()` 扫描整个 `data/` 目录聚合生成，保证索引与实际数据一致（幂等）。
- CI 定时链路中，各 skill 顺序执行，每个都重建一次索引，最后一次即为最新。

#### 3.7 Skill 形态约定（写进 CLAUDE.md）

| 约定 | 说明 |
|------|------|
| 入口脚本 | `run.ts`，CI 用 `tsx` 直接执行 |
| 幂等 | 重复执行不产生重复数据、不覆盖已有摘要 |
| 原子写入 | 经 `_shared/fs.ts`，先写 `.tmp` 再 rename |
| 数据校验 | 产出经 `_shared/validate.ts` 校验后才落盘 |
| 路径单一来源 | 一律走 `_shared/paths.ts` |
| 测试 | 每个 skill 有 `run.test.ts`，mock HTTP/FS |
| SKILL.md | 即使有脚本也要有，说明 agent 何时如何介入 |

### 4. 前端改造

#### 4.1 删除项

| 删除 | 原因 |
|------|------|
| `app/api/` 整个 BFF 代理层 | 无后端服务 |
| `lib/getnote-api.ts`、`lib/xyzrank-api.ts`、`lib/rss-parser.ts` | 逻辑迁移到 skills |
| `lib/queries.ts`（TanStack Query） | 静态数据无需服务端状态管理 |
| `stores/settings-store.ts` | 无 API Key、无认证 |
| `app/settings/page.tsx` | 无配置项 |
| `@tanstack/react-query`、`zustand` 依赖 | 不再需要 |
| `types/index.ts` 中 Get笔记 相关类型 | 依赖移除 |

#### 4.2 保留项

| 保留 | 原因 |
|------|------|
| `components/ui/`（shadcn） | 基础组件库 |
| `components/layout/`（sidebar、theme-provider） | 布局框架 |
| `components/providers.tsx`（移除 QueryClient） | 主题等 provider |
| App Router 页面结构 | 仅改数据来源 |

#### 4.3 新增 `lib/loaders.ts`

唯一的数据读取层，server component 在构建期调用：

```typescript
// 概要
import { promises as fs } from 'fs';
import path from 'path';
const DATA_DIR = path.resolve(process.cwd(), '..', 'data');

export async function loadIndex() { /* 读 data/index.json */ }
export async function loadRankings() { /* 读 data/rankings/latest.json */ }
export async function loadPodcastMeta(id: string) { /* 读 meta.json */ }
export async function loadEpisodes(podcastId: string) { /* 扫描 episodes/*.json */ }
export async function loadEpisode(podcastId: string, episodeId: string) { /* 读 .json + .md */ }
export async function loadSearchIndex() { /* 读 search-index.json */ }
```

#### 4.4 页面改造

| 页面 | 数据来源 | 关键变更 |
|------|----------|----------|
| `page.tsx` 仪表盘 | `loadIndex()` | 已订阅播客 + 最近摘要剧集，async server component |
| `podcasts/page.tsx` 排行榜 | `loadRankings()` | 移除 useQuery，改 async 加载 |
| `podcasts/[id]/page.tsx` 详情 | `loadPodcastMeta()` + `loadEpisodes()` | `generateStaticParams` 枚举 data/podcasts/* |
| `episodes/[id]/page.tsx` 笔记详情 | `loadEpisode()` | 渲染 .md 摘要 + 正文（markdown 渲染） |
| `search/page.tsx` 搜索 | `loadSearchIndex()` | 语义搜索下线，改客户端关键词过滤 |

#### 4.5 关键技术点

- **构建期读取**：`loaders.ts` 用 `fs` 在 SSG 阶段读 `data/`，数据烤进静态 HTML。
- **`generateStaticParams`**：遍历 `data/podcasts/*/` 和 episodes，枚举所有静态路由。
- **搜索降级**：由 skill 生成 `data/search-index.json`（标题+摘要扁平文本），前端客户端过滤。原 Get笔记 语义召回下线。
- **markdown 渲染**：episode .md 需渲染为 HTML（可引入轻量库如 `marked` 或 `react-markdown`）。

### 5. CI 与定时执行

#### 5.1 新增 `refresh.yml`

```yaml
# 概要结构
name: Refresh Data
on:
  schedule:
    - cron: '0 8 * * 1'    # 每周一 08:00 UTC: fetch-rankings
    - cron: '0 8 * * *'    # 每日 08:00 UTC: parse-rss → scrape-episode
  workflow_dispatch:        # 支持手动触发
```

每次执行步骤：
1. checkout
2. pnpm install（workspace，含 skills）
3. 运行对应 skill 脚本（`tsx skills/<name>/run.ts`）
4. 若 `data/` 有变更 → git commit + push（GITHUB_TOKEN）
5. push 触发 release.yml → 构建部署前端

**summarize 不进定时 CI**：仅本地或手动 workflow 触发，生成后手动提交。

#### 5.2 环境变量

- 定时 CI（fetch/parse/scrape）：无需密钥
- summarize：需要 `LLM_API_KEY`（仅本地或手动触发时配置）

### 6. 测试策略

| 层级 | 内容 | 工具 |
|------|------|------|
| `_shared/` | fs 原子写、validate、paths | vitest |
| 各 skill | run.test.ts，mock HTTP/FS，验证核心逻辑（增量幂等） | vitest |
| 前端 | loaders.ts 解析 fixture data/ | vitest |
| 集成 | 端到端跑一次 fetch→parse→scrape，验证 data/ 产出 | 手动 / CI |

### 7. 迁移策略（分阶段）

| 阶段 | 内容 | 验证标准 |
|------|------|----------|
| 1 | 搭 `skills/_shared/`（types/fs/paths/validate/http）+ pnpm workspace 配置 | 单测通过 |
| 2 | 写 `fetch-rankings`（移植 xyzrank-api.ts）→ 首次产出 rankings | JSON 落盘正确 |
| 3 | 写 `parse-rss`（移植 rss-parser.ts）→ 产出 episodes/*.json | 增量幂等验证 |
| 4 | 写 `scrape-episode` → 产出 *.md 正文 | 失败降级验证 |
| 5 | 写 `summarize`（LLM 摘要脚本）→ 补摘要 | 手动触发验证 |
| 6 | 改造前端：写 loaders.ts，逐页改读 data/，删旧 api/lib/stores | 构建通过、页面渲染 |
| 7 | 配 refresh.yml 定时 + 更新 CLAUDE.md/README | CI 跑通 |

## 范围之外（YAGNI）

以下不在本次改造范围：

- **音频转录**：v1 有 Whisper 转录，v3 不恢复。scrape-episode 只抓网页正文，不处理音频。
- **语义搜索**：原 Get笔记 语义召回下线，仅保留关键词搜索。未来可引入本地 embedding。
- **用户系统/认证**：个人项目，无需。
- **数据库**：git 文件即数据库，不引入 SQLite 等持久层。
- **数据量治理**：暂不限制 data/ 体积，数据量真正成问题时再迁移。

## 风险与对策

| 风险 | 影响 | 对策 |
|------|------|------|
| data/ 仓库膨胀 | clone/CI 变慢 | 短期可接受；长期可按播客归档或迁移到数据仓库 |
| 网页正文抓取被反爬 | scrape-episode 失败 | 降级为 scrape_status: failed，summary 跳过；可加 User-Agent 轮换 |
| LLM API 成本/可用性 | summarize 不可用 | ~~原方案~~；已改为 agent 原生生成（见下方修正），不依赖外部 API |
| 现有 Get笔记 数据无法迁移 | 历史笔记丢失 | 本次按全新数据流重建，不迁移 v2 数据 |

## 实现后修正（2026-07-02）

实现过程中发现两处偏离本 spec 的设计回归，已在合并前修正：

### 修正一：技能发现目录

| 原计划 | 问题 | 修正 |
|--------|------|------|
| skill 放 `skills/` 目录即被 agent 发现 | ZCode 的技能发现目录是 `.agents/skills/`，`skills/` 只是 pnpm 包目录，agent 识别不到 | 在 `.agents/skills/` 创建 4 个 SKILL.md 作为发现入口；代码逻辑保留在 `skills/` pnpm 包不动 |

两类技能的区分：
- **确定性脚本技能**（fetch-rankings / parse-rss / scrape-episode）：SKILL.md 指导 agent 跑 `pnpm --filter ... refresh`
- **agent 原生智能技能**（podcast-summarize）：SKILL.md 指导 agent 读正文 → 自己生成摘要 → 调 writeSummary 写回

### 修正二：summarize 从"脚本调 API"改为"agent 原生"

| 原计划（决策 #5、#9） | 问题 | 修正 |
|----------------------|------|------|
| summarize 是脚本，内部调 OpenAI 兼容 API 生成摘要 | agent 本身就是 LLM，脚本里再调外部 API 是多此一举，还引入 API Key 依赖 | 删除 `llm-client.ts`；summarize 包改为提供 prepareEpisode（读正文）/ writeSummary（写回）/ listPending（列出）三个纯工具函数；摘要由 agent 自身能力生成，无需任何外部 API |

这更符合设计意图："summarize 由 agent 实时生成"——agent 自己读、自己写，脚本只保证格式契约（原子写、frontmatter、索引重建）。
