# 基础设施切换：Postgres 任务队列（procrastinate）+ Caddy 反向代理

- 日期：2026-09-29
- 状态：已实施（本次提交）
- 前置背景：`SERVER_PIPELINE_ARCH_2026-08-21.md`（其"compose 不变（6 容器）"的部署表述自本文起失效）

## 1. 决策

| 维度 | 之前 | 现在 |
|------|------|------|
| 任务队列 | Celery 5（Redis broker + result backend，独立 worker + beat 容器） | **procrastinate 3.9**（Postgres 原生，单 worker 容器内置周期调度） |
| 缓存/锁 | Redis 7 | Postgres advisory lock + 进程内 TTL 缓存 |
| 反向代理 | nginx（手动证书 + envsubst 模板） | **Caddy 2**（默认 `tls internal` 本地 CA，零配置零续期） |
| compose 容器 | 6（postgres/redis/backend/worker/beat/nginx） | **4**（postgres/backend/worker/caddy） |

## 2. 为什么是 procrastinate 而不是 pg-boss

原始需求是"队列使用 pg-boss，不再使用 redis"。调研结论：

- **pg-boss 是 Node.js 专属库**（npm 包），没有官方 Python 客户端，PyPI 上也无维护良好的第三方移植。
- 本项目全部任务逻辑（ffmpeg 转写、AI 摘要、RSS 抓取、日报）都在 Python/FastAPI 侧；严格用 pg-boss 需要引入常驻 Node 服务做桥接（Python 经 SQL 函数入队 → Node worker 收任务 → 再拉起 Python 执行器），双运行时、跨语言错误处理、镜像与运维复杂度都显著上升。
- **procrastinate 是 Python 生态的"pg-boss 等价物"**：纯 Python、Postgres 13+ 原生队列，能力与需求逐项对齐——原生 async、`@app.periodic` cron 周期调度（取代 beat）、`RetryStrategy` 重试、`queueing_lock` 排队去重、LISTEN/NOTIFY 即时唤醒。经确认后选定。

## 3. 关键语义映射（Celery/Redis → procrastinate/Postgres）

| 旧机制 | 新机制 |
|--------|--------|
| Celery `max_retries=3` + `countdown=60*2**n` | `ExponentialBackoffRetry(max_attempts=4)`（`app/core/jobs.py`，退避曲线 60/120/240/480s 一致） |
| beat 周期表（4 条，UTC） | `@procrastinate_app.periodic(cron=...)`，时刻不变；**worker 容器 pin `TZ=UTC`**（procrastinate 的 cron 按进程本地时区求值） |
| Redis 转写 episode 锁（TTL 3600） | `pg_try_advisory_lock` 挂在专用连接上，显式释放、进程死亡自动释放（`transcription/state.py`；跨进程查询 owner 不可得时返回 `UNKNOWN_OWNER_TASK_ID`） |
| Redis 派发去重 claim（SET NX EX 2h） | 排队期：入队 `queueing_lock=f"transcription:dispatch:{task_id}"`（重复入队吞掉 `AlreadyEnqueued`）；执行期：`claim_task_dispatch` 按任务状态判定（终态→跳过，in_progress→报重复），并发互斥由 episode advisory lock 兜底 |
| Redis 摘要锁（TTL 1800） | `advisory_lock("podcast:summary:{episode_id}")`（`summary_service.py`） |
| Redis 启动锁（TTL 300） | `advisory_lock("startup:reset-stale-transcription-tasks")`，仅覆盖 reset 操作本身 |
| Redis feed 计数缓存（TTL 120s） | 进程内 TTL 字典（`feed_repository.py`，单副本部署） |
| `task_acks_late` / 崩溃恢复 | procrastinate 作业状态持久在 `procrastinate_jobs` 表；worker 崩溃后由既有 stale-task reset 标记失败，配合重试语义 |

行为差异（已确认接受）：
- 派发去重不再有"2 小时后自动可重派"的时间窗，改由任务状态与 stale reset 决定——语义更准。
- 失去 Celery 硬性 time limit（30min）；长任务卡死由 stale reset（5 分钟无更新判定）覆盖。
- 日报/清理时刻保持 **UTC**（19:30 UTC = 北京 03:30），与切换前完全一致。

## 4. 部署与运维

- **schema 安装**：backend 容器 entrypoint 在 `alembic upgrade head` 后执行 `python -m procrastinate -a app.core.jobs.procrastinate_app schema --apply`（幂等，`procrastinate_version` 表追踪版本）；worker 等 backend healthy 后启动。
- **worker**：`python -m app.bootstrap.worker`，并发 `WORKER_CONCURRENCY`（默认 1，对齐旧 celery `--concurrency=1`）；healthcheck `python -m app.bootstrap.worker --healthcheck`（探 Postgres + `procrastinate_jobs` 表存在）。
- **驱动**：procrastinate 走 psycopg 自管连接池，与 SQLAlchemy/asyncpg 主链路互不影响。
- **Caddy**：`docker/caddy/Caddyfile`，默认 `tls internal`；ACME/手动证书切换、根证书导入见 `docker/caddy/README.md`。原 nginx 的 stream 不缓冲、`/static/` 缓存、auth 限流 location 均已无对应后端路由（playback/static/JWT 已在前序提交移除），不再移植；WebSocket 与流式透传是 Caddy 默认行为。

## 5. 涉及文件

- 新增：`backend/app/core/jobs.py`、`backend/app/core/advisory_lock.py`、`backend/app/bootstrap/worker.py`、`docker/caddy/{Caddyfile,README.md}`
- 重写：`backend/app/domains/podcast/transcription/state.py`（advisory lock + 状态 claim）
- 删除：`backend/app/core/celery_app.py`、`backend/app/core/redis.py`、`docker/nginx/` 整目录
- 修改：12 个任务模块（原生 async + procrastinate 注册）、`task_orchestration.py`（async enqueue + queueing_lock）、`transcription_service.py`、`summary_service.py`、`feed_repository.py`、`repositories/base.py`、`lifecycle.py`、`http.py`（readiness 去 redis）、`config.py`（REDIS_*/CELERY_* → WORKER_CONCURRENCY）、`docker-compose.yml`、`docker-entrypoint.sh`、各 env 模板
- 依赖：`celery`/`redis` 移除；`procrastinate>=3.0`、`psycopg[binary]>=3.2` 加入
