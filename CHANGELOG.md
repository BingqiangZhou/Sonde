# Changelog

All notable changes to this project will be documented in this file.



## [1.0.0](https://github.com/BingqiangZhou/Sonde/compare/...v1.0.0) - 2026-09-29 ([📥](https://github.com/BingqiangZhou/Sonde/releases/tag/v1.0.0))

> v1.0.0 是声读的全面重写版：从 Python/Flutter 迁移到 Node 24 + TypeScript monorepo（Fastify + pg-boss + React Router 7 SSR + Tailwind），完整实现播客 RSS 采集、六步音频转写流水线、按分级门槛的 AI 评分筛选、每天 08:00（北京时间）自动成刊的中文日报，以及报刊风阅读站与后台控制台；同时彻底清除了旧栈的代码、文档与历史遗留。
>
> Sonde v1.0.0 is a ground-up rewrite: the personal podcast daily-digest site now runs on a Node 24 TypeScript monorepo (Fastify + pg-boss + React Router 7 SSR + Tailwind), delivering RSS collection, a six-step audio transcription pipeline, tier-thresholded AI scoring, a Chinese daily report auto-composed at 08:00 Beijing time, a newspaper-style reading site, and an admin console — with the legacy Python/Flutter stack fully purged.
>
> 共 13 commits：🚀 Features 7 | ⚙️ Miscellaneous Tasks 3 | 🐛 Bug Fixes 1 | 📚 Documentation 1 | 🚜 Refactor 1

### ⚙️ Miscellaneous Tasks

- Purge obsolete docs, dead code and unused deps ([6b03a41](https://github.com/BingqiangZhou/Sonde/commit/6b03a4153ac6c98552f02356cb46dab1f7ed9349))
- Finish Flutter/Python purge — rewrite history, clean disk leftovers ([d0cc106](https://github.com/BingqiangZhou/Sonde/commit/d0cc106bba15112876dcec56b8b644e6ed0acf40))
- Reset CHANGELOG to v1.0 baseline, update release skill for TS stack ([5b40b53](https://github.com/BingqiangZhou/Sonde/commit/5b40b5386bf0a68a1c752681d7ad48b7731b9232))

### 🐛 Bug Fixes

- *(web)* Serve static assets in custom server and redesign the UI ([f645565](https://github.com/BingqiangZhou/Sonde/commit/f645565da60afdb68c95f1ca813ec68b3c9a6510))

### 📚 Documentation

- Mark TS rewrite v1 complete, add mock-dev guide to README ([c7b2551](https://github.com/BingqiangZhou/Sonde/commit/c7b2551f790f4242e79233c1a015b139e2391a27))

### 🚀 Features

- *(scaffold)* TS monorepo skeleton — api/worker/web, pg-boss queues, SQL migration, Docker Compose ([d7a2d9c](https://github.com/BingqiangZhou/Sonde/commit/d7a2d9c6920a683ea3746862bb4a823204d50c4c))
- *(core)* LLM/transcription providers with receipts, prompt renderer, tz & json utils ([477cd36](https://github.com/BingqiangZhou/Sonde/commit/477cd3659d22a409bfe924da492e07ec1199e318))
- *(pipeline)* RSS source fetch + six-step transcription pipeline ([2f11546](https://github.com/BingqiangZhou/Sonde/commit/2f11546de6ee1803a208fe0b6d4b033575e67ee1))
- *(analyze+report)* Scoring/writing pipeline and daily report composition ([0926761](https://github.com/BingqiangZhou/Sonde/commit/09267610fe88a9147100df59e8274e7a5004e2dd))
- *(site)* Reading site — home/daily/episode/archive pages + site read API ([641b756](https://github.com/BingqiangZhou/Sonde/commit/641b75619d3e28eee2fbf10621712358d695112a))
- *(admin)* Admin console — sources CRUD, episode diagnostics, reports, costs ([28f75a2](https://github.com/BingqiangZhou/Sonde/commit/28f75a2695495dab7f7bd748b30d56736badbb50))
- *(web)* Switch to AIHOT-style left sidebar layout ([d8366b1](https://github.com/BingqiangZhou/Sonde/commit/d8366b13cd4d11dcf4b73f11792b69d87b634122))

### 🚜 Refactor

- Remove Python backend, Flutter app and old docker/CI for TS rewrite ([c5636cb](https://github.com/BingqiangZhou/Sonde/commit/c5636cbc2ca7eddba567ab436a0bb10fb42ab343))

> 基线说明：v1.0.0 起为 TS 重写版（声读 Sonde 播客日报站，Node/React 架构）。
> v0.x（Python/Flutter 时代）的发版历史见远程仓库的 v0.x 标签与 `git log`。
