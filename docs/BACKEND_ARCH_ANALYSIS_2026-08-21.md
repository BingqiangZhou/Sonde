# Sonde 后端架构深度分析报告（2026-08-21）

> 第二轮架构深扫。第一轮治理（9 个 commit，`c354b880…09e4fc28`）已落地死代码清扫、假别名移除、坏依赖边打断、content_service 拆分。本轮聚焦验证遗留项现状并挖掘新问题。
> 所有 P0 级指控均经人工读码逐行验证；证据以 `file:line` 标注（相对 `backend/`）。
> 验证基线：`uv run pytest` 461 passed / 1 skipped，`uv run ruff check .` 全过——**全绿掩盖了下述全部 P0**。

## 总评

分层骨架（routes → service → repository、DDD 目录、Celery 编排）清晰，可靠性设计（双 Redis 锁、派发声明、启动 stale 重置、优雅降级）有想法。但存在两类核心问题：

1. **一组 P0 级运行时断裂正躺在主干上**——源于一次未迁移完调用点的 Redis 重构；
2. **测试体系验证的是 mock 而非行为**——这是 P0 至今未暴露的根因。

结构层面，podcast 域是"激进文件合并"的产物：2351 行 god repo、四套 AI HTTP 客户端、只写不读的 Redis 镜像层、无事务边界。

---

## 一、P0：主干上的运行时断裂（先止血）

### 1.1 RedisCache 收编后 7 处生产代码调用已删除的方法

`app/core/redis.py` 仅剩原语方法（get/set/delete/lock/zset，`redis.py:167-278`）；领域方法已删，调用点未迁移，全库无兼容 shim：

| 调用点 | 后果 | 保护 |
|---|---|---|
| `episode_service.py:98/131` | 按订阅过滤的剧集列表接口 500 | 无 |
| `episode_service.py:414` | 剧集详情接口 500（`get_episode_with_summary` 最终 return 直调 `redis.get_episode_detail`） | 无 |
| `podcast_repository.py:173`（经 :416/:497） | feed 刷新发现新单集即崩——核心入库链路断裂 | 无 |
| `podcast_repository.py:659` | AI 摘要 DB 提交成功后 AttributeError，任务被误判失败 | 无 |
| `podcast_repository.py:1856` | 播放进度先 commit 成功再 500（数据落库但客户端看到失败） | 无 |
| `playback_service.py:107/108/129/152/155` | 降级直查库，功能侥幸正常 | try/except |
| `transcription/state.py:624` | `CacheTTL.hours(2)`——`CacheTTL` 无 `hours`（`redis.py:29-36`），`claim_task_dispatch` 必崩 | 无 |

**修复**：这些缓存本就是 §2.3 的"只写镜像"，直接删调用（不重新实现）；`CacheTTL.hours(2)` → `7200`；每处配走真实 service 层的回归测试。

### 1.2 stats 并发查询共享同一 AsyncSession

`stats_service.py:50-55` 用 `asyncio.gather` 并发跑三个协程，但 `repo` 与 `playback_service` 共享同一 session（:37-38）。SQLAlchemy AsyncSession 禁止并发操作，负载下必抛错；`return_exceptions=True` 又把异常吞掉——**统计接口静默返回空数据**而非报错。另 `stats_service.py:47` 的 "Cache MISS" 日志无条件打印，实际无缓存逻辑。

**修复**：三个查询串行化（均为轻查询），或每协程独立 session。

### 1.3 admin 登录的条件性崩溃

`admin/auth.py:19-22` 经 `get_settings()`（绕过 `config.py:216-226` 对 SECRET_KEY 特判的懒代理）读原始字段 `SECRET_KEY`——默认 None，仅当进程内发生过 JWT 签发（`domains/auth/security.py:74`）或 Fernet 加密后才有值。场景：`SECRET_KEY` env 未设（.env.example 中为注释态）+ 先用 Web 管理面板登录 → `NoneType.encode()` → 500。顺序依赖的隐形炸弹。

**修复**：改用 `settings.get_secret_key()`；lifespan 启动时预热一次，消除顺序依赖。

### 为什么 461 个测试全绿

