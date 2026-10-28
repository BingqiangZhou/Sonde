# 01 · v0 基线盘点（2026-10-28 实测）

> main 已重置到 v0 末端提交 724455ce。本文档是对当前代码的实测盘点，作为后续开发的出发点。若实施中发现与本文不符，以代码为准并回写本文。

## 1. 后端（backend/，uv 管理，Python ≥3.11）

### 1.1 结构

- 入口 `app/main.py`（FastAPI 工厂）+ `app/bootstrap/`（routers/http/lifecycle：CORS、slowapi 限流、健康检查、启停顺序、启动时 Redis 锁重置僵死转写）。
- 业务域仅两个：
  - `app/domains/podcast/` —— 全部业务：10 个 route 模块、episode/playback/queue/schedule/search/stats/transcription/content(摘要/高亮/日报)/conversation 服务、Celery tasks、六步转写流水线、SecureRSS 解析；
  - `app/domains/ai/` —— 仅模型配置（`ai_model_configs`，Fernet 加密 api_key）与文本生成调用，无 HTTP 路由。
- `app/admin/` —— Jinja2 服务端渲染管理面板（挂 `/api/v1/admin`）：仪表盘、AI Key 管理（测试/加密导出导入）、订阅管理（批量/OPML/测活）、系统设置。
- `core/`：config、database（async SQLAlchemy/asyncpg）、auth、celery_app、redis、ai_client（OpenAI 兼容 + 重试 + 模型回退链）、security/encryption（Fernet）、rate_limit 等。

### 1.2 认证现状（关键）

- **单用户 API Key**：`core/auth.py` —— `Authorization: Bearer <key>` 或 `X-API-Key` 与 `settings.API_KEY` 恒时比较；`API_KEY` 为空（开发态）时**全放行**；`SINGLE_USER_ID = 1` 硬编码。
- **多用户 JWT 域（原 `app/domains/user/`）已在 2026-04 "后端简化"中整体删除**；`users` 表仅存于迁移（001:172，2FA 列已在 024 删），**无 ORM 模型**；`user_sessions`、`password_resets` 表已删。
- 恢复依据：接口契约完整保存在 `backend/docs/AUTHENTICATION.md`（register / login / refresh / me / logout / logout-all；bcrypt；access 30min / refresh 7d；user_sessions 含设备信息）。
- Flutter 端邮箱登录 UI 完整保留且仍调用这些接口（见 §2），恢复后端即可对接。

### 1.3 数据模型（alembic 001→024 + f5b233bd 简化迁移）

| 表 | 归属 | 关键列/说明 | 模型位置 |
|---|---|---|---|
| `users` | 全局 | email/username/hashed_password/settings/preferences/api_key；**表在库中，无 ORM 模型** | 迁移 001 |
| `subscriptions` | 全局 | title、source_type+source_url **唯一（feed 去重）**、config、status、last_fetched_at、fetch_interval | podcast/models.py:325 |
| `user_subscriptions` | per-user | user+subscription 唯一对、update_frequency(HOURLY/DAILY/WEEKLY)、is_archived、playback_rate_preference；调度数学硬编码沪时区 | models.py:374 |
| `podcast_episodes` | 全局 | title、published_at、audio_url/duration/size、ai_summary、ai_confidence_score、item_link 唯一、play_count、status(pending_summary) | models.py:36 |
| `podcast_episode_transcripts` | 全局 | episode PK、transcript_content、word_count（大字段独立表） | models.py:574 |
| `transcription_tasks` | 全局 | 1:1 episode；status(pending/in_progress/completed/failed/cancelled)、current_step(六步状态机)、progress、chunk_info、summary 结果回填 | models.py:602 |
| `podcast_playback_states` | per-user | user+episode、position、playback_rate(0.5–3.0) | models.py:151 |
| `podcast_queues` / `podcast_queue_items` | per-user | 队列 + 有序条目、revision | models.py:196/… |
| `conversation_sessions` / `podcast_conversations` | per-user | 单集 AI 对话（含父子消息线程） | models.py:750/… |
| `podcast_daily_reports` / `..._items` | per-user | **旧日报（一句话摘要列表，03:30 沪），将被全局三刊淘汰** | models.py:869/… |
| `highlight_extraction_tasks` / `episode_highlights` | 全局 | 高亮提取（insight/novelty/actionability 0-10 分）；`is_user_favorited` 布尔非多用户，将废弃 | models.py:962/… |
| `ai_model_configs` | 全局 | 转写/生成模型配置，Fernet 加密 api_key，并发/成本/用量统计 | ai/models.py:30 |
| `system_settings` | 全局 | 管理面板 KV 设置 | admin/models.py:10 |

