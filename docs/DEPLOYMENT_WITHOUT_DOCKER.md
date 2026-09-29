# 非 Docker（裸机 systemd）部署指南

本指南介绍不使用 Docker、直接在 Linux 服务器（Ubuntu 22.04+/Debian 12 为例）上部署 Sonde 后端的方法，并对比两种方式的内存占用，评估 2GB 内存服务器的可行性。

适用场景：小内存 VPS、无法安装 Docker 的环境、希望减少常驻内存占用的个人部署。

Docker 方案见 [DEPLOYMENT.md](DEPLOYMENT.md) 与 [docker/README.md](../docker/README.md)。

---

## 架构对照

Docker Compose 启动 4 个服务，裸机部署需要自行承载其中每一个：

| Docker 服务 | 裸机对应 | 说明 |
|---|---|---|
| postgres (PostgreSQL 15) | 系统包 postgresql | 数据库 + procrastinate 任务队列存储 |
| backend (uvicorn/gunicorn) | systemd: `sonde-api` | FastAPI API，独占执行 alembic 迁移 |
| worker (procrastinate asyncio worker，TZ=UTC) | systemd: `sonde-worker` | 后台任务（订阅刷新、转写、AI 摘要、日报）兼跑周期调度（cron 在 worker 进程内触发） |
| caddy (Caddy 2) | 系统包 caddy（可选） | 反向代理 + 自动 HTTPS |

每日备份在两种方式下都不属于 Compose 服务，裸机用 cron 实现（见第 11 节）。

---

## 1. 系统要求

| 项目 | 要求 |
|---|---|
| OS | Ubuntu 22.04+ / Debian 12+（x86_64 / arm64） |
| Python | 3.11+ |
| PostgreSQL | 15+ |
| 其他 | ffmpeg（音频转码/分片，转写功能必需）、caddy（可选） |
| 内存 | 最低 1.5GB + 2GB swap；推荐 2GB 及以上 |
| 磁盘 | 10GB+（不含播客音频存储，转写音频会持续增长） |

## 2. 安装系统依赖

```bash
sudo apt update
sudo apt install -y postgresql ffmpeg git curl

# 可选：Caddy 反向代理（官方仓库安装见 caddyserver.com/docs/install）
# 可选：国内源加速可参考 docs/MIRRORS.md
```

PostgreSQL 15 在 Ubuntu 22.04 需加 PGDG 仓库（`apt` 自带的是 14），或直接使用 14+，本项目无 15 独有特性依赖。

安装 uv（Python 包管理器）：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# 国内网络可先: export UV_INDEX_URL=https://mirrors.aliyun.com/pypi/web/simple
```

> 说明：asyncpg/bcrypt/cryptography 等依赖在主流平台均有预编译 wheel，正常无需 build-essential；仅老旧/冷门平台需要。

## 3. 创建运行用户与目录

```bash
sudo useradd --create-home --shell /bin/bash sonde

sudo mkdir -p /opt/sonde
sudo chown sonde:sonde /opt/sonde

# 以 sonde 用户拉取代码
sudo -u sonde git clone <repo-url> /opt/sonde/backend
cd /opt/sonde/backend

# 应用运行所需目录（config.py 默认使用相对路径，相对工作目录）
sudo -u sonde mkdir -p uploads logs data storage/podcasts temp/transcription /opt/sonde/backups
```

## 4. 安装 Python 依赖

```bash
cd /opt/sonde/backend
sudo -u sonde env UV_INDEX_URL=https://mirrors.aliyun.com/pypi/web/simple \
  uv sync --frozen --no-dev