路由测试将 service 整个 `AsyncMock`（`podcast/tests/conftest.py:19-31`）；转写核心链路（downloader/converter/splitter/transcriber）零直接单测；`_refresh_single_subscription` 真实快乐路径零覆盖。测试验证的是"转发关系"而非"行为"。

---

## 二、结构性问题（架构层）

### 2.1 podcast 域：god repo + 转写三层嵌套

**God repo（`podcast_repository.py`，2351 行，约 60 方法 / 9 聚合）**：订阅、单集、Feed 分页、播放状态、摘要、搜索、统计、倍速偏好、队列全塞在一个具体类（无接口）。且早已不是数据访问层：

- 队列领域逻辑内嵌：位置步长 1024、压缩阈值、"current 必须在队首"不变量、删除继任者策略（:1920-2002）；
- 状态机迁移（:644-669）+ 直读系统设置（:207-216）+ 散布 Redis 写入；
- **每个写方法自行 commit**（:273、:413、:493、:657 等），服务层无事务边界——`add_subscription` 非原子（订阅先落库、单集后落库；`episode_service.py:641` 注释声称单事务，实际不是）；
- 机械合并残留：5 处孤立 docstring、4 个空 `TYPE_CHECKING` 块、4 次重复 logger（:39-74）。

**转写双服务**：`services/transcription_service.py`（1396 行门面）与 `transcription/service.py`（1473 行引擎）继承+组合三层嵌套（RuntimeService 继承引擎、再被 WorkflowService 组合）；跨对象替换私有方法的猴子补丁（services/transcription_service.py:140-165）；引擎反向懒 import 服务层（transcription/service.py:1362-1366）构成靠函数内 import 掩盖的环；失败标记 metadata key 三处不一致（`failed_at` / `summary_failed_at` / summary_service 自一套）。

**修复**：
1. 按聚合拆 repo：`SubscriptionRepository` / `EpisodeRepository` / `FeedQueryRepository`（读模型）/ `PlaybackStateRepository` / `QueueRepository` / `SummaryRepository` / `SearchRepository` / `StatsRepository`；
2. 引入 Unit of Work：repo 只 `flush`，commit 收敛到服务层显式事务边界；`add_subscription` 原子性随之解决；
3. `routes/dependencies.py:40-115` 的 7 个假名 provider（全部返回同一 PodcastRepository）随拆分改真绑定，清掉模块级 `_cached_repos`（:37）；
4. 转写：WorkflowService 改纯组合（去继承）；猴子补丁改构造注入 progress-updater 回调；失败 metadata key 收敛为常量。

### 2.2 AI：一个功能四套 HTTP 客户端

1. `core/ai_client.py`（643 行）半迁移孤儿：生产仅 `summary_service.py:115` 一处调用；`AIClientService` 类零生产调用，纯死代码；
2. `domains/ai/model_testing.py`：每次调用新建 aiohttp session（:61/:163/:231）；
3. `transcription/transcriber.py`：第四套独立实现，重试参数硬编码（:95-96）不读 settings；
4. 密钥解析 4 份且语义矛盾：文本生成路径永不查 env（text_generation_service.py:131-136），转写路径 env 优先于 DB（transcription/service.py:523-529）。chat URL 拼接 3 份、响应解析 3 份。

**修复**：
1. 删 `AIClientService` 及其测试；`call_ai_api*` / `_build_chat_url` / 重试判定迁入 `domains/ai/invocation.py`（生产断点仅 1 处 import + 3 个测试文件）；
2. 密钥解析统一走 `key_resolver`，消灭 transcription/service.py:519-548 内联实现；明确 env/DB 优先级；
3. transcriber 重试改读 `settings.AI_CLIENT_*`；model_testing 复用 `core/http_client` 共享 session；
4. 迁移完成后 `model_config_service.py:335/367` 懒导入改回顶层（循环依赖自然消失）。

### 2.3 Redis：只写不读的镜像层

真实读写仅两处：锁（摘要/转写/启动）+ feed 计数缓存（TTL 120s，无主动失效，订阅增删后最长 2 分钟脏读，`podcast_repository.py:813/830`）。以下均为无读者的写入：转写进度/状态镜像（state.py:443/:511）、episode→task 映射（:393）、活跃任务 zset（`sorted_set_range_by_score` 定义后零调用）、stats 失效调用（删的键从无写入方，`stats_service.py:86/92`）。状态查询路由实际全走 DB。

