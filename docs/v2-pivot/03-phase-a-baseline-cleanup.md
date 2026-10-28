# Phase A · 基线收尾

> 状态：✅ 完成（2026-10-28）　|　前置：Phase 0（已完成）　|　下一步：Phase B

## 目标

v0 基线在本机完全跑通并打扫干净，迁入 web/ 与 industry 两块 ts-era 资产，统一品牌为声读 Sonde。本阶段**不引入任何新功能**。

## 任务清单

### A1 验证基线

- [x] `cd backend && uv run ruff check .` 通过（必要时最小修复）
- [x] `uv run pytest -q` 通过（记录基线失败项，若为历史遗留问题记录于本文"注意事项"而非大改）
- [x] 停掉并清理 TS 旧容器：`docker compose -p sonde down`（或 `docker stop sonde-web-1 sonde-api-1 sonde-worker-1 sonde-db-1` + 删除）
- [x] 用 `docker/docker-compose.yml` 起 v0 栈（postgres/redis/backend/celery/nginx），`curl /api/v1/health` 绿
- [x] alembic 从零建库验证（`docker compose down -v` 后重起，entrypoint 自动迁移成功；head=f5b233bd4e12）
- [x] `cd frontend && flutter pub get && flutter analyze` 通过（记录基线警告数）

### A2 清理问题清单（01 文档 §4）

- [x] 删除根目录 `.env`（TS 遗留；backend 用 `backend/.env`）
- [x] 删除 `scripts/dev/` 垃圾目录、`scripts/test_auth_api.sh`（过期）
- [x] `TRANSCRIPTION_BACKLOG_SCHEDULE_MINUTE` 死配置：从 `core/config.py` 移除并全库搜索引用
- [x] `backend/docs/AUTHENTICATION.md` 头部加状态注记："该系统已被删除，Phase B 按此契约恢复"

### A3 品牌统一（不改代码结构）

- [x] 根 `README.md` 重写：声读 Sonde v2（Python+Flutter 多端播客知识库）、架构图、快速开始（uv/docker/flutter）
- [x] 根 `AGENTS.md` / `CLAUDE.md` 重写为 v2 实况（v0 版描述的是单用户旧态）：目录结构、命令、约定、指向 docs/v2-pivot/
- [x] frontend 仅改用户可见品牌：应用显示名（Android label / iOS CFBundleDisplayName / 桌面窗口标题 "Stella"→"声读 Sonde"）；**Dart 包名 `personal_ai_assistant` 不动**
- [x] `docker/docker-compose.yml` 项目名/容器名如含旧名一并改（sonde）
- [x] CHANGELOG.md 顶部加基线注记：v2 转向说明，v1.x 历史在 ts-era 分支

### A4 迁入 ts-era 资产

- [x] `git checkout ts-era -- apps/web` → 移至 `web/`：解 workspace 耦合（独立 package.json、去掉对根 tsconfig/包的依赖，必要时内联少量共享代码）；`npm install && npm run build` 通过
- [x] web 的 API 基址改为环境变量（指向 backend；Phase D 才真正接 /api/v1/site/*，本阶段保持可构建即可，页面允许暂时无数据）
- [x] `git checkout ts-era -- industry/prompts` → `backend/app/industry/prompts/`（原样迁入全部 .md）
- [x] 新建 `backend/app/industry/{__init__.py,site.py,taxonomy.py,selection.py}`：内容自 ts-era `industry/*.ts` 翻译为 Python 常量（站点信息、分类有序表、T1/T2 门槛、兴趣画像、`threshold_for(tier)`）；不接业务，仅可导入（Phase C 使用）
- [x] `.gitignore` 补 web/node_modules 等

### A5 提交与推送

- [x] 按任务组分 Conventional Commits（`chore: ...` / `docs: ...` / `feat(web): ...` 等）
- [ ] 网络恢复时执行推送待办（00 文档 §3），并更新 README 状态看板

## 验收标准

1. v0 docker 栈健康检查绿，alembic 可从零建库。
2. ruff / pytest / flutter analyze 达到或优于基线记录。
3. `web/` 独立构建成功；`backend/app/industry/` 可导入且 prompt 文件齐全。
4. 仓库内无过期文档/垃圾文件；品牌统一为声读 Sonde。

## 注意事项

- pytest 基线若有历史失败，逐条记录原因，只修与转向相关的，不展开大修。
- web 解耦时若依赖根级 TS 包（如共享类型），优先复制内联，避免为 web 维护第二个包。
- frontend 平台目录六套（android…linux），改显示名时逐平台核对，不动包名/签名配置。
- **本机网络实测（2026-10-28）**：Docker 构建直连 Debian/PyPI 不稳定；tuna 镜像在代理环境下反而 403/无版本。
  对策（已落地）：`backend/Dockerfile` 的 apt 源（`APT_MIRROR`）与 PyPI 索引（`PYPI_INDEX`）均改为可配置、默认官方；
  `docker/.env` 设 `BUILD_HTTP_PROXY=http://host.docker.internal:7897` 走宿主代理构建。
  本地 uv 若配置了阿里云镜像会重写 uv.lock 的 URL——仓库保持 pypi.org 官方锁，本地操作一律 `uv sync --frozen`。