已删表（简化迁移）：2FA、admin_audit_logs、user_sessions、password_resets、background_task_runs、subscription_categories 等。

### 1.4 队列（Celery beat，Redis broker，队列 `default`）

| 任务 | 调度 | 实现 |
|---|---|---|
| `refresh-podcast-feeds` | 每小时整点 | tasks/tasks_subscription.py:23（按 per-user 计划判定，顺带内联派发待转写） |
| `generate-pending-summaries` | 每 1800s | tasks/tasks_summary.py:20 |
| `generate-daily-podcast-reports` | 19:30 UTC（≈03:30 沪） | tasks/tasks_daily_report.py:26（**将被三刊取代**） |
| `auto-cleanup-cache` | 04:00 | tasks/tasks_maintenance.py:74 |

事件驱动任务：process_audio_transcription、process_podcast_episode_with_transcription、process_pending_transcriptions（无 beat，由刷新/路由触发）、extract_episode_highlights、generate_episode_summary、cleanup_* 等。

### 1.5 转写与 AI

- 六步流水线 `domains/podcast/transcription/`：下载（≤500MB，仅 http/https）→ ffmpeg 转 mp3 → 10MB 分块 → SiliconFlow 兼容 `/audio/transcriptions`（默认 `FunAudioLLM/SenseVoiceSmall`，信号量 4，重试 3）→ 合并 → 回填。
- `core/ai_client.py`：OpenAI 兼容 chat，重试 + 跨模型回退链；模型/密钥取自 `ai_model_configs`（env 兜底）。
- **无 receipts 成本台账**（v1 有，Phase C 移植）。

### 1.6 API 面（全部挂 `require_api_key`）

- `/api/v1/podcasts/episodes*`：feed、列表、history(-lite)、{id}、{id}/summary(POST)、{id}/playback(PUT/GET)、rate effective/apply、summaries/pending、summaries/models、search
- `/api/v1/podcasts/queue*`：队列 CRUD/重排/当前条目
- `/api/v1/podcasts/stats`、`/stats/profile`
- `/api/v1/podcasts/reports/daily`(+generate/dates)（旧日报，将淘汰）
- `/api/v1/podcasts/episodes/{id}/transcribe`、`transcription`（GET/DELETE）、`transcriptions/{task_id}/status`、`transcribe/schedule`、`transcript`、`transcription/cancel`、`subscriptions/{id}/transcribe/batch`、`check-new-episodes`、`transcriptions/pending`
- `/api/v1/podcasts/episodes/{id}/conversation-sessions|conversations*`（AI 对话）
- `/api/v1/podcasts/highlights*`
- `/api/v1/podcasts/subscriptions*`：CRUD、bulk-delete、refresh、reparse、schedule（含 batch/all）
- `/api/v1/admin`（HTML 面板，同 API Key 鉴权，支持 HMAC cookie）
- 内部：`/health`、`/api/v1/health(/ready)`
- **没有**：auth 域、discover、favorites、site 公开读接口。

### 1.7 配置（backend/app/core/config.py + backend/.env.example）

要点：`ENVIRONMENT/DEBUG`、`SECRET_KEY`（自动生成持久化于 DATA_DIR/.secret_key，**重生成会使加密 Key 失效**）、`API_KEY`、`DATABASE_URL` + 连接池、`REDIS_URL`、`CELERY_*`、`ALLOWED_HOSTS`、`OPENAI_API_KEY/BASE_URL`、`TRANSCRIPTION_API_URL/KEY` + 分块/存储/并发、`MAX_PODCAST_SUBSCRIPTIONS`（0=不限）、`RSS_POLL_INTERVAL_MINUTES`、`AI_CLIENT_*` 等。