**修复**：做减法——保留"锁 + feed 计数"，其余镜像代码全删。未来若需进度推送，用 SSE/WebSocket 直推而非 Redis 镜像 + 轮询。

### 2.4 认证三套并存 + core 职责混杂

`core/auth.py`（require_api_key 双模式 + 寄生 DB/Redis provider）、`domains/auth/security.py`（JWT）、`admin/auth.py`（HMAC cookie）并存可接受（单用户部署的历史演进），但：

- JWT 解码逻辑两份（core/auth.py:47-57 vs domains/auth/routes.py:43-58）；
- admin 从 core import 私有函数 `_extract_api_key`（admin/auth.py:10）；
- `core/ai_client.py:112-155` 在 core 层直接 raise `HTTPException`（会泄漏到 Celery 上下文）。

**修复**：JWT 解码收敛到 `domains/auth/security.py` 单点；`_extract_api_key` 转公开函数；core 的 AI 错误改抛领域异常（随 §2.2 迁移一起做）。

### 2.5 分层泄漏与卫生清单

- `core/database.py:115-121` `register_orm_models` 硬编码 import 4 个 domain 模型——core 反向依赖 domains；
- `routes_transcriptions.py:101-198` 路由内手拼 40+ 字段 dict，且绕过门面直掏 `workflow.transcription_service_factory(workflow.db)`；`response_assemblers.py` 建好但最大端点恰好不用；`routes_subscriptions.py:40-93` 同类问题；
- `models.py`（862 行）ORM 挂富领域逻辑，含硬编码 Asia/Shanghai（:466）；`schemas.py`（866 行）60 类单文件；
- `task_orchestration.py`（858 行）混杂 ORM 查询、aiohttp 构造（伪装 Chrome UA :199-204）、Celery 入队；为测试兼容保留私有转发（:849-858）；
- 错误响应实际形状 `{detail, type, status_code}`（exceptions.py:134-141），与 AGENTS.md 宣称的双语 `{message_en, message_zh}` 不符——仅 DB 503/超时 504 两个 handler 双语（:248-249/:274-275）；文档或代码必有一个要改；
- N+1：`list_pending_transcriptions` 逐集 lookup（services/transcription_service.py:511-515）、日报逐集触发（daily_report_service.py:181-182）；搜索在 ORM 实例挂未定义属性 `relevance_score`（podcast_repository.py:1411）；
- 异步路径同步阻塞 I/O：`model_testing.py:48/62`、`transcription/service.py:1149-1163`（shutil.move）、splitter/downloader 多处 `os.remove`；仓库已有正确范本（`asyncio.to_thread`，storage_cleanup.py:111）；
- `logging_config.py:187` `get_log_files` 按 `app-*.log` glob，实际文件名 `app.log`；
- service↔service 直接 import 兜底自建（stats_service.py:17/:38）；`episode_service.py:416-424` 跨聚合直查 TranscriptionTask；`schedule_service` 纯 SQLAlchemy 直查不走 repo（:42-148），与全域约定不一致。

---

## 三、可靠性 / 安全 / 运维

### 3.1 Celery 可靠性（4 个洞）

设计上双 Redis 锁 + 派发声明（state.py:610-634）+ 启动 stale 重置是认真的，但：

1. 未配 `acks_late`——worker 被 kill -9 时消息已 ack、任务丢失；且 stale 重置挂在 **FastAPI lifespan**（lifecycle.py:119-145）而非 worker 启动，API 不重启就没人复位；
2. 维护类任务 `max_retries` 是死代码（except 里直接 raise，tasks_maintenance.py:51-65）；
3. beat 内嵌唯一 worker（`-B --concurrency=1`，docker-compose.yml:188），横向扩容即多 beat 重复触发；
4. backend 与 celery_worker 共用 entrypoint **并发跑 alembic 迁移**（docker-entrypoint.sh:46-49），靠版本表锁兜底属竞态赌博。

