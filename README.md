# PodcastInsight — Skills 为核心的播客洞察平台

播客排行榜监控 + AI 摘要，基于 Agent Skills 架构。处理逻辑封装为可复用的 skill 脚本，数据存 git，前端是只读静态站。

## 功能特性

- **播客排行榜** — 从 xyzrank.com 获取 Top 1000 中文播客排行榜
- **RSS 解析** — 自动解析订阅播客的 RSS，发现新剧集
- **剧集正文抓取** — 抓取剧集网页正文
- **AI 摘要生成** — agent 自身能力生成摘要和标签（无需额外 API Key）
- **关键词搜索** — 在已生成摘要的剧集中搜索
- **响应式界面** — 移动端优先，支持深色/浅色主题

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
├── frontend/                    # 只读静态站（SSG）
└── .github/workflows/           # 定时数据刷新 + 发布
```

## 技术栈

- **Agent Skills**（SKILL.md + TypeScript 脚本，tsx 运行）
- Next.js 16 (App Router, SSG) / React 19 / TypeScript 5
- TailwindCSS 4 / shadcn/ui
- fast-xml-parser / marked / vitest
- GitHub Actions（定时数据刷新）

## 快速开始

### 前置要求

- Node.js 20+ & pnpm 10

### 安装与运行

```bash
git clone https://github.com/BingqiangZhou/PodcastInsight.git
cd PodcastInsight
pnpm install
pnpm dev          # 前端 http://localhost:3000
```

### 生成数据

```bash
# 抓取排行榜
pnpm --filter @podcastinsight/skill-fetch-rankings refresh

# 订阅播客：在 data/podcasts/<id>/meta.json 中设 subscribed: true 并填 rss_feed_url

# 解析 RSS 发现新剧集
pnpm --filter @podcastinsight/skill-parse-rss refresh

# 抓取剧集正文
pnpm --filter @podcastinsight/skill-scrape-episode refresh

# 生成 AI 摘要（在 agent 对话中说"生成摘要"，agent 自身能力生成，无需 API Key）
# 或先查看待处理列表：
pnpm --filter @podcastinsight/skill-summarize refresh
```

## Skills

| Skill | 说明 | 触发 |
|-------|------|------|
| fetch-rankings | 抓 xyzrank Top 排行榜 | GitHub Actions 每周一 + agent/手动 |
| parse-rss | 解析订阅播客 RSS，发现新剧集 | GitHub Actions 每日 + agent/手动 |
| scrape-episode | 抓剧集网页正文 | parse-rss 之后 + agent/手动 |
| podcast-summarize | agent 自身生成摘要和标签 | agent 对话触发（无需 API Key） |

## 开发

```bash
pnpm test          # 所有包测试
pnpm lint          # ESLint
pnpm build         # 前端构建
```

## License

MIT