## 2. Flutter 端（frontend/）

- pubspec：`personal_ai_assistant` 0.52.0+114，SDK ≥3.8；Riverpod 3.2 + riverpod_annotation、go_router 17.1、dio + retrofit + dio_cache_interceptor、drift + drift_flutter、flutter_secure_storage、audioplayers 6.6 + audio_service 0.18.18、en/zh i18n、window_manager（桌面标题 "Stella"）；dev: build_runner、very_good_analysis、mocktail。
- 结构：`lib/core`（app/config/database/localization/network/platform/router/theme/adaptive…）+ `lib/features`（auth、home 壳、podcast 主体、profile、settings、splash）。
- 路由壳：splash → 登录或主壳；`StatefulShellRoute` 三分支 `/discover` `/feed` `/profile`（子路由 history/subscriptions/downloads/cache）；push 路由 reports/highlights/episode-detail/settings。
- **API 客户端**：`core/network/dio_client.dart` —— baseUrl `<server>/api/v1`（服务器地址由 server_config_dialog 持久化）；Bearer access token 取自 flutter_secure_storage；401 → `token_refresh_service` POST `/auth/refresh`（**当前后端无此路由，必 404**）；retrofit 客户端镜像后端 /podcasts/* 全部端点。
- **登录 UI 完整保留**：login/register/forgot/reset/verify/onboarding，调 `/api/v1/auth/*`。
- 发现页：**直连** `itunes.apple.com/search+lookup` 与 `rss.marketingtools.apple.com` 榜单（16 国枚举，默认 cn）。
- 播放：audio_service 后台播放/锁屏控件、全局播放器、底部迷你条、睡眠定时、倍速（随 per-user/订阅同步）、队列控制、本地持久化。
- 本地库（drift v5）：download_tasks、playback_states、episodes_cache。
- 平台目录：android/ios/web/windows/macos/linux 齐全；测试 test/{unit,widget,integration,core,features}；`tool/backend_contract_smoke.ps1`。

## 3. 基础设施

- `docker/docker-compose.yml` 五服务：postgres:15-alpine（127.0.0.1:5432）、redis:7-alpine、backend（uvicorn :8000，健康检查 /api/v1/health，entrypoint 自动 `alembic upgrade head`）、celery_worker（同镜像，`worker -B --concurrency=1`，beat 合并）、nginx（80/443 自动 SSL）。
- `.github/workflows/release.yml`：tag `v*.*.*`/手动触发；prepare-release → build-android(签名 APK)/windows/linux/macos/ios → create-release。
- `scripts/`：init.sql、test_auth_api.sh（**过期**）、verify-optimizations.sh、dev/（垃圾目录）。

## 4. 基线问题清单（Phase A 清理项）

1. 过期文档：根 README（宣称"JWT 双 Token"）、`backend/docs/AUTHENTICATION.md`（描述已删系统——保留作恢复契约，加"待恢复"标注）、`scripts/test_auth_api.sh`。
2. 根目录 `.env` 是 **TS 遗留**（sonde mock 变量），backend 不读它。
3. `scripts/dev/` 垃圾目录；`TRANSCRIPTION_BACKLOG_SCHEDULE_MINUTE` 死配置。
4. 本机仍在运行 TS 旧容器（sonde-web/api/worker/db），需停并清理。
5. frontend 应用名/窗口名仍是 personal_ai_assistant / Stella。

## 5. 基线验证进度

| 项 | 状态 |
|---|---|
| `uv sync --extra dev`（uv 0.11.0） | ✅ 2026-10-28 通过 |
| `uv run pytest` | ⏸ 未完成（中断，Phase A 补齐） |
| `uv run ruff check .` | ⬜ 未跑 |
| v0 docker 栈 | ⬜ 未起 |
| `flutter pub get` / `flutter analyze` | ⬜ 未跑 |
