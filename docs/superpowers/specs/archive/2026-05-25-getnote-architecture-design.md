# PodcastInsight v2 — Get笔记驱动的轻量架构设计

## 背景

PodcastInsight v1 使用 FastAPI + PostgreSQL + Redis + Celery 重后端架构，自管理 Whisper 转录和 AI 摘要。v2 将核心能力交由 Get笔记 OpenAPI 处理，整个项目简化为一个纯 Next.js 应用。

## 决策记录

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 内容输入方式 | 传入播客网页链接 | Get笔记 link 类型自动抓取 + AI 摘要 |
| 播客数据源 | xyzrank 排行榜 + 手动 RSS | 两种都需要 |
| 聊天功能 | 不做 AI 聊天，用语义搜索替代 | 纯新版 API，避免两套 Base URL |
| 部署方式 | Next.js 自托管 | 复用现有前端，迁移成本最低 |
| 数据持久化 | Get笔记知识库 + localStorage | 无数据库，知识库即数据库 |
| 项目策略 | 原地重构现有仓库 | 保留历史记录 |

## 架构

```
PodcastInsight v2 — 纯 Next.js 架构
====================================

frontend/ (Next.js App Router)
├── src/
│   ├── app/
│   │   ├── page.tsx                    # Dashboard
│   │   ├── layout.tsx                  # 根布局
│   │   ├── podcasts/
│   │   │   ├── page.tsx                # 排行榜 + 订阅
│   │   │   └── [id]/page.tsx           # 播客详情 + 剧集
│   │   ├── episodes/
│   │   │   └── [noteId]/page.tsx       # 笔记详情
│   │   ├── search/
│   │   │   └── page.tsx                # 语义搜索
│   │   ├── settings/
│   │   │   └── page.tsx                # API Key 配置
│   │   └── api/
│   │       ├── getnote/
│   │       │   ├── notes/route.ts      # 笔记列表/保存
│   │       │   ├── notes/[id]/route.ts # 笔记详情
│   │       │   ├── knowledge/route.ts  # 知识库列表/创建
│   │       │   ├── knowledge/[id]/route.ts # 知识库笔记
│   │       │   ├── recall/route.ts     # 语义搜索
│   │       │   └── task/route.ts       # 任务进度
│   │       └── podcasts/
│   │           ├── rankings/route.ts   # xyzrank 代理
│   │           └── feed/route.ts       # RSS 解析
│   ├── lib/
│   │   ├── getnote-api.ts             # Get笔记 API 客户端
│   │   ├── xyzrank-api.ts             # xyzrank API 客户端
│   │   ├── rss-parser.ts              # RSS 解析
│   │   └── subscription-store.ts      # localStorage 订阅映射
│   ├── components/                     # shadcn/ui 组件
│   ├── hooks/                          # TanStack Query hooks
│   └── types/                          # TypeScript 类型
└── .env.local                          # API Key 存储
```

单一 API：`https://openapi.biji.com`，认证头 `Authorization` + `X-Client-ID`。

## 数据流

### 播客发现与订阅

1. 调用 xyzrank API 获取排行榜 → 展示
2. 用户点击"订阅" → `POST /knowledge/create` 在 Get笔记创建知识库
3. 返回 `topic_id` → 存入 localStorage 映射 `{xyzrankId: {topicId, podcastName, rssUrl}}`（用 xyzrankId 作 key 避免名称重复）

### 剧集内容抓取

1. 解析 RSS feed 获取 episode 列表（title, link, pubDate）
2. 用户选择"处理" → `POST /note/save` 传入 `{note_type: "link", link_url, topic_id}`
3. 返回 `task_id` → 前端轮询 `POST /task/progress`
4. Get笔记异步完成：抓取网页 → AI 生成摘要 → 自动打标签

### 内容展示

`GET /note/detail` 返回：
- `title` — 标题
- `content` — Markdown 正文
- `web_page.excerpt` — AI 摘要
- `web_page.content` — 原文
- `tags[]` — 标签

