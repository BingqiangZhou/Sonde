# 部署指南

本指南介绍如何部署 Sonde 到生产环境或开发环境。

## 快速开始

### 环境选择

| 场景 | 配置文件 | 用途 |
|------|----------|------|
| 本地开发 | `docker-compose.podcast.yml` | 开发调试，直接访问后端 |
| 生产部署 | `docker-compose.yml` | 生产环境，通过 Nginx 代理 |

### 开发环境 (3 步)

```bash
# 1. 进入 docker 目录
cd docker

# 2. 启动服务 (Windows)
scripts\start.bat

# Linux/Mac
docker compose -f docker-compose.podcast.yml up -d --build
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
OPENAI_API_KEY=your_key
```

#### 步骤 2: 配置 SSL 证书

将证书放到 `docker/nginx/cert/` 目录：
- `fullchain.pem` - 证书链
- `privkey.pem` - 私钥

获取证书参考 [SSL 设置](docker/nginx/SSL_SETUP.md)。

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
├── docker-compose.yml           # 生产环境
├── docker-compose.podcast.yml  # 开发环境
├── .env.example                # 配置模板
├── nginx/                      # Nginx 反向代理
│   ├── cert/                  # SSL 证书
│   ├── conf.d/                # 配置文件
│   └── logs/                  # 日志
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
| 访问方式 | 直接后端 8000 端口 | Nginx 反向代理 |
| 日志级别 | DEBUG | INFO |
| 数据库端口 | 暴露 5432 | 不暴露 |
| Redis 端口 | 暴露 6379 | 不暴露 |
| SSL/HTTPS | 无 | 有 |

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

## SSL 证书配置

### Let's Encrypt (推荐)

```bash
# 安装 certbot
sudo apt install certbot

# 获取证书 (停止 Nginx)
docker-compose stop nginx
sudo certbot certonly --standalone -d your-domain.com
docker-compose start nginx

# 复制证书
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem docker/nginx/cert/
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem docker/nginx/cert/
```

### 自签名证书 (开发)

```bash
cd docker/nginx/cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout privkey.pem -out fullchain.pem \
  -subj "/C=CN/ST=State/L=City/O=Organization/CN=localhost"
```

### 自动续期

```bash
sudo crontab -e
# 添加每天凌晨 2 点检查续期
0 2 * * * certbot renew --quiet --post-hook "cd /path/to/docker && docker-compose exec nginx nginx -s reload"
```

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

### Redis 连接失败

```bash
# 检查 Redis
docker ps | grep redis
docker start redis-podcast
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

1. 修改默认的强密码：JWT_SECRET_KEY、POSTGRES_PASSWORD、REDIS_PASSWORD
2. 使用 HTTPS (必须)
3. 配置防火墙，仅开放必要端口
4. 定期更新 Docker 镜像
5. 设置证书自动续期

---

## 相关文档

- [后端开发指南](backend/README.md)
- [Flutter 开发指南](frontend/README.md)
- [Nginx 配置](docker/nginx/README.md)
- [SSL 设置](docker/nginx/SSL_SETUP.md)
- [认证系统](backend/docs/AUTHENTICATION.md)
