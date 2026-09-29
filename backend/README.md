# Sonde - 后端

FastAPI 后端服务，提供播客订阅、AI 转录、管理面板等功能。

## 技术栈

| 技术 | 说明 |
|------|------|
| FastAPI | 异步 Web 框架 |
| SQLAlchemy | 异步 ORM |
| PostgreSQL | 关系型数据库（兼作任务队列存储） |
| procrastinate | Postgres 原生异步任务队列（worker 内含周期调度） |
| Alembic | 数据库迁移 |
| uv | 包管理器 |

## 快速开始

### 1. 安装依赖

```bash
cd backend
uv sync --extra dev
```

### 2. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，设置数据库连接、密钥等
```

必须配置：
- `DATABASE_URL` - PostgreSQL 连接字符串
- `SECRET_KEY` - 密钥

### 3. 运行数据库迁移

```bash
uv run alembic upgrade head
```

### 4. 启动服务

```bash
# API 服务
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API 文档: http://localhost:8000/api/v1/docs

## 后台任务（procrastinate）

### 启动 Worker（含周期调度）

```bash
uv run python -m app.bootstrap.worker
```

首次运行前需应用任务队列 schema（幂等，Docker 版由 backend 容器自动执行）：

```bash
uv run python -m procrastinate -a app.core.jobs.procrastinate_app schema --apply
```

周期任务由 worker 进程内 cron 触发（procrastinate 的 cron 表达式按进程本地时区求值，需 `TZ=UTC` 才能保持下述 UTC 时刻；worker 容器已固定 TZ=UTC）。并发数用 `WORKER_CONCURRENCY` 控制（默认 1）。

定时任务：
- 每小时刷新播客 Feed
- 每 30 分钟生成待处理摘要
- 每日 4:00 UTC 清理缓存
- 每日 19:30 UTC 生成播客日报

## 代码质量

### 代码检查

```bash
# 代码检查
uv run ruff check .

# 代码格式化
uv run ruff format .
```

### 运行测试

```bash
# 所有测试
uv run pytest

# 指定目录
uv run pytest tests/podcast/
```

## Docker 验证

所有后端测试必须在 Docker 中运行：

```bash
# 启动 Docker 服务
cd docker
docker compose up -d

# 验证服务
docker compose ps
curl http://localhost:8000/api/v1/health
```

验证 worker 服务：
- `worker` - procrastinate asyncio worker（任务执行 + 周期调度），健康检查：`docker compose exec worker python -m app.bootstrap.worker --healthcheck`

## 项目结构

```
backend/
├── app/
│   ├── bootstrap/      # 应用初始化（路由注册、生命周期、缓存预热）
│   │   └── worker.py       # procrastinate worker 入口（任务执行 + 周期调度）
│   ├── core/           # 核心基础设施（配置、安全、数据库、中间件）
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── jobs.py
│   │   ├── advisory_lock.py
│   │   ├── auth.py
│   │   ├── exceptions.py
│   │   ├── security/       # 安全模块（加密、密码）
│   │   └── middleware/     # 中间件（请求日志、限流）
│   ├── shared/         # 共享层（repository helpers, schemas）
│   ├── http/           # HTTP 辅助（错误处理）
│   ├── admin/          # 管理面板（独立认证、CSRF、服务端渲染）
│   └── domains/        # 业务领域
│       ├── podcast/        # 播客订阅、单集、播放、转录、摘要
│       └── ai/             # AI 模型配置、供应商管理
├── alembic/            # 数据库迁移（27 个迁移文件）
├── tests/              # 测试文件
├── pyproject.toml      # 项目配置
└── uv.lock             # 依赖锁定
```

## API 说明

- API 前缀: `/api/v1`
- 管理面板: `/api/v1/admin/*`
- 播客订阅: `/api/v1/podcasts/subscriptions/*`
- 播客单集: `/api/v1/podcasts/*`
- 健康检查: `/health`, `/api/v1/health`, `/api/v1/health/ready`

## 相关文档

- [环境变量配置](README-ENV.md)
- [部署指南](../docs/DEPLOYMENT.md)
