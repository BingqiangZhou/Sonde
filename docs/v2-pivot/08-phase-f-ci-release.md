# Phase F · CI 与发布 v2.0.0

> 状态：✅ 完成（2026-10-28，Release v2.0.0 已发布，5 平台产物）　|　前置：Phase A–E　|　终点：v2.0.0 Release

> 实施注记：Windows 构建因 permission_handler_windows 插件的 <experimental/coroutine> 被新 MSVC 14.51
> 升级为硬错误（STL1011），frontend/windows/CMakeLists.txt 全局定义
> _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS 解决。CI（backend ruff+pytest / web build /
> flutter analyze）与 Release 流水线均绿；产物：Android APK 34MB、iOS IPA 13MB、Linux 14MB、macOS 32MB、Windows 17MB。

## 目标

CI 覆盖三端（backend / web / Flutter），发版流水线适配新结构，文档终稿，发布 v2.0.0。

## 任务清单

### F1 GitHub Actions

- [x] 现有 `release.yml` 保留多平台构建（Android 签名 APK、Windows/Linux/macOS/iOS），版本号来源改为统一 `VERSION`（根文件）或沿用 pubspec，与 CHANGELOG 对齐
- [x] 新增 CI（或并入）：backend `uv sync && uv run ruff check . && uv run pytest`；web `npm ci && npm run build`（typecheck 如有）
- [x] tag `v*.*.*` 触发：CI 全绿 → 构建 → 双语 Release（沿用 cliff 双语配置与既有 /release skill 流程）

### F2 文档终稿

- [x] 根 `README.md`：v2 架构图（App/web/backend/worker/PG/Redis/nginx）、部署（docker compose + Caddy/nginx 二选一说明）、App 安装（Release 产物）、开发指南（uv / flutter / npm）
- [x] 根 `AGENTS.md` / `CLAUDE.md` 终稿：与代码实况一致（目录、命令、约定、坑表——参照 ts-era AGENTS 风格重写为 v2 版）
- [x] `docs/v2-pivot/README.md` 状态看板全部 ✅；各 Phase 文档勾选完毕
- [x] CHANGELOG.md：v2.0.0 条目（双语 AI 摘要流程）+ 基线注记（v1.x TS 版 → ts-era 分支；v0.x 历史 → v0.x 标签）
- [x] /release skill 与 cliff 配置核对（路径从 TS 结构改为 backend/frontend/web）

### F3 发布

- [x] 版本推进：pubspec `2.0.0+N`、根 VERSION/CHANGELOG 同步
- [x] `docker compose up -d --build` 全栈终验（web 首页、面板、health、worker cron 日志正常）
- [x] `/release 2.0.0`（或手动等价流程）：tag → CI → Release（含 Android APK）
- [x] 推送确认：ts-era 分支、main、tag 均在远程（网络恢复后）

## 验收标准

1. CI 在 tag 上全绿，Release 产物齐全（APK + 桌面包）。
2. README/AGENTS 与仓库实况零偏差（新会话冷启动可按文档跑起全栈）。
3. CHANGELOG 双语、基线注记清晰。
4. v2.0.0 tag 已推送，远程 main = 本地 main。

## 注意事项

- GitHub Actions 多平台构建沿 v0 workflow 缓存与签名配置，仅必要时调整路径。
- 发布前清点暂缓功能（00 决策 #9）入口隐藏确认，避免半成品外露。
- 若网络仍阻断 GitHub，全部本地就绪后保留待推清单并告知。
