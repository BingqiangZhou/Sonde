# 声读 Sonde

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/flutter-3.8+-cyan)](https://flutter.dev/)
[![Docker](https://img.shields.io/badge/docker-supported-blue)](https://www.docker.com/)

**个人播客知识库**：订阅播客 → 自动转写全文 → AI 评分筛选 → 每天/周/月自动成刊（中文日报/周报/月报），多端阅读与收听。

- **backend/** — Python FastAPI（+ Celery + Redis + PostgreSQL）：订阅抓取、六步转写流水线、AI 评分与三刊成刊、多用户认证、管理面板
- **frontend/** — Flutter 多端客户端（Android / iOS / 桌面 / Web）：登录、订阅管理、发现、播放、三刊阅读
- **web/** — 报刊风中文阅读站（React Router SSR），只经 HTTP 读后端

> **v2（2026-10-28）**：回归 Python + Flutter 多用户形态，移植 v1.x TS 版的 AI 评分/三刊流水线，六阶段转向已全部完成（决策与实施记录见 [`docs/v2-pivot/`](docs/v2-pivot/README.md)）；v1.x TS 版完整存档于 [`ts-era`](https://github.com/BingqiangZhou/Sonde/tree/ts-era) 分支。

## 功能

- **多用户**：邮箱注册（可关闭）+ JWT；每人自己的订阅、播放进度、收藏
- **订阅**：RSS 播客订阅，feed 全局去重（多人订阅同一播客只转写/评分一次），可配置抓取频率
- **转写**：音频下载 → ffmpeg → 分块 → OpenAI 兼容 ASR → 全文转录
- **AI 评分筛选**：LLM 按注意力价值为单集打分（0-100），按源分级门槛（T1/T2）入选；落选保留分数与理由
- **三刊**：日报（每天 08:00）、周报（周一 08:30）、月报（每月 1 日 08:30，Asia/Shanghai）；主编 prompt 成刊，报刊风排版
- **发现**：iTunes 多国搜索 + 热门榜（经后端代理出站；`ITUNES_PROXY_URL` 走 HTTP 代理，容器直连不稳时推荐）
- **收藏**：per-user 云同步（App 星标 + 收藏页）
- **播放**：后台播放、锁屏控制、倍速、进度续播（per-user 云同步）
- **成本台账**：每次 LLM/转写调用入 receipts，面板可查

## 快速开始

```bash
# 1. 基础设施 + 后端 + worker + nginx（首次会自动跑 alembic 迁移）
cd docker
cp .env.example .env        # 按需修改（POSTGRES_PASSWORD 等）
docker compose up -d --build
curl http://localhost:8000/api/v1/health

# 2. Flutter 客户端
cd frontend
flutter pub get
flutter run                 # App 内配置服务器地址为 http://<主机>:8000
```

本地开发（不用 Docker）：

```bash
# 后端
cd backend
uv sync --extra dev
cp .env.example .env        # 填 API_KEY / DATABASE_URL / REDIS_URL
uv run uvicorn app.main:app --reload
uv run pytest               # 测试（内存 SQLite，无需 Docker）

# Web 阅读站
cd web
npm install
npm run dev                 # 开发；API 基址用环境变量 API_URL 指向后端
```

## 仓库结构

```
backend/            FastAPI 应用（app/domains: podcast, ai；app/admin: 管理面板；app/industry: 定制层）
backend/app/industry/   站点定制层：site/taxonomy/selection 配置 + prompts/*.md（改配置不改代码）
frontend/           Flutter 客户端（Riverpod 3 + GoRouter + Drift + audio_service）
web/                React Router 8 SSR 阅读站（独立 npm 项目）
docker/             Docker Compose（postgres / redis / backend / celery_worker / nginx）
docs/               设计文档；docs/v2-pivot/ 为 v2 转向文档集（当前开发依据）
specs/              历史规格记录
```

## 文档

- 📋 [CHANGELOG.md](CHANGELOG.md) — 更新历史（v1.x TS 版见 ts-era 分支）
- 🗂 [docs/v2-pivot/](docs/v2-pivot/README.md) — v2 转向决策、基线盘点、目标架构与 Phase A–F 实施计划
- 🔧 [AGENTS.md](AGENTS.md) / [CLAUDE.md](CLAUDE.md) — 仓库开发约定

## License

MIT
