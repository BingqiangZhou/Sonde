# 声读 Sonde 全面重写决策（2026-09-29）

> 状态：已批准，实施中。本文档记录本次重写的背景、决策与目标架构。

## 背景

声读此前是 FastAPI(Python) + Flutter 的个人播客知识库：RSS 订阅 → 定时刷新 → 音频转写 → 单集 AI 摘要 → 日报快照（正则抽取一句话摘要的列表，无 AI 筛选与成刊）。

参考 [AIHOT](https://github.com/KKKKhazix/AIHOT)（一个"自己找热点、自己写日报"的开源站点框架）后，决定放弃渐进改造，**从零重写为 AIHOT 同架构的播客日报站**。

## 已确认的决策

| 决策点 | 结论 |
|---|---|
| 旧 Python 后端 / Flutter 前端 | 全部删除，不保留任何旧代码 |
| 落地方式 | **从零自写**（学习 AIHOT 架构思想，不复制其代码） |
| 技术栈 | Node 24 + TypeScript monorepo：Fastify + pg-boss + PostgreSQL 17 + React Router 7 SSR + Tailwind CSS + Docker Compose |
| 播客音频转写策略 | **全部转写**：每个新单集都下载音频→转写全文，评分基于完整转录（转写流程逻辑沿用旧项目六步流水线，移植为 TS） |
| 网页播放 | **纯阅读 + 外链**：不做播放器，单集页外链原始单集 |
| 数据库 | **从零开始**：新 schema，不做任何旧数据迁移（含旧订阅列表，手动重新添加） |
| 筛选策略 | **评分门槛制**：LLM 每集打 0-100 注意力价值分，按源 tier 门槛入选日报；落选也存分数与理由 |
| 个性化 | **可配置兴趣画像**：`industry/selection.ts` 中的 `interestProfile` 注入评分 prompt |
| 聚簇/热度/翻译/MCP/周报月报 | 第一版**不做** |
| 品牌 | 声读 Sonde（AIHOT 为 MIT 但禁止沿用其名称/logo，与其无关） |

## 目标架构（镜像 AIHOT 布局）

```
apps/
  api/       Fastify：站点读 API + admin API（session 鉴权）
  worker/    pg-boss 队列消费 + cron 调度（含转写流水线）
  web/       React Router 7 (framework mode, SSR)：中文阅读站 + /admin
packages/
  backend/   业务逻辑：db（原生 SQL）、sources、pipeline、reports、llm/transcription providers、prompts 渲染
industry/    声读定制层：site.ts / taxonomy.ts / selection.ts / sources.json / prompts/*.md
database/    纯 SQL 迁移 + seeds
scripts/     init-env.ts / migrate.ts / seed.ts
deploy/      Caddyfile
```

三进程：`api`（HTTP）、`worker`（队列+定时）、`web`（SSR，只经 HTTP 读 api，不直连 DB）。Docker Compose：db / setup(一次性) / api / worker / web (+caddy 可选)。

## 数据流水线

1. **采集** `sources.fetch`：每分钟扫描到期源（按 `interval_minutes`）→ 解析 RSS → 新单集入库 → 入队转写
2. **转写** `episodes.transcribe`：下载音频 → ffmpeg 转 16kHz 单声道 → ≤10MB 分块 → OpenAI 兼容 `/audio/transcriptions` 分块调用 → 合并为 `body_text` → 入队分析
3. **分析** `episodes.analyze`：两段式 LLM——评分（JSON {score, reason, tags}）→ 过门槛才写作（{title_zh, summary_zh, reason_zh}）
4. **成刊** `reports.daily`：每天 08:00（Asia/Shanghai）将昨日（北京日历）入选单集交主编 prompt 生成日报（title/leadParagraph/highlights + 按 taxonomy 分节），另设每小时 catch-up

## 数据表（v1）

`sources` / `episodes`（含转录正文与转写状态机）/ `analyses`（追加式判定）/ `daily_reports`（content jsonb + revisions）/ `receipts`（LLM 与转写调用的轻量成本台账）。

## 与历史文档的关系

- `LOCAL_FIRST_REDESIGN_2026-08-21.md`（已取消）、`PER_USER_CONSOLE_PLAN_2026-08-21.md`（已搁置）、`SERVER_PIPELINE_ARCH_2026-08-21.md`（已被本重写取代）仅作历史存档
- `INFRA_PGQUEUE_CADDY_2026-08-21 前后` 的 Postgres + Caddy 经验延续到新架构（pg-boss 同样跑在 Postgres 上）
