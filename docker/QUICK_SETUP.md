# 快速配置指南 / Quick Setup Guide

## 概述

现在**只需要配置一个 `.env` 文件**就可以完成所有配置，包括：
- 数据库与任务队列
- 域名和 TLS 证书
- 后端 API 配置
- 外部服务密钥

**无需手动修改 Caddy 配置文件！**

---

## 生产环境部署 (3 步搞定)

### 步骤 1: 配置 .env 文件

```bash
cd docker
cp .env.example ../backend/.env
nano ../backend/.env
```

**必须修改的配置**:
```bash
# ============ 必须修改 ============
DOMAIN=your-domain.com              # 你的域名
POSTGRES_PASSWORD=secure_password   # 数据库密码
JWT_SECRET_KEY=random_secret_key    # JWT 密钥
```

> **API 密钥不在 `.env` 配置**：OpenAI / 转录等第三方 key 在服务启动后通过后台管理面板配置（`/api/v1/admin` → API Keys），加密存储、即时生效。

### 步骤 2: 确认 TLS 模式（默认零配置）

Caddy 默认 `tls internal`（内置 CA 自动签发本地证书并自动续期），**无需放置任何证书文件**。公网域名部署时，按 [caddy/README.md](caddy/README.md) 切换 ACME 自动证书（`.env` 设置 `ACME_EMAIL` 并修改 Caddyfile 中 `tls` 指令）或挂载手动证书。

### 步骤 3: 启动服务

```bash
cd docker
docker-compose --env-file ../backend/.env up -d
```

访问: `https://your-domain.com`

---

## 工作原理

### Caddy 配置自动化

`caddy/Caddyfile` 直接使用 `{$ENV_VAR}` 环境变量占位符，容器启动时由 Caddy 从环境注入（无需 envsubst 模板渲染）：

**.env 文件**:
```env
DOMAIN=example.com
MAX_BODY_SIZE=20MB
```

**Caddyfile** (`caddy/Caddyfile`):
```caddyfile
{$DOMAIN:localhost} {              # 自动替换为 example.com
    tls internal
    request_body {
        max_size {$MAX_BODY_SIZE:20MB}  # 自动替换请求体上限
    }
    reverse_proxy backend:8000
}
```

启动时自动注入，无需手动修改！

---

## .env 文件结构

```
.env.example (统一配置模板)
├── 项目配置
│   ├── PROJECT_NAME
│   └── ENVIRONMENT
├── Caddy 配置
│   ├── DOMAIN                  # 站点地址（默认 localhost）
│   ├── MAX_BODY_SIZE           # 请求体大小上限（默认 20MB）
│   ├── ACME_EMAIL              # ACME 自动证书邮箱（公网域名时使用）
│   └── CADDY_CONF_DIR          # Caddyfile 挂载目录
├── 数据库配置
│   ├── POSTGRES_USER
│   └── POSTGRES_PASSWORD
├── 后端配置
│   ├── BACKEND_WORKERS
│   ├── WORKER_CONCURRENCY      # 任务 worker 并发数（默认 1）
│   └── LOG_LEVEL
├── JWT 配置
│   └── JWT_SECRET_KEY
└── 外部服务
    └── TRANSCRIPTION_API_URL
```

> AI 服务密钥（OpenAI / SiliconFlow 等）不在 `.env` 中，通过后台管理面板 `/api/v1/admin/apikeys` 配置。

---

## 常见问题

### Q1: .env 可以和后端的 .env 合并吗?

**A**: 已经合并了！`docker/.env.example` 包含所有配置，复制到 `backend/.env` 即可。

### Q2: 如何修改域名?

**A**: 只需修改 `.env` 中的 `DOMAIN` 变量，重启 Caddy 即可。

```bash
# 编辑 .env
DOMAIN=new-domain.com

# 重启 Caddy
docker-compose restart caddy
```

### Q3: 开发环境需要配置 TLS 吗?

**A**: 不需要。默认 `DOMAIN=localhost` 时 Caddy 用内置 CA 自动签发本地证书，开箱即用（浏览器首次访问需信任 Caddy 根证书，见 [caddy/README.md](caddy/README.md)）。

### Q4: 需要手动放置 SSL 证书吗?

**A**: 默认不需要。`tls internal` 模式零配置；仅在使用外部签发的手动证书时，按 [caddy/README.md](caddy/README.md) 挂载证书目录并修改 Caddyfile 的 `tls` 指令。

---

## 配置对比

### 旧方式 (手动配置，已废弃)

```bash
# 1. 修改 .env
nano .env

# 2. 手动编辑反向代理配置文件
# 修改 server_name、证书路径...

# 3. 启用配置
# 手动切换/重载配置文件...
```

### 新方式 (只用 .env)

```bash
# 1. 修改 .env (包含域名、TLS 模式等)
nano backend/.env

# 2. 启动 (自动读取配置)
docker-compose --env-file backend/.env up -d
```

---

## 完整示例

```bash
# 1. 准备配置
cd docker
cp .env.example ../backend/.env

# 2. 编辑配置 (修改这3项即可)
nano ../backend/.env
DOMAIN=api.example.com
POSTGRES_PASSWORD=MySecurePassword123!
JWT_SECRET_KEY=$(openssl rand -hex 32)

# 3. 启动（默认 tls internal，无需证书文件；
#    公网域名 ACME 证书见 caddy/README.md）
docker-compose --env-file ../backend/.env up -d

# 完成！访问 https://api.example.com
```
