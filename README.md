# 声读 Sonde

个人播客更新时间线：自动订阅播客 RSS，把每一集新更新汇成一条持续刷新的时间线。零运行成本——不转写音频、不调用任何 LLM/API,纯抓取与展示。

## 工作方式

1. **订阅**：worker 启动时与每日 04:00（北京时间）自动同步 xyzrank.com 中文播客榜前 1000 名
2. **采集**：worker 每分钟扫描到期源（按每个源的间隔），条件 GET 抓取 RSS，新单集入库
3. **展示**：单页时间线按发布时间倒序展示——封面、播客名、发布时间、时长、原始标题（外链）与 RSS 自带简介

订阅跟随榜单自动增减：进榜自动订阅，掉榜停止抓取（历史单集保留在时间线上）。

## 架构

```
apps/api       Fastify：站点读 API（/api/site/meta、/api/site/episodes、/api/site/sources、/api/site/categories）
apps/worker    pg-boss：sources.fetch 队列 + 每分钟到期扫描 cron
apps/web       React Router 8 SSR：单页时间线（中文、报刊风、深浅双主题）
packages/backend  业务逻辑（原生 SQL、RSS 采集、时间线读取、订阅同步）
industry/      定制层：站点文案（site.ts）
database/      纯 SQL 迁移
```

技术栈：Node 24 · TypeScript · Fastify · pg-boss · PostgreSQL 17 · React Router 8 · Tailwind CSS · Docker Compose

## 快速开始

```bash
# 1. 生成 .env（随机 Postgres 密码）
node scripts/init-env.ts

# 2. 启动（db → migrate → api/worker/web；worker 启动即同步 xyzrank 榜单）
docker compose up -d --build

# 3. 访问 http://localhost:3000
```

时间线内容随 worker 抓取自动填充，无需手工操作。

本地开发：Node 24 + Docker 跑 Postgres，`npm install` 后用 `npm run dev:api` / `dev:worker` / `dev:web`（详见 AGENTS.md）。

## 定制

- 站点名/文案：`industry/site.ts`
- 一级分类词表：`GENRE_ROLLUP`（`packages/backend/src/sources/xyzrank.ts`，改字典后下次同步对当期在榜源生效；掉榜停用源保留旧分类）

## License

MIT