```

产物在 `.venv/`，systemd 直接调用 `.venv/bin/` 下的可执行文件，运行期不依赖 uv。

## 5. 配置环境变量

```bash
cd /opt/sonde/backend
sudo -u sonde cp .env.example .env
sudo -u sonde nano .env
```

必须修改的项：

```bash
ENVIRONMENT=production
API_KEY=<openssl rand -hex 32>          # API 访问鉴权，生产必填
SECRET_KEY=<openssl rand -hex 32>       # 加密已存储的 AI 密钥等，缺失则每次重启随机生成
DATABASE_URL=postgresql+asyncpg://sonde:<密码>@localhost:5432/sonde
WORKER_CONCURRENCY=1                    # 任务 worker 并发数（转写任务较重，默认 1）
ALLOWED_HOSTS=["https://你的域名"]       # 生产必须改为实际域名
```

> **AI 密钥不写入 `.env`**：OpenAI / SiliconFlow 等第三方 key 一律在后台管理面板配置 —— 服务启动后访问 `/api/v1/admin`（用 `API_KEY` 登录），进入 **API Keys** 页面添加模型并填写密钥（加密存储，修改后下一个任务即生效）。

**建议把路径类配置改为绝对路径**（systemd 对工作目录更不敏感）：

```bash
LOG_DIR=/opt/sonde/backend/logs
TRANSCRIPTION_TEMP_DIR=/opt/sonde/backend/temp/transcription
TRANSCRIPTION_STORAGE_DIR=/opt/sonde/backend/storage/podcasts
```

## 6. 配置 PostgreSQL

创建库和用户：

```bash
sudo -u postgres psql <<'SQL'
CREATE USER sonde WITH PASSWORD '改成强密码';
CREATE DATABASE sonde OWNER sonde;
SQL
```

2GB 内存服务器建议在 `/etc/postgresql/15/main/postgresql.conf` 中收紧：

```ini
max_connections = 30          # API 池 5+溢出 10 + worker，远用不满 100
shared_buffers = 128MB
effective_cache_size = 512MB
work_mem = 4MB
maintenance_work_mem = 64MB
```

```bash
sudo systemctl restart postgresql
```

## 7. 执行数据库迁移

对应 Docker 版 `RUN_MIGRATIONS=1` 的行为。**首次启动前和每次升级代码后**，先停服务再执行：

```bash
cd /opt/sonde/backend
sudo -u sonde .venv/bin/alembic upgrade head
```

> alembic 的 `env.py` 会从工作目录自动读取 `.env`（同 pydantic-settings），因此必须先 `cd` 到 backend 目录。
> 迁移由人工（或部署脚本）单点执行，避免 API 与 worker 并发跑 alembic —— 这正是 Docker 版让 backend 容器独占迁移的原因。

## 8. 初始化任务队列 schema（procrastinate）

任务队列由 procrastinate（Postgres 原生队列）承载，无需 Redis 等额外中间件。**首次部署在数据库迁移之后**应用一次其 schema（幂等，可重复执行）：

```bash
cd /opt/sonde/backend
sudo -u sonde .venv/bin/python -m procrastinate -a app.core.jobs.procrastinate_app schema --apply
```

（Docker 版由 backend 容器入口在 `alembic upgrade head` 之后自动执行同一命令。）

## 9. systemd 服务

### `/etc/systemd/system/sonde-api.service`

```ini
[Unit]
Description=Sonde backend API (uvicorn)
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=sonde
Group=sonde
WorkingDirectory=/opt/sonde/backend
Environment=PYTHONUTF8=1 TZ=Asia/Shanghai
ExecStart=/opt/sonde/backend/.venv/bin/uvicorn app.main:app \
    --host 127.0.0.1 --port 8000 \
    --timeout-keep-alive 60 --proxy-headers --forwarded-allow-ips='*'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

> 监听 `127.0.0.1`，由 Caddy 代理对外；若不用 Caddy 需改成 `0.0.0.0` 并自行处理 TLS。

### `/etc/systemd/system/sonde-worker.service`

```ini
[Unit]
Description=Sonde procrastinate worker (jobs + periodic cron deferral)
After=network-online.target postgresql.service sonde-api.service
Wants=network-online.target

[Service]
Type=simple
User=sonde
Group=sonde
WorkingDirectory=/opt/sonde/backend
# TZ 必须为 UTC：procrastinate 的 cron 表达式按进程本地时区求值，
# 固定 UTC 才能与原 Celery beat 的 UTC 调度时刻保持一致
Environment=PYTHONUTF8=1 TZ=UTC WORKER_CONCURRENCY=1
ExecStart=/opt/sonde/backend/.venv/bin/python -m app.bootstrap.worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

> 周期调度（feed 刷新、待处理摘要、缓存清理、日报）由 worker 进程内 cron 触发，**无需独立的 beat 单元**。并发数用 `WORKER_CONCURRENCY` 控制（默认 1）。

### 启动

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sonde-api sonde-worker
sudo systemctl status sonde-api sonde-worker
```

## 10. Caddy 反向代理（可选但推荐）

`/etc/caddy/Caddyfile`（要点从 `docker/caddy/Caddyfile` 移植；Caddy 默认流式转发响应，无需针对流式接口单独关闭缓冲）：

```caddyfile
你的域名 {
    tls internal

    encode zstd gzip

    request_body {
        max_size 20MB
    }

    reverse_proxy 127.0.0.1:8000
}
```

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

公网域名下可切换为 ACME 自动证书（`tls 你的邮箱`）；本机/内网自用保持 `tls internal`（内置 CA）。TLS 模式与根证书信任见 [docker/caddy/README.md](../docker/caddy/README.md)。

## 11. 每日备份（cron）

`sudo crontab -e` 添加（保留 7 天）：

```cron
10 4 * * * sudo -u postgres pg_dump -Fc -f /opt/sonde/backups/db_$(date +\%Y\%m\%d).dump sonde && find /opt/sonde/backups -name 'db_*.dump' -mtime +7 -delete
```

## 12. 验证部署

```bash
curl http://localhost:8000/api/v1/health        # {"status":"healthy"}
curl http://localhost:8000/api/v1/health/ready  # 就绪检查（数据库）
# API 文档: http://localhost:8000/api/v1/docs（生产走域名 + HTTPS）

journalctl -u sonde-api -f          # API 日志
journalctl -u sonde-worker -f       # worker 日志（RSS 刷新、转写、摘要都在这里）
```

