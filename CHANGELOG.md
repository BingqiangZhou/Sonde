# Changelog

All notable changes to this project will be documented in this file.



## [1.1.0](https://github.com/BingqiangZhou/Sonde/compare/v1.0.1...v1.1.0) - 2026-09-29 ([📥](https://github.com/BingqiangZhou/Sonde/releases/tag/v1.1.0))

> v1.1.0 将 Web 端升级到 React Router 8.4.0，并新增「全部动态」页（/all）：所有完成评分的单集（含未过门槛者）统一在此浏览——入选条目链接到单集详情，未入选条目展示灰色评分与筛选理由；同时补齐 GitHub Actions CI 与推送 v* 标签后自动验证并创建 GitHub Release 的发版流水线，并修复了全新 checkout 上 server.ts 因引用构建产物导致 typecheck 失败的问题。
>
> Sonde v1.1.0 upgrades the web app to React Router 8.4.0 and adds the "All Episodes" feed (/all): every scored episode, including those below the selection threshold, is listed in one place — selected items link to the episode detail page while unselected ones show their gray score and the reason they were filtered out. This release also adds GitHub Actions CI and a release pipeline that verifies the build and publishes the GitHub Release automatically when a v* tag is pushed, plus a fix so typecheck passes on a fresh checkout without build artifacts.
>
> 共 3 commits：🚀 Features 1 | ⚙️ Miscellaneous Tasks 1 | 🐛 Bug Fixes 1

### ⚙️ Miscellaneous Tasks

