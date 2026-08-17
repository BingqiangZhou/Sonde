# Docker 部署目录

个人 AI 助手的 Docker 部署配置。

5 个服务：postgres (PostgreSQL 15)、redis (Redis 7)、backend (FastAPI)、celery_worker (异步任务 + 内嵌 beat)、nginx (反向代理 + SSL)。

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

### SSL 证书（生产环境）

将 SSL 证书放到 `docker/nginx/cert/` 目录：
- `fullchain.pem` - 证书链
- `privkey.pem` - 私键

---

## 目录结构

```
docker/
├── docker-compose.yml          # Docker Compose 配置
├── .env.example                # 环境配置模板
├── .env                        # 实际环境配置
├── nginx/                      # Nginx 配置
│   ├── nginx.conf
│   ├── conf.d/
│   │   └── default.conf.template  # HTTPS 模板
│   ├── cert/                      # SSL 证书目录
│   ├── logs/                      # Nginx 日志
│   ├── README.md
│   └── SSL_SETUP.md
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

# 3. 就绪检查（含数据库和 Redis）
curl http://localhost:8000/api/v1/health/ready

# 4. 访问 API 文档
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
docker compose exec postgres psql -U admin -d personal_ai
```

### Nginx 管理

```bash
# 测试配置
docker compose exec nginx nginx -t

# 重新加载配置
docker compose exec nginx nginx -s reload

# 查看 Nginx 日志
tail -f nginx/logs/access.log
tail -f nginx/logs/error.log
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
- [ ] 服务启动: `docker compose ps` 显示 5 个服务 **Up**
- [ ] 健康检查: `curl http://localhost:8000/api/v1/health` 返回健康
- [ ] API 文档可访问: `http://localhost:8000/api/v1/docs` 正常显示
- [ ] 功能测试: 能添加播客订阅

### 生产环境额外检查

- [ ] 配置 SSL 证书到 `docker/nginx/cert/`
- [ ] Nginx 配置测试通过
- [ ] HTTPS 访问正常

---

## 相关文档

- **部署指南**: [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md)
- **Nginx 配置**: [nginx/README.md](nginx/README.md)
- **SSL 配置**: [nginx/SSL_SETUP.md](nginx/SSL_SETUP.md)
