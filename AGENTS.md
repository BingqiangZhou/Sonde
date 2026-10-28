# Repository Guidelines

声读 Sonde v2 — Python + Flutter 多用户播客知识库。当前处于 v2 转向实施期（Phase A–G），**开发依据与阶段状态见 `docs/v2-pivot/README.md`**，动工前先读对应 Phase 文档。

## Project Structure & Module Organization
- `backend/`: FastAPI service (DDD layout) in `backend/app/`:
  - `bootstrap/` lifecycle、middleware、routing、cache warming；`core/` config、database、redis、security、auth、exceptions、celery、ai_client、http_client
  - `shared/` 跨域工具（repository helpers、schemas）；`http/` error helpers 与 route decorators
  - `domains/` podcast（episodes、subscriptions、transcriptions、summaries、conversations、highlights）+ ai（model config、providers）
  - `admin/` Admin panel（server-rendered HTML，API-Key auth）— `app/` 下独立顶层模块，不在 `domains/` 内
- `backend/app/industry/`: 声读定制层 — `site.py` / `taxonomy.py` / `selection.py` 常量 + `prompts/*.md`（LLM prompt 模板，`{{var}}` + `{{> include}}`）。站点个性改这里，不改代码；prompt 文本永不内联进 Python。
- `backend/alembic/`: database migrations.
- `backend/tests/` and `backend/app/**/tests/`: backend test suites.
- `frontend/`: Flutter app in `frontend/lib/`（`core/`：database (Drift)、theme、network (Dio + token refresh)、widgets (adaptive/)；`features/`：auth, podcast, profile, settings, splash, home）with tests in `frontend/test/`. Dart 包名为 `sonde`，平台标识统一 `app.sonde`（v2.0.1 起，旧名 personal_ai_assistant/com.opc.stella 已全量移除）。阅读站功能（三刊/归档/全部动态）在 App「阅读」Tab 内（Phase G；原 `web/` React 阅读站已退役删除）。
- `docker/`: Docker Compose files and deployment assets (postgres, redis, backend, celery_worker, nginx).
- `docs/` and `specs/`: design notes; `docs/v2-pivot/` is the active v2 pivot doc set.

## Build, Test, and Development Commands
- Backend dependencies: `cd backend && uv sync --extra dev`
- Migrations: `uv run alembic upgrade head`
- Run API locally: `uv run uvicorn app.main:app --reload`
- Lint/format (backend): `uv run ruff check .` and `uv run ruff format .`
- Backend tests: `uv run pytest`
- Frontend deps: `cd frontend && flutter pub get`
- Frontend code gen: `cd frontend && dart run build_runner build` (required after modifying `@riverpod`, `@RestApi`, `@JsonSerializable`, or Drift files)
- Frontend tests: `flutter test`; l10n: `flutter gen-l10n` (edit both en/zh ARB)
- Docker backend verification (required): `cd docker && docker compose up -d --build`，`curl http://localhost:8000/api/v1/health`
- 本机网络不畅时构建镜像：`docker/.env` 设 `BUILD_HTTP_PROXY=http://host.docker.internal:7897`

## Coding Style & Naming Conventions
- Backend uses `ruff` for linting/formatting; do not use `black`, `isort`, or `flake8`.
- Use `uv` for Python package management; avoid `pip install`.
- Follow async/await patterns for I/O in the backend (SQLAlchemy async, aiohttp, redis).
- Exceptions: service 层抛 `BaseCustomError`；routes 用 `app.http.errors` 的 `HTTPException`。DI 用 FastAPI `Depends()`；migrations 在 `backend/alembic/`。
- Celery: 单 `default` 队列，worker 带 embedded beat（`-B` flag）运行。
- Frontend uses Material 3 + platform-adaptive UI (CupertinoTheme wrapper, `.adaptive()` widgets); theme tokens (`AppColors`/`AppRadius`/`AppSpacing`) — no hardcoded values.
- Frontend responsive breakpoints: mobile <600 | tablet 600–1200 | desktop >=1200。
- 付费 AI 调用必须走 provider 层并写 receipts 成本台账（Phase C 起）。

## Testing Guidelines
- Backend: pytest with async tests; run `uv run pytest` before PRs（SQLite in-memory via aiosqlite，无需 Docker）。
- Frontend: widget tests are mandatory for page functionality.
- Verify backend via Docker (not only local uvicorn).
- A task is NOT COMPLETE until: code compiles, tests pass, and modified functionality works end-to-end.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `style:`, `docs:`.
- 按阶段分组提交（Phase A–G），不跨阶段混合。
- 项目级 ZCode skill：`/commit`（智能提交，`.agents/skills/commit/`）、`/release`（发版流程，`.agents/skills/release/`）。

## Environment & Secrets
- Backend config lives in `backend/.env`（from `.env.example`）；Docker 编排在 `docker/.env`。Never commit secrets.
- 不要读取或提交 `.env*`、`*.pem`、`*.key`、云凭证等敏感文件。
- Health check: `curl http://localhost:8000/api/v1/health`。端点全集：`GET /health` 与 `GET /api/v1/health`（liveness）、`GET /api/v1/health/ready`（readiness）。

## Configuration & Requirements Notes
- API endpoints are prefixed with `/api/v1/`.
- 当前后端为多用户 JWT 认证（Phase B 恢复，契约见 `backend/docs/AUTHENTICATION.md`）；`/api/v1/site/*` 自 Phase G 起同样需登录态。
- 日期/时区：报告窗口按 Asia/Shanghai 日历计算，DB 存 timestamptz (UTC)。
- Check `docs/v2-pivot/` before implementing new work.

## Gotchas

| Wrong | Correct |
|-------|---------|
| `pip install` | `uv add` / `uv sync` |
| `flutter_adaptive_scaffold` | `CustomAdaptiveNavigation` + `Breakpoints` |
| 硬编码颜色/圆角/间距 | `AppColors` / `AppRadius` / `AppSpacing` tokens |
| 手改 `.g.dart` | 改源码后重跑 `dart run build_runner build` |
| 裸 `ValueError` | `BaseCustomError`（service）/ `HTTPException`（route） |
| `Color.withOpacity()` | `Color.withValues(alpha:)`（前者已弃用） |
| Python 内联 LLM prompt | `backend/app/industry/prompts/*.md` |
| `admin` 放进 `domains/` | `admin/` 是 `app/` 下独立顶层模块 |
| 使用旧包名 personal_ai_assistant / com.opc.stella | Dart 包名 `sonde`，平台标识 `app.sonde` |
