# 声读 Sonde 全面重写决策（2026-09-29）

> 状态：**已实施完成**（同日完成 v1 全链路）。本文档记录本次重写的背景、决策与目标架构。

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

Python/Flutter 时代的全部设计文档（LOCAL_FIRST / PER_USER_CONSOLE / SERVER_PIPELINE / INFRA_PGQUEUE_CADDY / BACKEND_ARCH_ANALYSIS / FEATURES / DEPLOYMENT / EMULATOR_TEST_REPORT / MIRRORS / ANDROID_SIGNING / GITHUB_ACTIONS_GUIDE / RELEASE_QUICK_REF）已在本次清理中删除——它们描述的旧栈不复存在，需要时可从 git 历史查阅（`git log -- docs/`）。Postgres + Caddy 的部署经验延续到新架构（pg-boss 同样跑在 Postgres 上）。

## 实施记录（v1 完成态）

| 阶段 | 内容 | 验证方式 |
|---|---|---|
| 清理 | 删除 backend/ frontend/ docker/ .github，重写 README/AGENTS/.gitignore | 重写链首个提交（git log 可查） |
| 脚手架 | npm workspaces 三进程、0001_init.sql、Dockerfile(ffmpeg)、compose 五容器 | Docker 端到端健康检查 |
| 核心包 | chatJson（重试/校验/记账）、transcribeChunk、prompt 渲染器、时区/JSON 工具 | 51 个单测 |
| 采集+转写 | 条件 GET 抓取、首导 14 天/10 条截断、六步转写（下载/ffmpeg 16k/分块/逐块转写/合并/派发） | Docker 真实 feed 实测 |
| 分析+日报 | 评分（zod 容错）→ tier 门槛 → 写作；08:00 站点时区成刊 + taxonomy 分节 | mock LLM/ASR 全链路实测 |
| 阅读站 | 首页/日报/单集/归档 + 站点读 API | Docker 实测页面渲染 |
| admin | 登录会话、源管理、单集诊断、日报触发、成本页（web 自定义服务器反代 /api） | Docker 实测 |

开发用 mock（无 key 跑全链路）：`scripts/dev/mock-llm.mjs`，见 README「本地开发」。