**修复**：`acks_late=True + task_reject_on_worker_lost=True`（转写任务幂等，重跑安全）；stale 重置移到 `worker_process_init`；beat 拆独立服务；迁移只在 backend 跑或加 `pg_advisory_lock`。

### 3.2 安全（按风险排序）

- AI Key **明文导出**（apikeys_service.py:317-360）；
- admin 会话无 CSRF token 仅靠 samesite=lax，而管理端全是状态变更操作；
- slowapi 限速器进程内存态（重启/多副本失效）；`/auth/refresh` 无限速（auth/routes.py:96）；
- JWT 无吊销、logout 纯客户端（auth/routes.py:105-108）；
- `API_KEY` 为空=全放行的 dev bypass（core/auth.py:75-77、admin/auth.py:33-34）在生产校验里仅告警不阻断（config.py:180-190）；
- admin 路由把异常原文回显客户端（apikeys.py:90/268/290）；
- `backend/.gitignore` 未列 `.env`（当前侥幸未被跟踪）。

**修复**：导出改密码加密或仅导掩码；admin 写操作加 `X-Requested-With` 校验（最低成本 CSRF 防御）；refresh 加限速 + redis jti 黑名单（一个 set 即够）；生产模式缺 API_KEY 从 warning 升级为拒绝启动。

### 3.3 可观测性与备份

- 无结构化日志 / request-id / metrics / tracing，仅慢请求中间件（阈值 5s）；
- 日志双份轮转（TimedRotating + docker json-file）；
- **无任何备份机制**——`postgres_data` 卷与存 `.secret_key` 的 `backend_data` 卷丢一个，所有 Fernet 加密的 AI Key 全废（encryption.py:79-85 自认）。

**修复**：加每日 `pg_dump` 到 `./backups` 的 beat 任务（挂到现有 maintenance 编排）；request-id 中间件（十几行）；secret_key 首次生成时提示备份到卷外。

### 3.4 测试策略的结构性缺陷（P0 根因）

- sqlite 内存库覆盖不了 PG 专有行为（`with_for_update skip_locked`、pg_trgm）；27 个 alembic 迁移零测试；
- mock 一切的路由测试测不出真实行为；
- 转录端到端快乐路径（下载→转码→切块→调用→存库）无测试；AI 域仅 2 个测试。

**修复**：新增"真实集成测试"层——`docker compose up postgres redis` 后以真 DB + 真 RedisCache 跑关键路径（feed 刷新入库、转写派发、播放进度、摘要保存），HTTP 层继续 TestClient 但**只 mock 外部 AI/下载、不 mock 内部 service**；以 `uv run pytest -m integration` 本地跑，作为发布前手工门禁。

---

## 四、改善路线图

| 阶段 | 内容 | 工作量 | 验收 |
|---|---|---|---|
| **P0 止血** | §1.1 删 7 处死缓存调用 + `CacheTTL.hours→7200`；§1.2 stats 串行化；§1.3 `get_secret_key()`；每项配真实路径回归测试 | 1 天 | 新回归测试全绿 + Docker 起服后手动过列表/详情/进度/feed 刷新 |
| **P1 结构收敛** | god repo 按聚合拆 8 个 + UoW 事务边界 + 假名 dependencies 清理；错误响应双语对齐文档 | 1-2 周 | pytest 全绿（机械移动，行为不变）；事务原子性有测试 |
| **P2 统一** | AI 四栈收敛（删 AIClientService → invocation.py → key_resolver 单点）；转写去继承/去猴子补丁/metadata key 统一；Redis 只留锁+feed 计数 | 2-3 周 | 摘要与转写链路各有一条真集成测试 |
| **P3 加固**（可并行） | acks_late + stale 重置移 worker + beat 拆分 + 迁移互斥；备份任务；安全清单；request-id；集成测试层 | 持续 | kill -9 worker 后任务自动重跑；`./backups` 出现每日 dump |

## 一句话结论

编排与可靠性设计有想法，但被两件事拖垮——**一次没迁移完调用点的 Redis 重构**（P0 直接来源）和**一套验证 mock 而非行为的测试体系**（P0 至今未暴露的原因）。先花一天止血，再按 P1→P2 做结构收敛，P3 随手推进。
