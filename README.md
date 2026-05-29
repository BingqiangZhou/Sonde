# PodcastInsight — 播客洞察平台

PodcastInsight 是一个基于 Get笔记 OpenAPI 的播客洞察平台，集成播客排行榜监控、AI 笔记摘要、语义搜索等功能，帮助你从播客内容中高效提取和管理知识。

## 功能特性

- **播客排行榜** — 从 xyzrank.com 获取 Top 1000 中文播客排行榜，支持订阅追踪
- **Get笔记集成** — 通过 Get笔记 OpenAPI 自动完成网页抓取、AI 摘要生成、智能打标签
- **知识库管理** — 为每个订阅播客创建独立知识库，结构化管理剧集笔记
- **语义搜索** — 基于 Get笔记 的语义召回能力，全局或知识库范围搜索播客内容
- **RSS Feed 解析** — 自动解析播客 RSS feed，发现新剧集并保存到 Get笔记 处理
- **API Key 管理** — 前端可视化配置 Get笔记 API Key，支持 localStorage 和环境变量两种存储方式
- **响应式界面** — 移动端优先的中文界面，支持深色/浅色主题切换

## 技术栈

- **Next.js 16** / React 19 / TypeScript 5 (App Router)
- **TailwindCSS 4** / shadcn/ui (组件库)
- **TanStack Query v5** (服务端状态管理)
- **Zustand** (客户端状态管理)
- **Get笔记 OpenAPI** (核心数据引擎，替代传统后端和数据库)
- **Sonner** (消息通知)

## 快速开始

### 前置要求

- Node.js 20+ & pnpm
- Get笔记账号及 API Key (从 Get笔记开放平台获取)

### 1. 克隆项目

```bash
git clone git@github.com:BingqiangZhou/PodcastInsight.git
cd PodcastInsight
```

### 2. 配置环境变量

```bash
cp frontend/.env.example frontend/.env.local
```

编辑 `frontend/.env.local`，填入 Get笔记凭证：

```env
# Get笔记 API 配置
GETNOTE_API_KEY=your_api_key_here
GETNOTE_CLIENT_ID=your_client_id_here
```

### 3. 启动开发服务器

```bash
cd frontend

# 安装依赖
pnpm install

# 启动开发服务器 (端口 3000)
pnpm dev
```

访问 http://localhost:3000 即可使用。

也可以在应用内的 **设置** 页面配置 API Key。

## 项目结构

```
podcast-insight/
├── frontend/                     # Next.js 全栈应用
│   ├── src/
│   │   ├── app/                  # App Router 页面 + API Routes
│   │   │   ├── api/              # BFF 代理层
│   │   │   │   ├── getnote/      # Get笔记 API 代理
│   │   │   │   └── podcasts/     # xyzrank + RSS 代理
│   │   │   ├── podcasts/         # 播客排行榜 + 详情
│   │   │   ├── episodes/         # 笔记详情
│   │   │   ├── search/           # 语义搜索
│   │   │   └── settings/         # API Key 配置
│   │   ├── components/           # shadcn/ui 组件
│   │   ├── lib/                  # API 客户端、TanStack Query hooks、工具函数
│   │   ├── stores/               # Zustand 状态管理
│   │   └── types/                # TypeScript 类型
│   ├── package.json
│   └── .env.example
├── docs/                         # 设计文档和规范
├── .env.example
└── CLAUDE.md                     # 开发规范文档
```

## API 概览

### Get笔记代理 (BFF)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/getnote/notes` | 笔记列表 |
| POST | `/api/getnote/notes` | 保存笔记 |
| GET | `/api/getnote/notes/[id]` | 笔记详情 |
| POST | `/api/getnote/task` | 任务进度查询 |
| GET | `/api/getnote/knowledge` | 知识库列表 |
| POST | `/api/getnote/knowledge` | 创建知识库 |
| GET | `/api/getnote/knowledge/[id]` | 知识库笔记 |
| POST | `/api/getnote/recall` | 语义搜索 |

### 播客数据

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/podcasts/rankings` | xyzrank 排行榜 |
| POST | `/api/podcasts/feed` | RSS feed 解析 |

## 开发指南

```bash
cd frontend
pnpm lint                # ESLint 检查
pnpm test                # Vitest 测试
pnpm build               # 生产构建
```

### 约定

- 前端使用 **App Router** (`app/` 目录)，不是 Pages Router
- UI 组件使用 **shadcn/ui**，不自行编写基础组件
- 数据查询使用 **TanStack Query** (`useQuery` / `useMutation`)，不直接 fetch
- 无后端服务，所有数据操作通过 **BFF 代理层** 转发到 Get笔记 API
- Git 提交遵循 **Conventional Commits** (`feat:`, `fix:`, `refactor:`)

## License

MIT
