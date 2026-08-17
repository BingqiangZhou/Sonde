# Nginx 反向代理配置说明 / Nginx Reverse Proxy Configuration

## 概述 / Overview

本 Nginx 配置仅用于**生产环境**，提供以下功能：

This Nginx configuration is for **production environment only**, providing:

- **反向代理** / Reverse Proxy: 将外部请求转发到 FastAPI 后端
- **负载均衡** / Load Balancing: 支持多实例负载均衡
- **SSL/TLS 终止** / SSL/TLS Termination: 处理 HTTPS 加密
- **静态文件服务** / Static Files: 高效提供静态资源
- **安全增强** / Security Enhancement: 添加安全头和防护
- **请求日志** / Request Logging: 记录所有访问日志

> **注意**: 开发环境不需要 Nginx，直接访问后端端口即可。
>
> **Note**: Development environment doesn't need Nginx, access backend directly.

---

## 目录结构 / Directory Structure

```
docker/nginx/
├── nginx.conf              # Nginx 主配置文件
├── conf.d/
│   ├── default.conf        # HTTP 配置 (测试用)
│   └── default-ssl.conf    # HTTPS 配置 (生产环境)
├── cert/                   # SSL 证书目录
│   ├── fullchain.pem       # 证书链
│   └── privkey.pem         # 私钥
├── logs/                   # Nginx 日志目录
├── SSL_SETUP.md            # SSL 证书配置指南
└── README.md               # 本文档
```

---

## 快速开始 / Quick Start

### 生产环境部署 (HTTPS)

```bash
# 1. 配置环境变量
cd docker
cp .env.example .env
nano .env  # 修改密码和密钥

# 2. 配置 SSL 证书（参考 SSL_SETUP.md）
# 证书文件放在: docker/nginx/cert/

# 3. 启用 HTTPS 配置
cd nginx/conf.d
mv default.conf default.conf.bak
mv default-ssl.conf default.conf

# 4. 修改配置中的域名
nano default.conf  # 修改 server_name

# 5. 启动生产环境
cd ../..
docker-compose --env-file .env up -d

# 6. 验证
curl https://your-domain.com/api/v1/health
```

---

## 配置说明 / Configuration Details

### 主配置文件 (nginx.conf)

主要配置项：

```nginx
user nginx;                           # 运行用户
worker_processes auto;                # 工作进程数（自动）
worker_connections 1024;              # 每个进程的最大连接数
keepalive_timeout 65;                 # 保持连接超时
client_max_body_size 100M;            # 最大上传文件大小
```

### 站点配置 (conf.d/*.conf)

#### HTTP 配置 (default.conf)

- 监听端口：80
- 适用于：开发环境
- 无需SSL证书

#### HTTPS 配置 (default-ssl.conf)

- 监听端口：443
- 适用于：生产环境
- 需要SSL证书
- 自动HTTP到HTTPS重定向

---

## 常用命令 / Common Commands

### 启动和停止

```bash
# 启动所有服务
docker-compose --env-file .env up -d

# 只启动 Nginx
docker-compose --env-file .env up -d nginx

# 停止 Nginx
docker-compose stop nginx

# 重启 Nginx
docker-compose restart nginx

# 查看状态
docker-compose ps nginx
```

### 配置管理

```bash
# 测试 Nginx 配置
docker-compose exec nginx nginx -t

# 重新加载配置（无需重启）
docker-compose exec nginx nginx -s reload

# 查看完整配置
docker-compose exec nginx nginx -T
```

### 日志查看

```bash
# 查看 Nginx 日志
docker-compose logs -f nginx

# 查看访问日志
tail -f docker/nginx/logs/access.log

# 查看错误日志
tail -f docker/nginx/logs/error.log

# 查看后端访问日志
tail -f docker/nginx/logs/backend.access.log
```

---

## 配置自定义 / Customization

### 修改代理路径

如果需要修改API路径，编辑 `conf.d/*.conf`:

```nginx
location /api/ {
    proxy_pass http://fastapi_backend/;
}
```

### 添加新的域名

编辑配置文件中的 `server_name`:

