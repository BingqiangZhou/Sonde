# 00 · 转向决策（2026-10-28）

> 状态：已确认。本文档记录 v2 转向的决策依据与分支布局，变更需在此追加记录。

## 1. 三次形态史

| 时期 | 形态 | 说明 |
|---|---|---|
| v0.x（~2026-04） | Python FastAPI + Flutter 多端 App | 多用户邮箱注册/JWT、订阅、播放器、转写、AI 摘要；末期"后端简化"砍成单用户 API Key |
| v1.x（2026-09-29） | Node/TS 单仓（Fastify + pg-boss + React Router SSR） | AIHOT 式日报站：全文转写 → LLM 评分门槛筛选 → 日/周/月三刊 + 成本台账（文档见 ts-era 分支 `docs/SONDE_TS_REWRITE_2026-09-29.md`） |
| **v2（本次）** | **回归 v0 形态 + 吸收 v1 流水线** | Python 后端 + Flutter 客户端 + 多用户；把 v1 的评分筛选、三刊、成本台账移植进 Python |

## 2. 决策表

| # | 决策点 | 结论 |
|---|---|---|
| 1 | 后端 | 以 **v0 基线**（FastAPI + SQLAlchemy async + Celery/Redis + Postgres 15 + nginx）继续开发，不重写、不回退到 TS |
| 2 | 客户端 | **Flutter 核心版**（v0 frontend 基线）：登录、订阅管理+发现、单集浏览（摘要/评分/转录）、三刊阅读、后台播放+续播、收藏同步 |
| 3 | 用户体系 | **多用户**：邮箱注册 + JWT（access 30min / refresh 7d，user_sessions 设备管理）；`REGISTRATION_OPEN` 默认**关闭**，管理员建号 |
| 4 | 订阅模型 | 沿用 v0 现状：`subscriptions` 全局 feed 去重 + `user_subscriptions` per-user 设置；转写/评分全局只跑一次 |
| 5 | 评分与报告 | **全局唯一**（不分用户）：评分门槛制 + 日(08:00)/周(周一 08:30)/月(1 日 08:30) 三刊，Asia/Shanghai 时区 |
| 6 | 发现（iTunes） | 从 Flutter 直连 Apple 改为**走后端代理**：多国合并搜索 + `ITUNES_DNS`/`ITUNES_PROXY_URL` 出站定制（移植自 ts-era `itunes.ts`） |
| 7 | 管理后台 | 沿用 v0 **Jinja2 面板**（/api/v1/admin）并扩展（成本/报告/诊断/发现）；**不迁** ts-era React /admin |
| 8 | 队列 | **保持 Celery + Redis**（procrastinate 迁移不在本次范围，避免镀金） |
| 9 | 首版暂缓 | 播放队列管理、收听历史/统计、离线下载、睡眠定时、AI 对话、高亮提取（代码都在 v0，后续按需开放） |
| 10 | 版本 | 转向完成发布 **v2.0.0** |

## 3. 分支布局与推送待办

| 分支/标签 | 指向 | 用途 |
|---|---|---|
| `main` | v0 基线（724455ce）+ v2 转向开发 | 唯一开发主线 |
| `ts-era` | TS 版完整存档（含原工作区未提交的 iTunes 工作，已提交为 feat） | v1.x 历史与参考实现（web 阅读站、prompts、流水线逻辑从此迁出） |
| `v0` 分支 + `v1.x`/`v0.x` 标签 | 各时代快照 | 保底参照，不动 |

**推送状态**：✅ 已完成（2026-10-28）——`ts-era` 已推送存档，`main` 已强推至 v0 基线并持续同步。

## 4. 风险总表

| 风险 | 影响 | 对策 | 责任阶段 |
|---|---|---|---|
| 认证域考古漂移（历史代码与现库结构不一致） | Phase B 返工 | 以 `backend/docs/AUTHENTICATION.md` 契约为验收基线，逐文件比对适配 | B |
| Celery/时区坑（旧日报 19:30 UTC≈03:30 沪的教训） | 三刊时间错 | cron 显式指定 Asia/Shanghai 并写窗口计算测试 | C |
| 多用户带来转写成本上升 | 账单失控 | feed 全局去重（既有）+ `ai_receipts` 台账 + `MAX_PODCAST_SUBSCRIPTIONS` 上限 | B/C |
| web 独立化（解 workspace）破坏构建 | Phase A/D 返工 | A 阶段单独提交并验证 `npm run build` | A |
| 网络阻断（GitHub 不可达） | 远程不同步 | 本地先行；恢复后按 §3 顺序推送 | 持续 |
| v0 过期文档误导开发 | 无 | Phase A 清理（见 01 §4） | A |
