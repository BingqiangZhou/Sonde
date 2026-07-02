# PodcastInsight v3 — Skills 为核心的播客洞察平台

处理逻辑封装为 Agent Skills，数据存 git，前端是只读静态站。

## 架构

```
PodcastInsight/
├── .agents/skills/              # Agent 技能发现入口（SKILL.md，agent 据此识别并触发）
│   ├── fetch-rankings/SKILL.md
│   ├── parse-rss/SKILL.md
│   ├── scrape-episode/SKILL.md
│   └── podcast-summarize/SKILL.md   # agent 原生智能技能
├── skills/                      # 技能的代码实现（pnpm workspace 包，run.ts）
│   ├── _shared/                 # 共享类型/路径/IO/校验
│   ├── fetch-rankings/          # 抓 xyzrank 排行榜
│   ├── parse-rss/               # 解析订阅 RSS
│   ├── scrape-episode/          # 抓剧集正文
│   └── summarize/               # 摘要读写工具（prepare/write/list，agent 调用）
├── data/                        # skill 产出，git 跟踪
│   ├── rankings/latest.json
│   ├── podcasts/<id>/{meta.json, episodes/*.json, episodes/*.md}
│   ├── index.json               # 前端首页索引
│   └── search-index.json        # 搜索索引
├── frontend/                    # 只读静态站（SSG）
│   └── src/lib/loaders.ts       # 唯一数据读取层
└── .github/workflows/release.yml  # 发布流程（非定时，push tag 触发）
```

## 两类技能的区分

- **确定性脚本技能**（fetch-rankings / parse-rss / scrape-episode）：纯逻辑，由 agent 或命令行手动触发。
- **agent 原生智能技能**（podcast-summarize）：摘要由 agent 自身生成（agent 就是 LLM），不需要任何外部 API 或 Key。脚本只提供 prepareEpisode（读正文）和 writeSummary（写回）两个工具函数。

## 命令

```bash
pnpm install                       # 安装（workspace）
pnpm dev                           # 前端开发服务器
pnpm build                         # 前端构建
pnpm test                          # 所有包测试

# 运行确定性 skill（也可在 agent 对话中触发）
pnpm --filter @podcastinsight/skill-fetch-rankings refresh
pnpm --filter @podcastinsight/skill-parse-rss refresh
pnpm --filter @podcastinsight/skill-scrape-episode refresh
pnpm --filter @podcastinsight/skill-summarize refresh   # 仅列出待处理剧集，不生成摘要
```

## 约定

- **Skills 是核心**：处理逻辑 = SKILL.md + 确定性 run.ts 脚本，TDD
- **技能发现**：SKILL.md 放 `.agents/skills/`（ZCode 发现目录），代码在 `skills/` pnpm 包
- **数据布局单一真相**：路径一律走 `skills/_shared/src/paths.ts`
- **原子写入**：经 `_shared/fs.ts`（写 .tmp 再 rename）
- **幂等**：所有 skill 重复执行安全，按 id 去重
- **前端只读**：删了 BFF/API Routes/状态管理，构建期读 data/，无运行时写入
- **无 Get笔记 / 无数据库 / 无后端服务 / 无 LLM API Key**：摘要由 agent 自身能力生成，数据即 git 文件
- Next.js App Router（NOT Pages Router）
- shadcn/ui 组件（NOT 自定义 UI）

## 注意事项

| 错误 | 正确 |
|------|------|
| 在前端写数据获取逻辑 | 前端只通过 loaders.ts 读 data/ |
| skill 直接拼路径 | 用 _shared/paths.ts |
| 非 .tmp 原子写 | 用 _shared/fs.ts |
| 前端用 TanStack Query | 静态数据，server component 直接 await |
