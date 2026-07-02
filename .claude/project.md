# PodcastInsight v3 — Skills 为核心的播客洞察平台

处理逻辑封装为 Agent Skills，数据存 git，前端是只读静态站。

## Tech Stack
- **Skills**: Agent Skills（SKILL.md + TypeScript 脚本，tsx 运行）
- **Frontend**: Next.js 16 (App Router, SSG) / React 19 / TypeScript 5 / TailwindCSS 4 / shadcn-ui
- **Shared**: skills/_shared（类型、路径、原子 IO、校验）
- **数据**: 结构化 JSON/MD 文件存于 git（无数据库、无 Get笔记、无后端服务）
- **包管理**: pnpm workspace（NEVER npm/yarn）

## Key Directories
- `.agents/skills/`: Agent 技能发现入口（SKILL.md，ZCode 据此识别并触发）
- `skills/`: 技能代码实现（pnpm workspace 包，run.ts）
  - `_shared/`: 共享类型/路径/IO/校验
  - `fetch-rankings/`, `parse-rss/`, `scrape-episode/`: 确定性脚本技能（agent/命令行手动触发）
  - `summarize/`: 摘要读写工具（prepareEpisode/writeSummary/listPending，agent 调用）
- `data/`: skill 产出，git 跟踪（rankings/、podcasts/、index.json、search-index.json）
- `frontend/`: 只读静态站（SSG），唯一数据读取层 `src/lib/loaders.ts`
- `docs/`: 设计文档和规范

## Development Commands
See `CLAUDE.md` for detailed commands and project rules.
