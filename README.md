# 声读 Sonde

个人播客知识库：自动订阅播客 RSS → 转写音频 → AI 评分筛选 → 每天 08:00 出日报、每周一出周报、每月 1 日出月报。

学习 [AIHOT](https://github.com/KKKKhazix/AIHOT) 的"自己找热点、自己写日报"框架思想，针对播客场景从零实现的同架构项目。

## 工作方式

1. **采集**：worker 按每个源的间隔定时抓取 RSS，发现新单集入队
2. **转写**：下载音频 → ffmpeg 转码 → 分块调用 OpenAI 兼容转写接口 → 合并全文
3. **筛选**：LLM 为每集打 0-100 注意力价值分（结合可配置的兴趣画像），过门槛（按源分级 T1/T2）才进入下一步
4. **写作**：入选单集生成中文标题、答案先行的摘要与一句话推荐理由
5. **成刊**：
   - **日报**：每天 08:00（北京时间）将昨日入选单集编成日报——刊头标题、导语、今日看点、分节条目
   - **周报**：每周一 08:30 回顾上一周（周一至周日）的入选单集，提炼趋势与主线
   - **月报**：每月 1 日 08:30 盘点上个月的入选单集

## 站点功能

- 阅读站（中文）：首页 / 日报 / 周报 / 月报 / 全部动态（含未入选）/ 单集详情
- **收藏**：单集可星标收藏，只保存在本浏览器（localStorage），不上传
- **主题**：浅色 / 深色 / 跟随系统，报刊风双主题
- **更新日志**：`/changelog` 与仓库 CHANGELOG.md（中文版）同步
- 后台控制台 `/admin`：订阅源管理、单集诊断、报刊触发、成本台账

## 架构

```
apps/api       Fastify：站点读 API + admin API
apps/worker    pg-boss 队列 + cron：采集/转写/分析/成刊
apps/web       React Router 8 SSR：中文阅读站 + /admin
packages/backend  业务逻辑（原生 SQL、流水线、LLM/转写 provider）
industry/      声读定制层：站点文案、分类、门槛、兴趣画像、prompt
database/      纯 SQL 迁移
```

技术栈：Node 24 · TypeScript · Fastify · pg-boss · PostgreSQL 17 · React Router 8 · Tailwind CSS · Docker Compose

## 快速开始

```bash
# 1. 初始化环境变量（生成随机密钥）
node scripts/init-env.ts --llm-key <你的OpenAI兼容Key>

# 2. 启动（db → migrate/seed → api/worker/web）
docker compose up -d --build

# 3. 访问
#   站点  http://localhost:3000
#   后台  http://localhost:3000/admin（密码见 .env 的 ADMIN_PASSWORD）
```

本地开发：Node 24 + Docker 跑 Postgres，`npm install` 后用 `npm run dev:api` / `dev:worker` / `dev:web`（详见 AGENTS.md）。

### 无 API key 的本地联调

`scripts/dev/mock-llm.mjs` 提供模拟的 LLM 与转写端点，可跑通全链路（数据为固定假文案）：

```bash
docker network create sonde_default 2>/dev/null; docker run -d --name sonde-mock-llm --network sonde_default \
  -v "$PWD/scripts:/scripts:ro" node:24-trixie-slim node /scripts/dev/mock-llm.mjs
# .env 中把 LLM_BASE_URL / TRANSCRIPTION_BASE_URL 指向 http://sonde-mock-llm:9999/v1
```

正式使用前请把 `.env` 换成真实的 OpenAI 兼容端点与 key。

## 定制

- 订阅源：admin 后台管理，或编辑 `industry/sources.json`（首次启动 seed）
- 评分门槛与兴趣画像：`industry/selection.ts`
- 日报分节分类：`industry/taxonomy.ts`
- 全部 prompt：`industry/prompts/*.md`（改标准不用改代码）

## License

MIT
