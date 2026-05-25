# PodcastInsight v2 — Get笔记驱动的播客洞察平台

播客排名监控 + Get笔记 AI 摘要/笔记 + 语义搜索 Web 平台。
纯 Next.js 架构，Get笔记 OpenAPI 作为核心数据引擎。

## 架构

```
podcast-insight/
├── frontend/              # Next.js 全栈应用
│   ├── src/
│   │   ├── app/           # App Router 页面 + API Routes
│   │   │   ├── api/       # BFF 代理层
│   │   │   │   ├── getnote/   # Get笔记 API 代理
│   │   │   │   └── podcasts/  # xyzrank + RSS 代理
│   │   │   ├── podcasts/  # 播客排行榜 + 详情
│   │   │   ├── episodes/  # 笔记详情
│   │   │   ├── search/    # 语义搜索
│   │   │   └── settings/  # API Key 配置
│   │   ├── components/    # shadcn/ui 组件
│   │   ├── hooks/         # React hooks
│   │   ├── lib/           # API 客户端、工具函数
│   │   ├── stores/        # Zustand 状态管理
│   │   └── types/         # TypeScript 类型
│   └── package.json
├── docs/                  # 设计文档和规范
├── .env.example
└── CLAUDE.md
```

## 命令

```bash
cd frontend
pnpm install                  # 安装依赖
pnpm dev                      # 开发服务器 (端口 3000)
pnpm build                    # 生产构建
pnpm lint                     # ESLint
pnpm test                     # Vitest 测试
```

## 技术栈

- Next.js 16 (App Router)
- React 19
- TypeScript 5
- TailwindCSS 4
- shadcn/ui (组件库)
- TanStack Query v5 (服务端状态)
- Zustand (客户端状态)
- Lucide icons
- Sonner (toast)

## 核心能力

### 1. Get笔记 OpenAPI 集成
- 笔记 CRUD：保存文本/链接，自动抓取网页内容 + AI 摘要
- 知识库：创建和管理知识库，作为播客订阅的容器
- 语义搜索：全局和知识库范围的语义召回
- 异步任务：链接保存后轮询处理进度

### 2. 播客排行 (xyzrank.com)
- 从 xyzrank.com API 获取 Top 1000 播客排行
- 展示排名、logo、分类、作者、RSS feed
- 用户可订阅播客（创建对应知识库）

### 3. RSS Feed 解析
- 解析播客 RSS feed 获取剧集列表
- 将剧集链接保存到 Get笔记 知识库处理
- Get笔记 自动完成：网页抓取 → AI 生成摘要 → 打标签

### 4. API Key 管理
- 前端设置页输入 Get笔记 API Key + Client ID
- 凭证存储在 Zustand (localStorage) 和/或 .env.local
- 通过 BFF 代理层注入认证头

## API 路由 (BFF 代理层)

```
# Get笔记 代理
GET    /api/getnote/notes          # 笔记列表
POST   /api/getnote/notes          # 保存笔记
GET    /api/getnote/notes/[id]     # 笔记详情
POST   /api/getnote/task           # 任务进度
GET    /api/getnote/knowledge      # 知识库列表
POST   /api/getnote/knowledge      # 创建知识库
GET    /api/getnote/knowledge/[id] # 知识库笔记
POST   /api/getnote/recall         # 语义搜索

# 播客数据
GET    /api/podcasts/rankings      # xyzrank 排行榜
POST   /api/podcasts/feed          # RSS feed 解析
```

## 约定

- Next.js App Router (NOT Pages Router)
- shadcn/ui 组件 (NOT 自定义 UI)
- TanStack Query 管理所有服务端状态
- Route Handlers 做代理，注入 API Key
- 响应式：移动端优先，桌面端侧边栏布局
- 支持暗色/亮色模式

## 注意事项

| 错误 | 正确 |
|------|------|
| Next.js Pages Router | App Router (app/ 目录) |
| 自定义 CSS 组件 | shadcn/ui 组件 |
| 不用 TanStack Query 直接 fetch | 使用 useQuery/useMutation |
| 后端服务 | 纯 Next.js，无后端 |
| pip / uv | 无 Python 依赖 |
| 数据库 | Get笔记知识库即数据库 |
