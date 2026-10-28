# Repository Guidelines

声读 Sonde v2 — Python + Flutter 多用户播客知识库。当前处于 v2 转向实施期（Phase A–F），**开发依据与阶段状态见 `docs/v2-pivot/README.md`**，动工前先读对应 Phase 文档。

## Project Structure & Module Organization
- `backend/`: FastAPI service (DDD layout) with core, shared, admin, and domain modules (`ai`, `podcast`) in `backend/app/`.
- `backend/app/industry/`: 声读定制层 — `site.py` / `taxonomy.py` / `selection.py` 常量 + `prompts/*.md`（LLM prompt 模板，`{{var}}` + `{{> include}}`）。站点个性改这里，不改代码；prompt 文本永不内联进 Python。
- `backend/alembic/`: database migrations.
- `backend/tests/` and `backend/app/**/tests/`: backend test suites.
- `frontend/`: Flutter app with feature modules in `frontend/lib/` and tests in `frontend/test/`. Dart 包名为 `sonde`，平台标识统一 `app.sonde`（v2.0.1 起，旧名 personal_ai_assistant/com.opc.stella 已全量移除）。
- `web/`: React Router 8 SSR 阅读站（独立 npm 项目，无 workspace）。
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
- Web: `cd web && npm install && npm run build`（typecheck: `npm run typecheck`）
- Docker backend verification (required): `cd docker && docker compose up -d --build`，`curl http://localhost:8000/api/v1/health`
- 本机网络不畅时构建镜像：`docker/.env` 设 `BUILD_HTTP_PROXY=http://host.docker.internal:7897`

## Coding Style & Naming Conventions
- Backend uses `ruff` for linting/formatting; do not use `black`, `isort`, or `flake8`.
- Use `uv` for Python package management; avoid `pip install`.
- Follow async/await patterns for I/O in the backend (SQLAlchemy async, aiohttp, redis).
- Frontend uses Material 3 + platform-adaptive UI (CupertinoTheme wrapper, `.adaptive()` widgets); theme tokens (`AppColors`/`AppRadius`/`AppSpacing`) — no hardcoded values.
- Web: React Router framework mode, Tailwind, no component library; Chinese-first UI copy.
- 付费 AI 调用必须走 provider 层并写 receipts 成本台账（Phase C 起）。

## Testing Guidelines
- Backend: pytest with async tests; run `uv run pytest` before PRs.
- Frontend: widget tests are mandatory for page functionality.
- Verify backend via Docker (not only local uvicorn).

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `style:`, `docs:`.
- 按阶段分组提交（Phase A–F），不跨阶段混合。

## Environment & Secrets
- Backend config lives in `backend/.env`（from `.env.example`）；Docker 编排在 `docker/.env`。Never commit secrets.
- Health check: `curl http://localhost:8000/api/v1/health`.

## Configuration & Requirements Notes
- API endpoints are prefixed with `/api/v1/`.
- 当前后端为单用户 API Key 认证；多用户 JWT 在 Phase B 恢复（契约见 `backend/docs/AUTHENTICATION.md`）。
- 日期/时区：报告窗口按 Asia/Shanghai 日历计算，DB 存 timestamptz (UTC)。
- Check `docs/v2-pivot/` before implementing new work.
