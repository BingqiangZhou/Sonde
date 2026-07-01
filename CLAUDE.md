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