```nginx
server_name example.com www.example.com;
```

### 配置负载均衡

如果运行多个后端实例，修改upstream配置：

```nginx
upstream fastapi_backend {
    server backend1:8000 weight=3;
    server backend2:8000 weight=2;
    server backend3:8000 backup;
    keepalive 32;
}
```

### 添加缓存配置

```nginx
# 添加到 http 块
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g;

# 添加到 location 块
location / {
    proxy_cache my_cache;
    proxy_cache_valid 200 60m;
    proxy_pass http://fastapi_backend;
}
```

---

## 性能优化 / Performance Optimization

### 1. 启用 Gzip 压缩

已在 `nginx.conf` 中配置：

```nginx
gzip on;
gzip_comp_level 6;
gzip_types text/plain application/json;
```

### 2. 调整工作进程

```nginx
worker_processes auto;  # 根据 CPU 核心数自动调整
worker_connections 2048;  # 增加连接数
```

### 3. 启用 Keep-Alive

```nginx
keepalive_timeout 65;
keepalive_requests 100;
```

### 4. 优化缓冲区

```nginx
client_body_buffer_size 10M;
client_max_body_size 100M;
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
```

---

## 安全配置 / Security Configuration

### 已实现的安全措施

1. **隐藏版本号**: `server_tokens off;`
2. **安全头**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
3. **SSL/TLS**: 仅支持 TLSv1.2 和 TLSv1.3
4. **HSTS**: 强制 HTTPS (生产环境)
5. **请求大小限制**: 防止大文件攻击

### 额外安全建议

```nginx
# 限制请求速率
limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
limit_req zone=one burst=20 nodelay;

# IP 白名单
allow 192.168.1.0/24;
deny all;

# 禁止访问隐藏文件
location ~ /\. {
    deny all;
}
```

---

## 故障排查 / Troubleshooting

### 1. 502 Bad Gateway

**原因**: 后端服务不可用

**解决**:
```bash
# 检查后端服务状态
docker-compose ps backend

# 查看后端日志
docker-compose logs backend
```

### 2. 504 Gateway Timeout

**原因**: 后端响应超时

**解决**: 增加超时时间
```nginx
proxy_read_timeout 300s;
proxy_connect_timeout 75s;
```

### 3. 404 Not Found

**原因**: 路径配置错误

**解决**: 检查 `location` 配置是否正确

### 4. SSL 证书错误

**原因**: 证书路径或权限错误

**解决**:
```bash
# 检查证书文件
ls -la docker/nginx/cert/

# 修正权限
chmod 600 docker/nginx/cert/privkey.pem
chmod 644 docker/nginx/cert/fullchain.pem
```

---

## 监控和日志 / Monitoring and Logging

### 日志分析

```bash
# 统计访问量
awk '{print $1}' docker/nginx/logs/access.log | sort | uniq -c | sort -nr | head -10

# 统计状态码
awk '{print $9}' docker/nginx/logs/access.log | sort | uniq -c | sort -nr

# 查找错误请求
grep " 5" docker/nginx/logs/access.log
```

### 性能监控

```bash
# 监控连接数
docker-compose exec nginx nginx -s status

# 实时监控
watch -n 1 'docker-compose exec nginx nginx -s status'
```

---

## 生产环境检查清单 / Production Checklist

- [ ] 配置 SSL 证书
- [ ] 启用 HTTPS 配置
- [ ] 修改 `server_name` 为实际域名
- [ ] 设置日志轮转
- [ ] 配置证书自动续期
- [ ] 测试配置：`nginx -t`
- [ ] 检查安全头：`curl -I https://your-domain.com`
- [ ] SSL 测试：https://www.ssllabs.com/ssltest/
- [ ] 防火墙配置：开放 80 和 443 端口
- [ ] 监控配置：设置日志分析和告警

---

## 参考 / References

- [Nginx 官方文档](http://nginx.org/en/docs/)
- [Mozilla SSL 配置生成器](https://ssl-config.mozilla.org/)
- [FastAPI 生产部署](https://fastapi.tiangolo.com/deployment/)
- [Docker 网络配置](https://docs.docker.com/network/)