- *(ci)* Add GitHub Actions CI and tag-triggered release workflow ([410e7c1](https://github.com/BingqiangZhou/Sonde/commit/410e7c1da84ac6c057930d9329ee333dbc9ea10b))

### 🚀 Features

- *(web)* Upgrade to React Router 8 and add /all feed (全部动态) ([8599b4f](https://github.com/BingqiangZhou/Sonde/commit/8599b4f082f95cf22f627092360376ca18caf8f0))

### 🐛 Bug Fixes

- *(web)* Typecheck on fresh checkout without build artifacts ([90880f1](https://github.com/BingqiangZhou/Sonde/commit/90880f10b28c1b59772bc69d11e5e45e58eb8d55))



## [1.0.1](https://github.com/BingqiangZhou/Sonde/compare/v0.53.0...v1.0.1) - 2026-09-29 ([📥](https://github.com/BingqiangZhou/Sonde/releases/tag/v1.0.1))

> v1.0.1 是声读的全面重写首发版：从 Python/Flutter 迁移到 Node 24 + TypeScript monorepo（Fastify + pg-boss + React Router 7 SSR + Tailwind），完整实现播客 RSS 采集、六步音频转写流水线、按分级门槛的 AI 评分筛选、每天 08:00（北京时间）自动成刊的中文日报，以及报刊风阅读站与后台控制台；同时彻底清除了旧栈的代码、文档与历史遗留。
>
> Sonde v1.0.1 is the debut release of the ground-up rewrite: the personal podcast daily-digest site now runs on a Node 24 TypeScript monorepo (Fastify + pg-boss + React Router 7 SSR + Tailwind), delivering RSS collection, a six-step audio transcription pipeline, tier-thresholded AI scoring, a Chinese daily report auto-composed at 08:00 Beijing time, a newspaper-style reading site, and an admin console — with the legacy Python/Flutter stack fully purged.
>
> 共 13 commits：🚀 Features 7 | ⚙️ Miscellaneous Tasks 3 | 🐛 Bug Fixes 1 | 📚 Documentation 1 | 🚜 Refactor 1

### ⚙️ Miscellaneous Tasks

- *(release)* Add bilingual AI summary to changelog pipeline ([d728f69](https://github.com/BingqiangZhou/Sonde/commit/d728f6907bbbce51943f3039b33d14af6a0750fa))
- *(backend)* Harden celery reliability, auth security and deployment ([157c4a6](https://github.com/BingqiangZhou/Sonde/commit/157c4a6ddd2b186a722e7f1748f5821cc5b7712d))
- *(backend)* Sweep cross-cutting hygiene debt ([76192fa](https://github.com/BingqiangZhou/Sonde/commit/76192fad312cbe42c078e9baf355b0fccd237a46))
- *(docker)* Rebrand the compose stack to sonde and restructure it ([d4dae3e](https://github.com/BingqiangZhou/Sonde/commit/d4dae3e49594efa0a94629d61768ca2c376b8d34))
- *(docker)* Drop the postgres backup sidecar ([acea708](https://github.com/BingqiangZhou/Sonde/commit/acea708a573de36c761a6980f032b4f836a6fc99))
- *(backend)* Drop stale Dockerfile.cn, broken quickstart doc, and dead mypy config ([24edbd1](https://github.com/BingqiangZhou/Sonde/commit/24edbd120d4b3dafea9eae18ea9d34c2a4f2d09b))
- *(backend)* Drop unused openapi-diff script and exception-handling doc ([cd60fa0](https://github.com/BingqiangZhou/Sonde/commit/cd60fa0b60cf1769391c4567871f4714aa0ee759))
- *(backend)* Drop unused get_redis_client dependency and its compat test ([4b6d854](https://github.com/BingqiangZhou/Sonde/commit/4b6d854bb5bbf2ee2efa0c476b61ce224d82ed5e))
- Purge obsolete docs, dead code and unused deps ([6b03a41](https://github.com/BingqiangZhou/Sonde/commit/6b03a4153ac6c98552f02356cb46dab1f7ed9349))
- Finish Flutter/Python purge — rewrite history, clean disk leftovers ([d0cc106](https://github.com/BingqiangZhou/Sonde/commit/d0cc106bba15112876dcec56b8b644e6ed0acf40))
- Reset CHANGELOG to v1.0 baseline, update release skill for TS stack ([5b40b53](https://github.com/BingqiangZhou/Sonde/commit/5b40b5386bf0a68a1c752681d7ad48b7731b9232))

### 🐛 Bug Fixes

- *(podcast)* Repair runtime breaks left by the redis consolidation ([0fb5bdf](https://github.com/BingqiangZhou/Sonde/commit/0fb5bdf71ddfccb69ec5c2ea77f9ea8fc468af0f))
- *(backend)* Make fresh-database deployments actually usable ([0811255](https://github.com/BingqiangZhou/Sonde/commit/0811255be8fb6fc9a39ee3c2d2c83ddbd3209d17))
- *(admin)* Replace stale username/password login form with API key field ([d1ebef9](https://github.com/BingqiangZhou/Sonde/commit/d1ebef94a060446c223a15175976f22f274642b5))
- *(frontend)* Show manual-entry hint when the pairing camera fails ([b0edf19](https://github.com/BingqiangZhou/Sonde/commit/b0edf19c8bb9ea51a713ebd3f1cf5b8f1c6eef04))
- *(web)* Serve static assets in custom server and redesign the UI ([f645565](https://github.com/BingqiangZhou/Sonde/commit/f645565da60afdb68c95f1ca813ec68b3c9a6510))

### 📚 Documentation

- Mark TS rewrite v1 complete, add mock-dev guide to README ([c7b2551](https://github.com/BingqiangZhou/Sonde/commit/c7b2551f790f4242e79233c1a015b139e2391a27))

### 🚀 Features

- *(core)* Per-request id middleware with log correlation ([c03de9f](https://github.com/BingqiangZhou/Sonde/commit/c03de9f9df0758f454c48167900fec443b9ba619))
- *(admin)* Encrypt AI-key exports with a passphrase, drop plaintext export ([9b2ae79](https://github.com/BingqiangZhou/Sonde/commit/9b2ae7971efda8657326b76b681f0cb7ad60a492))
- *(backend)* App pairing QR page and incremental episode sync endpoint ([3c85bf8](https://github.com/BingqiangZhou/Sonde/commit/3c85bf894d0729a8094bd40fc9a94544bb1a7eaa))
- *(frontend)* QR pairing flow for backend connection ([c62e3b3](https://github.com/BingqiangZhou/Sonde/commit/c62e3b3a4427c21fe14c61f7cf5f7d1d55e8cbf1))
- *(frontend)* Local truth tables and incremental episode cache sync ([36d1b2a](https://github.com/BingqiangZhou/Sonde/commit/36d1b2aa8bfde60da2aac5ef3bf2826d87547e11))
- *(frontend)* Localize playback, queue, history, stats onto Drift ([71a9a3d](https://github.com/BingqiangZhou/Sonde/commit/71a9a3d9221abcc191675ff620e9a55ae420ed6d))
- *(scaffold)* TS monorepo skeleton — api/worker/web, pg-boss queues, SQL migration, Docker Compose ([d7a2d9c](https://github.com/BingqiangZhou/Sonde/commit/d7a2d9c6920a683ea3746862bb4a823204d50c4c))
- *(core)* LLM/transcription providers with receipts, prompt renderer, tz & json utils ([477cd36](https://github.com/BingqiangZhou/Sonde/commit/477cd3659d22a409bfe924da492e07ec1199e318))
- *(pipeline)* RSS source fetch + six-step transcription pipeline ([2f11546](https://github.com/BingqiangZhou/Sonde/commit/2f11546de6ee1803a208fe0b6d4b033575e67ee1))
- *(analyze+report)* Scoring/writing pipeline and daily report composition ([0926761](https://github.com/BingqiangZhou/Sonde/commit/09267610fe88a9147100df59e8274e7a5004e2dd))
- *(site)* Reading site — home/daily/episode/archive pages + site read API ([641b756](https://github.com/BingqiangZhou/Sonde/commit/641b75619d3e28eee2fbf10621712358d695112a))
- *(admin)* Admin console — sources CRUD, episode diagnostics, reports, costs ([28f75a2](https://github.com/BingqiangZhou/Sonde/commit/28f75a2695495dab7f7bd748b30d56736badbb50))
- *(web)* Switch to AIHOT-style left sidebar layout ([d8366b1](https://github.com/BingqiangZhou/Sonde/commit/d8366b13cd4d11dcf4b73f11792b69d87b634122))

### 🚜 Refactor

- *(ai)* Consolidate the four AI http stacks into the ai domain ([dc188fe](https://github.com/BingqiangZhou/Sonde/commit/dc188fea78e1d0312fdc58f6034f31a5648c1b8f))
- *(podcast)* Drop write-only redis mirrors and the progress monkey-patch ([c13aece](https://github.com/BingqiangZhou/Sonde/commit/c13aece50d64f5aa06ea57e85521bcd0810a4ff9))
- *(podcast)* Split the god repository into aggregate repositories ([46f903c](https://github.com/BingqiangZhou/Sonde/commit/46f903c5a800f1b01b124016f5ff125bf1ac5114))
- *(podcast)* Compose the transcription engine instead of inheriting it ([0ea4afc](https://github.com/BingqiangZhou/Sonde/commit/0ea4afc963eeb66d4616d31c0e70d396e0a03f49))
- *(ai)* Configure all AI keys via admin panel, drop env fallbacks ([5bbc47b](https://github.com/BingqiangZhou/Sonde/commit/5bbc47bcf61f8b5bd28937d7c7e9c0c6b4c17a6e))
- *(admin)* Drop setup-auth service shell and dedupe frequency fan-out ([242143b](https://github.com/BingqiangZhou/Sonde/commit/242143bab7cb0558146d2c5e7fbd8d999c7c4211))
- *(http)* Dissolve app/http package into bootstrap and global handlers ([db2d714](https://github.com/BingqiangZhou/Sonde/commit/db2d714ebac4ed25885b066ee7bb94be5eadaa9e))
- *(ai)* Merge model config services into one class, extract BaseModelManager ([4dc432f](https://github.com/BingqiangZhou/Sonde/commit/4dc432ffa5c95e210ce437d5ad9a98092d85abea))
- *(podcast)* Converge feed on cursor pagination, page-only history, single repo provider ([e85940f](https://github.com/BingqiangZhou/Sonde/commit/e85940fb8d5eb13d8955e05f6ada0a52a1029463))
- *(podcast)* Unify RSS parsing on SecureRSSParser, drop feedparser stack ([f2df0fb](https://github.com/BingqiangZhou/Sonde/commit/f2df0fb7825d5c0804b96e046af3858e4959fed8))
- *(core)* Flatten middleware package into a single module ([96ddd93](https://github.com/BingqiangZhou/Sonde/commit/96ddd9319c305d3b18e70c82769316a08953411f))
- *(podcast)* Decouple summary generation from transcription engine ([7bca7e9](https://github.com/BingqiangZhou/Sonde/commit/7bca7e9b70d83dc6040975709372e0f775f9647b))
- *(podcast)* Collapse transcription service layers into one workflow ([9455eb5](https://github.com/BingqiangZhou/Sonde/commit/9455eb5c0462863b0fa5026e23b94b427cbb994f))
- *(ai)* Unify active-model resolution into a single shared helper ([d47b6d3](https://github.com/BingqiangZhou/Sonde/commit/d47b6d37f74f275df593ce7844f35636909d6f53))
- *(podcast)* Drop dead transcription/summary code paths ([051eba3](https://github.com/BingqiangZhou/Sonde/commit/051eba37d101c8b384ef099021bb80b56b463c62))
- *(ai)* Drop never-read ai_model_configs columns ([0b233cb](https://github.com/BingqiangZhou/Sonde/commit/0b233cbeb86c0470b5c8748e88ec8beed8bc87f9))
- *(podcast)* Repair garbled docstrings and slim transcription logs ([1af9f55](https://github.com/BingqiangZhou/Sonde/commit/1af9f5522faff7f76a343b89a4992d600b48819e))
- *(podcast)* Source transcript/summary payloads from canonical stores ([f6661b0](https://github.com/BingqiangZhou/Sonde/commit/f6661b06cab9b7d127c21b239ca61174248185fc))
- *(podcast)* Drop task-row content copies and summary_version ([df7ba2d](https://github.com/BingqiangZhou/Sonde/commit/df7ba2d6335e9e698fa454c49a8a4ea22d54a0d2))
- *(podcast)* Drop unused summaryVersion field from episode model ([82cb3cf](https://github.com/BingqiangZhou/Sonde/commit/82cb3cfe9ec268a4ace3143a35c8d0d3a8a1a188))
- *(backend)* Strip auth, playback, queue, stats, search, admin pages ([44b1cb5](https://github.com/BingqiangZhou/Sonde/commit/44b1cb5f8ef942d65175e1a89b8799cef6f9d7c5))
- *(frontend)* Retire the JWT auth UI, pairing is the only login ([87a7c11](https://github.com/BingqiangZhou/Sonde/commit/87a7c11ac264f318b497dbb1dc6aa564d725aa77))
- *(infra)* Replace Celery+Redis with procrastinate and nginx with Caddy ([d04e84e](https://github.com/BingqiangZhou/Sonde/commit/d04e84e14f215e2822f822aa7dac7ddbf24a6ddf))
- Remove Python backend, Flutter app and old docker/CI for TS rewrite ([c5636cb](https://github.com/BingqiangZhou/Sonde/commit/c5636cbc2ca7eddba567ab436a0bb10fb42ab343))

### 🧪 Testing

- *(backend)* Add a real-stack integration test tier ([68796d1](https://github.com/BingqiangZhou/Sonde/commit/68796d107dc9fd434064bf71c5bf6ab2f807e362))
- Drop zero-value and duplicate cases, fix stale test artifacts ([98a238a](https://github.com/BingqiangZhou/Sonde/commit/98a238aa179014697bf0fcc46400173bbb8ebd09))
- Consolidate overlapping suites into single homes ([96b6f5c](https://github.com/BingqiangZhou/Sonde/commit/96b6f5ca9033ba5ec4615df388af94b0f51cd1b4))

# Changelog

All notable changes to this project will be documented in this file.

> 基线说明：v1.0.x 起为 TS 重写版（声读 Sonde 播客日报站，Node/React 架构）。
> v0.x（Python/Flutter 时代）的发版历史见远程仓库的 v0.x 标签与 `git log`。
