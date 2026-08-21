# 快速配置指南 / Quick Setup Guide

## 概述

现在**只需要配置一个 `.env` 文件**就可以完成所有配置，包括：
- 数据库和 Redis
- 域名和 SSL
- 后端 API 配置
- 外部服务密钥

**无需手动修改 Nginx 配置文件！**

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

### 步骤 2: 配置 SSL 证书

```bash
# 证书文件放在以下位置：
docker/nginx/cert/fullchain.pem
docker/nginx/cert/privkey.pem

# 获取证书参考: nginx/SSL_SETUP.md
```

### 步骤 3: 启动服务

```bash
cd docker
docker-compose --env-file ../backend/.env up -d
```

访问: `https://your-domain.com`

---

## 工作原理

### Nginx 配置自动化

Nginx 使用 `envsubst` 自动从 `.env` 文件读取配置：

**.env 文件**:
```env
DOMAIN=example.com
SSL_CERT_PATH=/etc/nginx/cert/fullchain.pem
SSL_KEY_PATH=/etc/nginx/cert/privkey.pem
```

**Nginx 模板** (`default.conf.template`):
```nginx
server_name ${DOMAIN};  # 自动替换为 example.com
ssl_certificate ${SSL_CERT_PATH};  # 自动替换路径
```

启动时自动替换，无需手动修改！

---

## .env 文件结构

```
.env.example (统一配置模板)
├── 项目配置
│   ├── PROJECT_NAME
│   └── ENVIRONMENT
├── Nginx 配置 ⭐ 新增
│   ├── DOMAIN                  # 域名
│   └── SSL_CERT_PATH           # SSL 证书路径
├── 数据库配置
│   ├── POSTGRES_USER
│   └── POSTGRES_PASSWORD
├── Redis 配置
│   └── REDIS_PASSWORD
├── 后端配置
│   ├── BACKEND_WORKERS
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

**A**: 只需修改 `.env` 中的 `DOMAIN` 变量，重启 Nginx 即可。

```bash
# 编辑 .env
DOMAIN=new-domain.com

# 重启 Nginx
docker-compose restart nginx
```

### Q3: 开发环境需要配置 Nginx 吗?

**A**: 不需要。开发环境使用 `docker-compose.podcast.yml`，直接访问后端端口。

### Q4: SSL 证书路径需要修改吗?

**A**: 不需要。`.env` 中的路径已经是容器内路径，证书放在 `docker/nginx/cert/` 即可。

---

## 配置对比

### 旧方式 (手动配置)

```bash
# 1. 修改 .env
nano .env

# 2. 修改 Nginx 配置
nano nginx/conf.d/default-ssl.conf
# 修改 server_name、证书路径...

# 3. 启用配置
mv default.conf default.conf.bak
mv default-ssl.conf default.conf
```

### 新方式 (只用 .env)

```bash
# 1. 修改 .env (包含域名、SSL路径等)
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

# 3. 放置 SSL 证书
mkdir -p nginx/cert
# 将 fullchain.pem 和 privkey.pem 放到 nginx/cert/

# 4. 启动
docker-compose --env-file ../backend/.env up -d

# 完成！访问 https://api.example.com
```
