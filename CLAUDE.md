# 声读 Sonde v2

Python FastAPI + Flutter 播客知识库（多用户，v2 转向实施中）。转向文档集：`docs/v2-pivot/`（开发必读）。

## Commands

### Backend (Python 3.11+, uses uv — NEVER pip)
```bash
cd backend
uv sync --extra dev                    # Install deps
uv run alembic upgrade head            # Run migrations
uv run uvicorn app.main:app --reload   # Dev server
uv run ruff check .                    # Lint (NOT black/isort/flake8)
uv run pytest                          # Tests (SQLite in-memory, no Docker needed)
```

### Frontend (Flutter 3.8+, Dart)
```bash
cd frontend
flutter pub get                        # Install deps
dart run build_runner build            # Code gen (required after @riverpod, @RestApi, @JsonSerializable, Drift)
flutter test                           # All tests
flutter gen-l10n                       # After editing both en.arb and zh.arb
```

### Web (React Router SSR)
```bash
cd web
npm install
npm run build && npm run typecheck     # Build + typecheck
API_URL=http://127.0.0.1:8000 npm run start   # 生产 server（/api 反代到后端）
```

### Docker (full-stack verification)
```bash
cd docker && docker compose up -d --build
curl http://localhost:8000/api/v1/health
# 国内网络构建失败时：docker/.env 设 BUILD_HTTP_PROXY=http://host.docker.internal:7897
```

## Project Structure

```
backend/app/
  bootstrap/      Lifecycle, middleware, routing, cache warming
  core/           Config, database, redis, security, auth, exceptions, celery, ai_client, http_client, middleware
  shared/         Cross-domain utilities (repository helpers, schemas)
  domains/        podcast (episodes, subscriptions, transcriptions, summaries, conversations, highlights), ai (model config, providers)
  industry/       声读定制层：site/taxonomy/selection 常量 + prompts/*.md（LLM 模板；改配置不改代码）
  http/           Error helpers, route decorators
  admin/          Admin panel (server-rendered HTML templates, API-Key auth)

frontend/lib/
  core/           database (Drift), theme (AppColors), constants, widgets (adaptive/), platform, network (Dio + token refresh), services, storage, utils
  features/       auth, podcast (largest), profile, settings, splash, home

web/              React Router 8 SSR 阅读站（独立 npm 项目；app/routes.ts 定义页面；server.ts 反代 /api）
```

## Conventions

### Backend
- **uv only** (NEVER pip). **ruff only** for lint/format (NOT black/isort/flake8)
- All I/O is async (SQLAlchemy async, aiohttp, redis)
- Exceptions: Service layer raises `BaseCustomError`. Routes use `HTTPException` from `app.http.errors`
- DI: FastAPI `Depends()`. Migrations: `backend/alembic/`
- Celery: single `default` queue, worker runs with embedded beat (`-B` flag)
- LLM prompt 文本只放 `backend/app/industry/prompts/*.md`，渲染支持 `{{var}}` + `{{> include}}`，缺失即硬错误（Phase C 接入）

### Frontend
- **Material 3 only**; platform-adaptive UI (CupertinoTheme wrapper + `.adaptive()` widgets)
- Responsive: mobile <600 | tablet 600-1200 | desktop >=1200
- Theme tokens in `AppColors`, spacing in `AppSpacing`; run `dart run build_runner build` after codegen-annotated files
- i18n: edit both ARB files then `flutter gen-l10n`; widget tests mandatory for pages

### API
- Endpoints: `/api/v1/` prefix. 当前为单用户 API Key 认证（`app/core/auth.py`）；多用户 JWT Phase B 恢复
- Health: `GET /health` and `GET /api/v1/health` (liveness), `GET /api/v1/health/ready` (readiness)

### General
- Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `style:`, `docs:`
- 报告窗口时区 Asia/Shanghai；DB timestamptz (UTC)

## Gotchas

| Wrong | Correct |
|-------|---------|
| `pip install` | `uv add` or `uv sync` |
| flutter_adaptive_scaffold | `CustomAdaptiveNavigation` + `Breakpoints` |
| Hardcoded colors/radii/spacing | `AppColors`, `AppRadius`, and `AppSpacing` tokens |
| Edit `.g.dart` by hand | Edit source, re-run `dart run build_runner build` |
| Bare ValueError for errors | `BaseCustomError` (service) or `HTTPException` (route) |
| `Color.withOpacity()` | `Color.withValues(alpha:)` (former is deprecated) |
| Inline LLM prompts in Python | `backend/app/industry/prompts/*.md` |
| `admin` under `domains/` | `admin/` is a separate top-level module at `app/admin/` |
| 使用旧包名 personal_ai_assistant | Dart 包名已改为 `sonde`（v2.0.1），Bundle ID 统一 `app.sonde` |

## Testing & Completion

- **Backend**: `uv run pytest` (SQLite in-memory via aiosqlite)
- **Frontend**: `flutter test`; **Web**: `npm run build && npm run typecheck`
- **Full-stack**: `cd docker && docker compose up -d --build` then verify health endpoint
- A task is NOT COMPLETE until: code compiles, tests pass, modified functionality works end-to-end