### 语义搜索

`POST /resource/recall` 全局搜索，`POST /resource/recall/knowledge` 知识库范围搜索。参数：`query`（必填）、`top_k`（默认 3，最大 10）。

## 页面设计

### Dashboard (`/`)
- 搜索栏 → 全局语义搜索
- 已订阅播客列表 → localStorage 映射 + `/knowledge/list`
- 最近笔记 → `/note/list`

### 播客排行榜 (`/podcasts`)
- xyzrank 排行榜表格（分页、分类筛选）
- 排名、名称、logo、分类、订阅按钮

### 播客详情 (`/podcasts/[id]`)
- 播客信息 + RSS 剧集列表
- "处理"按钮 → 保存链接到知识库
- 知识库笔记列表

### 笔记详情 (`/episodes/[noteId]`)
- AI 摘要卡片
- Markdown 正文
- 原文折叠区
- 标签

### 语义搜索 (`/search?q=xxx`)
- 搜索结果列表
- 可限定知识库范围

### 设置 (`/settings`)
- API Key + Client ID 配置
- 连接测试（调 `/note/list`）
- 配额用量展示
- 清除订阅数据
- "从 Get笔记 同步"按钮（重建 localStorage 映射）

## 错误处理

### 认证
- 未配置 API Key → 引导提示，跳转设置页
- API Key 无效（10001）→ 清除配置 + 提示重新输入
- 非会员（10201）→ 提示需要 Get笔记会员

### 限流
- 429 响应 → "请求过于频繁，稍后再试" + 显示剩余配额
- TanStack Query retry 设 1 次

### 异步任务轮询
- 首次 5s，递增（5s → 10s → 20s），最多 10 次
- pending/processing → loading 动画
- success → 刷新列表
- failed → 错误提示
- 超时 → "处理中，稍后刷新查看"

### 数据一致性
- localStorage 订阅映射可跨设备丢失
- "从 Get笔记 同步"按钮调 `/knowledge/list` 重建映射

### 缓存策略
- 排行榜 staleTime: 1 小时
- 笔记列表 staleTime: 5 分钟
- TanStack Query 默认 staleTime: 5 分钟

## 迁移计划

### 删除
- `backend/` 目录（FastAPI + Celery + DB models + migrations）
- `docker/` 目录（docker-compose + nginx）
- `.env.example` 中 DB/Redis/Celery 配置
- `cliff.toml`

### 保留
- `frontend/src/components/` — shadcn/ui 组件
- `frontend/src/app/globals.css` — 样式
- `frontend/src/app/layout.tsx` — 布局（调整导航）
- `frontend/package.json`（移除不需要的依赖）

### 改造
- `page.tsx` — 重写 Dashboard
- `podcasts/` — 重写排行榜 + 详情
- `episodes/` — 重写笔记详情
- `settings/` — 重写为 API Key 配置
- `lib/` — 替换 API 客户端
- `types/` — 替换为 Get笔记 API 类型
- `hooks/` — 新 TanStack Query hooks

### 新增
- `app/api/` — Route Handlers 代理层
- `app/search/` — 语义搜索页
- `lib/getnote-api.ts` — Get笔记 API 客户端
- `lib/xyzrank-api.ts` — xyzrank API 客户端
- `lib/rss-parser.ts` — RSS 解析
- `lib/subscription-store.ts` — localStorage 管理
- `.env.local` — `GETNOTE_API_KEY` + `GETNOTE_CLIENT_ID`

### 更新
- `CLAUDE.md` — 完全重写
- `.gitignore` — 移除 Python 相关
- `.github/` — 移除 backend CI 步骤

## 技术栈

- Next.js 15 (App Router)
- React 19
- TypeScript 5
- TailwindCSS 4
- shadcn/ui
- TanStack Query v5
- Zustand（客户端状态）
- Lucide icons
- Sonner（toast）

唯一外部依赖：Get笔记 OpenAPI（需会员账号 + API Key）。
