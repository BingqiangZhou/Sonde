# PodcastInsight v2 — Get笔记驱动的播客洞察平台

播客排名监控 + Get笔记 AI 摘要/笔记 + 语义搜索 Web 平台。
纯 Next.js 架构，Get笔记 OpenAPI 作为核心数据引擎。

## Tech Stack
- **Frontend**: Next.js 16 (App Router) / React 19 / TypeScript / TailwindCSS 4 / shadcn-ui
- **State**: TanStack Query v5 (服务端状态) + Zustand (客户端状态)
- **数据引擎**: Get笔记 OpenAPI（笔记 CRUD、知识库、语义搜索）
- **播客排行**: xyzrank.com API
- **无后端服务**: 纯 Next.js BFF 代理层，无独立后端

## Key Directories
- `frontend/`: Next.js 全栈应用（App Router + API Routes）
- `frontend/src/app/api/`: BFF 代理层（getnote/、podcasts/）
- `frontend/src/components/`: shadcn/ui 组件
- `frontend/src/lib/`: API 客户端、TanStack Query hooks、工具函数
- `frontend/src/stores/`: Zustand 状态管理
- `frontend/src/types/`: TypeScript 类型
- `docs/`: 设计文档和规范

## Development Commands
See `CLAUDE.md` for detailed commands and project rules.