功能验证：添加一个播客订阅 → 手动/等待刷新 → 触发一期转写与摘要，确认 `storage/podcasts/`、`temp/transcription/` 有文件产生且 `journalctl` 无报错。

## 13. 升级流程

```bash
sudo systemctl stop sonde-worker sonde-api
cd /opt/sonde/backend && sudo -u sonde git pull
sudo -u sonde env UV_INDEX_URL=https://mirrors.aliyun.com/pypi/web/simple uv sync --frozen --no-dev
sudo -u sonde .venv/bin/alembic upgrade head
sudo -u sonde .venv/bin/python -m procrastinate -a app.core.jobs.procrastinate_app schema --apply
sudo systemctl start sonde-api sonde-worker
```

---

## 内存占用对比：Docker vs 裸机

容器不是虚拟机：同一个 PostgreSQL/Python 进程在容器内外内存基本相同。**差异主要来自 Docker 守护进程本身**；任务队列改为 Postgres 原生的 procrastinate 后，Redis 与独立 beat 进程均已移除，两种部署方式的进程集合一致。

以下为个人使用规模（几个订阅、每天几十期转写）下的稳态 RSS 经验估算：

| 组件 | Docker 部署 | 裸机部署 |
|---|---:|---:|
| dockerd + containerd | 120–250 MB | — |
| PostgreSQL 15（数据 + 任务队列） | 150–250 MB | 150–250 MB（相同配置） |
| Backend API（uvicorn/gunicorn） | 150–250 MB | 150–250 MB |
| worker（procrastinate asyncio，含周期调度） | 150–300 MB | 150–300 MB |
| Caddy | 10–20 MB | 10–20 MB |
| 每日备份 cron | 0 常驻（pg_dump 短时 +50–100 MB） | 0 常驻（cron 瞬时） |
| 操作系统（最小安装） | 150–250 MB | 150–250 MB |
| **稳态合计** | **约 0.6–1.3 GB** | **约 0.5–1.0 GB** |

**结论：两种方式相差约 120–250 MB（主要就是 dockerd/containerd 常驻开销）。** 除此之外各进程内存相同，不会有数量级差别。

另外两点顺带收益：裸机省去约 1–1.5 GB 磁盘镜像；少了容器层，`journalctl` 直接看日志。代价是需要自己维护 systemd 单元、升级脚本和依赖版本一致性（Docker 版由镜像锁死）。

### 峰值场景（两种部署方式相同）

- **转写任务**：ffmpeg 子进程每次约 +100–300 MB，且 `TRANSCRIPTION_MAX_THREADS` 默认为 4（最多 4 个并发转写管线，含音频分片缓冲）；
- **每日备份**：pg_dump 短时 +50–100 MB；
- **AI 摘要批量生成**：worker 内存短时上涨。

---

## 2GB 内存服务器能否正常运行？

**可以，两种方式都可以；裸机更宽裕。** 按上表，稳态占用约 0.6–1.3 GB（Docker）或 0.5–1.0 GB（裸机），2GB 有余量覆盖转写峰值的短时上涨。建议照以下清单收紧：

1. **务必加 2GB swap**（转写 + 备份叠加的瞬时峰值安全网）：

   ```bash
   sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
   sudo mkswap /swapfile && sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   sudo sysctl -w vm.swappiness=10
   ```

2. **`TRANSCRIPTION_MAX_THREADS=1`（最多 2）** —— 这是 2GB 机器上最关键的一项，默认 4 个并发 ffmpeg 容易在转写积压清空时把内存打满；
3. PostgreSQL：`max_connections=30`、`shared_buffers=128MB`（见第 6 节）；
4. worker 并发 `WORKER_CONCURRENCY=1`（Docker 版默认已是）；
5. 保持 `DATABASE_POOL_SIZE=5` / `DATABASE_MAX_OVERFLOW=10` 默认值即可，不要调大。

不建议低于 2GB：1GB 机器即使裸机 + 全部调优，转写峰值也很容易触发 OOM killer（通常先杀 worker）。

---

## 常见问题

**Q：服务起不来，报数据库连接失败？**
先确认 `postgresql` 处于 active 状态，再核对 `.env` 中 `DATABASE_URL` 的密码与第 6 节设置一致；`journalctl -u sonde-api -n 50` 看具体报错。

**Q：worker 日志里任务一直不执行？**
检查 `sonde-worker` 是否运行、`journalctl -u sonde-worker` 有无数据库连接报错，并确认第 8 节的 procrastinate schema 已应用；周期任务由 worker 进程内 cron 触发，worker 的 `TZ` 必须为 `UTC` 才能按预期时刻运行。

**Q：转写没有产物？**
确认系统 `ffmpeg -version` 可用；转写依赖外部 API（密钥在后台管理面板 `/api/v1/admin/apikeys` 配置），本地只做下载、转码与分片。

---

## 相关文档

- [Docker 部署指南](DEPLOYMENT.md)
- [docker/README.md](../docker/README.md)
- [国内镜像源说明](MIRRORS.md)
- [Caddy 配置](../docker/caddy/README.md)
