# 部署指南

本指南介绍如何部署 Sonde 到生产环境或开发环境。

## 快速开始

### 环境选择

| 场景 | 配置文件 | 用途 |
|------|----------|------|
| 本地开发 | `docker-compose.yml` | 开发调试，`DOMAIN=localhost` 经 Caddy 本地证书访问 |
| 生产部署 | `docker-compose.yml` | 生产环境，通过 Caddy 代理 + 自动 HTTPS |

> 拓扑说明：自 2026-09 起编排精简为 4 容器（postgres / backend / worker / caddy；pg-boss 方案调研后落地 procrastinate，Redis / Celery beat / nginx 容器均已移除）。

### 开发环境 (3 步)

```bash
# 1. 进入 docker 目录
cd docker

# 2. 启动服务 (Windows)
scripts\start.bat

# Linux/Mac
docker compose up -d --build
```

### 生产环境 (3 步)

#### 步骤 1: 配置 .env

```bash
cd docker
cp .env.example ../backend/.env
nano ../backend/.env
```

必须修改的配置：
```bash
DOMAIN=your-domain.com
POSTGRES_PASSWORD=secure_password
JWT_SECRET_KEY=$(openssl rand -hex 32)
```

> AI 服务密钥（OpenAI / 转写等第三方 key）不在 `.env` 中配置：服务启动后登录后台管理面板 `/api/v1/admin`，在 **API Keys** 页面添加模型并填写密钥（加密存储，即时生效）。

#### 步骤 2: 确认 TLS 模式

Caddy 默认 `tls internal`（内置 CA 自动签发本地证书），零配置零续期，本机/内网自用即可直接用。公网域名部署可切换 ACME 自动证书或挂载手动证书，见 [Caddy 配置](docker/caddy/README.md)。

#### 步骤 3: 启动服务

```bash
cd docker
docker-compose --env-file ../backend/.env up -d
```

---

## Docker 配置说明

### 目录结构

```
docker/
├── docker-compose.yml           # Docker 编排（4 服务，开发/生产共用）
├── .env.example                # 配置模板
├── caddy/                      # Caddy 反向代理
│   ├── Caddyfile              # 站点配置（环境变量占位符）
│   └── README.md              # TLS 模式与运维说明
└── scripts/                   # 启动脚本
```

### 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f backend

# 重启后端
docker-compose restart backend

# 删除所有数据
docker-compose down -v
```

### 环境对比

| 特性 | 开发环境 | 生产环境 |
|------|----------|----------|
| 访问方式 | 直连后端 8000 端口或经 Caddy | Caddy 反向代理 + HTTPS |
| 日志级别 | DEBUG | INFO |
| 数据库端口 | 暴露 5432 | 不暴露 |
| SSL/HTTPS | Caddy 本地证书（tls internal） | Caddy 自动证书 |

---

## 验证部署

### 开发环境

```bash
# 健康检查
curl http://localhost:8000/api/v1/health

# API 文档
# 浏览器打开: http://localhost:8000/api/v1/docs
```

### 生产环境

```bash
# HTTPS 健康检查
curl https://your-domain.com/api/v1/health

# 测试 SSL
curl https://your-domain.com/docs
```

---

## TLS 证书配置（Caddy）

### tls internal（默认，零配置）

Caddy 内置 CA 自动为站点签发本地证书并自动续期，无需任何配置。浏览器首次访问 HTTPS 提示"不受信任"时，导入 Caddy 根证书即可（导出与导入步骤见 [docker/caddy/README.md](docker/caddy/README.md)）。

### ACME 自动证书（公网域名）

公网域名解析到本机且 80/443 可达时，把 `docker/caddy/Caddyfile` 中的 `tls internal` 改为 `tls {$ACME_EMAIL}`，并在 `.env` 设置 `DOMAIN=your-domain.com` 和 `ACME_EMAIL=you@example.com`，然后 `docker compose restart caddy`。证书签发与续期全自动，无需 cron。

### 手动证书

沿用 certbot 等外部签发的证书时，挂载证书目录后把 `tls internal` 改为 `tls /etc/caddy/cert/fullchain.pem /etc/caddy/cert/privkey.pem`（详见 [docker/caddy/README.md](docker/caddy/README.md)）。

---

## 常见问题

### 端口冲突

```bash
# 查找占用端口
netstat -ano | findstr :8000

# 修改 docker/.env 中的端口配置
```

### 数据库连接失败

```bash
# 检查 PostgreSQL 容器
docker ps | grep postgres

# 查看日志
docker logs postgres
```

### 后台任务不执行

```bash
# 检查 worker 容器与日志
docker compose ps worker
docker compose logs -f worker

# worker 健康检查
docker compose exec worker python -m app.bootstrap.worker --healthcheck
```

---

## 服务器规格

### 最小配置 (个人使用)
- CPU: 1 核
- 内存: 1GB
- 磁盘: 10GB

### 推荐配置 (5-10 用户)
- CPU: 2 核
- 内存: 2GB
- 磁盘: 50GB

### 生产配置 (50+ 用户)
- CPU: 4 核
- 内存: 8GB
- 磁盘: 100GB SSD

---

## 安全建议

1. 修改默认的强密码：JWT_SECRET_KEY、POSTGRES_PASSWORD
2. 使用 HTTPS (必须)
3. 配置防火墙，仅开放必要端口
4. 定期更新 Docker 镜像
5. 证书续期：Caddy（tls internal / ACME）全自动续期，无需额外配置

---

## 相关文档

- [后端开发指南](backend/README.md)
- [Flutter 开发指南](frontend/README.md)
- [Caddy 配置](docker/caddy/README.md)
- [认证系统](backend/docs/AUTHENTICATION.md)
