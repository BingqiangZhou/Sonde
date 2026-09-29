# Docker 部署目录

Sonde（声读）的 Docker 部署配置。Compose 项目名固定为 `sonde`（容器 `sonde-*`、卷 `sonde_*`、网络 `sonde_network`），与目录名无关。

4 个服务：postgres (PostgreSQL 15，数据 + procrastinate 任务队列)、backend (FastAPI，独占执行 alembic 迁移与 procrastinate schema 应用)、worker (procrastinate 异步任务 + 周期调度，容器固定 TZ=UTC)、caddy (反向代理 + 自动 HTTPS)。

---

## 快速开始

### 1. 配置环境

```bash
cd docker

# 复制并编辑配置文件
cp .env.example .env
nano .env

# 必须修改的配置:
# - POSTGRES_PASSWORD: 数据库密码
# - SECRET_KEY: 密钥 (用 openssl rand -hex 32 生成)
# - DOMAIN: 你的域名 (如果有)

# 常用可选配置:
# - WORKER_CONCURRENCY: 任务 worker 并发数 (默认 1)
# - MAX_BODY_SIZE: 请求体大小上限 (默认 20MB)
# - ACME_EMAIL: ACME 自动证书邮箱 (公网域名时使用)
# - CADDY_CONF_DIR: Caddyfile 挂载目录 (默认 ./caddy)
```

### 2. 启动服务

```bash
cd docker
docker compose up -d --build
```

### 3. 访问服务

- Backend: http://localhost:8000
- API 文档: http://localhost:8000/api/v1/docs
- 健康检查: http://localhost:8000/api/v1/health

### TLS 证书（生产环境）

Caddy 默认 `tls internal`（内置 CA 自动签发本地证书），零配置零续期。公网域名可切换 ACME 自动证书或挂载手动证书，见 [caddy/README.md](caddy/README.md)。

---

## 目录结构

```
docker/
├── docker-compose.yml          # Docker Compose 配置
├── .env.example                # 环境配置模板
├── .env                        # 实际环境配置
├── caddy/                      # Caddy 反向代理
│   ├── Caddyfile               # 站点配置（环境变量占位符）
│   └── README.md               # TLS 模式与运维说明
└── README.md                   # 本文件
```

---

## 验证部署

启动成功后，检查服务：

```bash
# 1. 查看服务状态
docker compose ps

# 2. 健康检查
curl http://localhost:8000/api/v1/health
# 预期: {"status": "healthy"}

# 3. 就绪检查（检查数据库）
curl http://localhost:8000/api/v1/health/ready

# 4. worker 健康检查
docker compose exec worker python -m app.bootstrap.worker --healthcheck

# 5. 访问 API 文档
# 浏览器打开: http://localhost:8000/api/v1/docs
```

---

## 常用命令

### 启动/停止

```bash
# 启动
docker compose up -d

# 停止
docker compose down

# 重启后端
docker compose restart backend
```

### 查看日志

```bash
# 所有服务日志
docker compose logs -f

# 仅后端日志
docker compose logs -f backend

# 最近 20 行
docker compose logs --tail=20 backend
```

### 数据管理

```bash
# 删除所有数据并重新开始
docker compose down -v

# 查看数据库
docker compose exec postgres psql -U admin -d sonde
```

### Caddy 管理

```bash
# 校验配置（也是 caddy 容器的 healthcheck）
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# 重新加载配置
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# 查看 Caddy 日志（输出到容器 stdout）
docker compose logs -f caddy
```

---

## 测试部署

```bash
# 在容器中运行后端测试
docker compose exec backend uv run pytest
```

---

## 部署成功检查清单

- [ ] 配置 `docker/.env` 并修改密码、域名
- [ ] 服务启动: `docker compose ps` 显示 4 个服务 **Up**
- [ ] 健康检查: `curl http://localhost:8000/api/v1/health` 返回健康
- [ ] API 文档可访问: `http://localhost:8000/api/v1/docs` 正常显示
- [ ] 功能测试: 能添加播客订阅

### 生产环境额外检查

- [ ] 按 [caddy/README.md](caddy/README.md) 确认 TLS 模式（默认 `tls internal`；公网域名可切 ACME 或手动证书）
- [ ] Caddy 配置校验通过: `docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile`
- [ ] HTTPS 访问正常

---

## 相关文档

- **部署指南**: [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)
- **Caddy 配置**: [caddy/README.md](caddy/README.md)
