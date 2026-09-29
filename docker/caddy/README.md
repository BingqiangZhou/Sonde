# Caddy 反向代理

Caddy 替代了原先的 nginx 容器，作为 Sonde 的唯一入口（HTTP/80 + HTTPS/443 → `backend:8000`）。

## 目录结构

```
docker/caddy/
├── Caddyfile      # 站点配置（环境变量占位符由容器环境注入）
└── README.md
```

证书与 ACME 账户持久化在 `sonde_caddy_data` 卷中，配置缓存位于 `sonde_caddy_config` 卷。

## TLS 模式（默认：tls internal）

默认 `tls internal`：Caddy 内置 CA 为站点自动签发本地证书，零配置、零续期。
适合本机 / 内网自用部署（local-first）。

### 信任 Caddy 根证书（首次访问 HTTPS 报"不受信任"时）

1. 从容器导出根证书：
   ```bash
   docker compose exec caddy cat /data/caddy/pki/authorities/local/root.crt > sonde-root-ca.crt
   ```
2. 导入到操作系统 / 浏览器：
   - Windows：双击证书 → 安装到"受信任的根证书颁发机构"
   - macOS：钥匙串访问 → 导入 → 始终信任
   - Android（App 内访问可跳过）：设置 → 安全 → 加密与凭据 → 安装证书

### 内网 IP 访问

`DOMAIN` 默认 `localhost`，仅匹配 `localhost` 主机名。用内网 IP / 主机名访问时，
在 `docker/.env` 设置 `DOMAIN=192.168.x.x`（或主机名）后 `docker compose up -d caddy`，
Caddy 会为该地址签发内部证书。

## 切换到 ACME 自动证书（公网域名）

需要公网域名解析到本机且 80/443 可达：

1. `docker/.env` 设置 `DOMAIN=your-domain.com`、`ACME_EMAIL=you@example.com`
2. 编辑 `Caddyfile`，把 `tls internal` 改为 `tls {$ACME_EMAIL}`
3. `docker compose up -d caddy`

Caddy 自动从 Let's Encrypt 申请并续期证书，无需任何手动操作。
建议同时在站点块 `header` 中追加 `Strict-Transport-Security "max-age=31536000; includeSubDomains"`。

## 切换到手动证书（沿用 certbot 流程）

1. 挂载证书目录（在 docker-compose.yml 的 caddy 服务 volumes 追加）：
   ```yaml
   - ./caddy/cert:/etc/caddy/cert:ro
   ```
2. `Caddyfile` 中把 `tls internal` 改为：
   ```
   tls /etc/caddy/cert/fullchain.pem /etc/caddy/cert/privkey.pem
   ```
3. `docker compose up -d caddy`；续期后执行 `docker compose exec caddy caddy reload`

## 运维命令

```bash
# 校验配置
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# 修改 Caddyfile 后热加载（不中断连接）
docker compose exec caddy caddy reload

# 查看访问日志（stdout，由 docker json-file 驱动轮转）
docker compose logs -f caddy
```

## 与原 nginx 配置的差异

| 原 nginx 行为 | 现状 |
|---------------|------|
| `^/api/v1/.*/stream` 关闭缓冲、长超时 | 对应路由已随 playback 功能移除；Caddy 反代默认即流式透传，未来流式端点无需特殊配置 |
| `/static/` 30 天缓存 | 后端已无静态文件路由，不移植 |
| `/api/v1/auth/*` 登录限流 5r/m | JWT 认证端点已移除；后端自带 slowapi 60/min 内存限流 |
| WebSocket upgrade 头 | Caddy 自动处理 |
| 手动证书 + envsubst 模板 | tls internal 默认零配置；ACME / 手动证书见上文 |
