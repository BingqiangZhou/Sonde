# 更新日志

本文件记录声读（Sonde）所有重要变更；英文版见 [CHANGELOG_EN.md](CHANGELOG_EN.md)。



## [1.1.0](https://github.com/BingqiangZhou/Sonde/compare/v1.0.1...v1.1.0) - 2026-09-29 ([📥](https://github.com/BingqiangZhou/Sonde/releases/tag/v1.1.0))

> v1.1.0 将 Web 端升级到 React Router 8.4.0，并新增「全部动态」页（/all）：所有完成评分的单集（含未过门槛者）统一在此浏览——入选条目链接到单集详情，未入选条目展示灰色评分与筛选理由；同时补齐 GitHub Actions CI 与推送 v* 标签后自动验证并创建 GitHub Release 的发版流水线，并修复了全新 checkout 上 server.ts 因引用构建产物导致 typecheck 失败的问题。
>
> 共 3 个提交：🚀 新功能 1 | ⚙️ 其他事务 1 | 🐛 问题修复 1

### ⚙️ 其他事务

- *(ci)* 新增 GitHub Actions CI 与标签触发的发版流水线 ([410e7c1](https://github.com/BingqiangZhou/Sonde/commit/410e7c1da84ac6c057930d9329ee333dbc9ea10b))

### 🚀 新功能

- *(web)* 升级到 React Router 8 并新增「全部动态」页（/all） ([8599b4f](https://github.com/BingqiangZhou/Sonde/commit/8599b4f082f95cf22f627092360376ca18caf8f0))

### 🐛 问题修复

- *(web)* 修复全新 checkout 无构建产物时 typecheck 失败的问题 ([90880f1](https://github.com/BingqiangZhou/Sonde/commit/90880f10d6ab9227c37d1da0387e28e5c6d6f844))



## [1.0.1](https://github.com/BingqiangZhou/Sonde/compare/v0.53.0...v1.0.1) - 2026-09-29 ([📥](https://github.com/BingqiangZhou/Sonde/releases/tag/v1.0.1))

> v1.0.1 是声读的全面重写首发版：从 Python/Flutter 迁移到 Node 24 + TypeScript monorepo（Fastify + pg-boss + React Router 7 SSR + Tailwind），完整实现播客 RSS 采集、六步音频转写流水线、按分级门槛的 AI 评分筛选、每天 08:00（北京时间）自动成刊的中文日报，以及报刊风阅读站与后台控制台；同时彻底清除了旧栈的代码、文档与历史遗留。
>
> 共 57 个提交：🚀 新功能 13 | 🚜 重构 24 | ⚙️ 其他事务 11 | 🐛 问题修复 5 | 🧪 测试 3 | 📚 文档 1

### ⚙️ 其他事务

- *(release)* 为发版流水线加入双语 AI 摘要 ([d728f69](https://github.com/BingqiangZhou/Sonde/commit/d728f6907bbbce51943f3039b33d14af6a0750fa))
- *(backend)* 加固 Celery 可靠性、鉴权安全与部署 ([157c4a6](https://github.com/BingqiangZhou/Sonde/commit/157c4a6ddd2b186a722e7f1748f5821cc5b7712d))
- *(backend)* 清理横切面的卫生债 ([76192fa](https://github.com/BingqiangZhou/Sonde/commit/76192fad312cbe42c078e9baf355b0fccd237a46))
- *(docker)* Compose 栈更名为 sonde 并重构结构 ([d4dae3e](https://github.com/BingqiangZhou/Sonde/commit/d4dae3e49594efa0a94629d61768ca2c376b8d34))
- *(docker)* 移除 postgres 备份 sidecar ([acea708](https://github.com/BingqiangZhou/Sonde/commit/acea708a573de36c761a6980f032b4f836a6fc99))
- *(backend)* 移除过期的 Dockerfile.cn、失效的快速上手文档与废弃的 mypy 配置 ([24edbd1](https://github.com/BingqiangZhou/Sonde/commit/24edbd120d4b3dafea9eae18ea9d34c2a4f2d09b))
- *(backend)* 移除未使用的 openapi-diff 脚本与异常处理文档 ([cd60fa0](https://github.com/BingqiangZhou/Sonde/commit/cd60fa0b60cf1769391c4567871f4714aa0ee759))
- *(backend)* 移除未使用的 get_redis_client 依赖及其兼容测试 ([4b6d854](https://github.com/BingqiangZhou/Sonde/commit/4b6d854bb5bbf2ee2efa0c476b61ce224d82ed5e))
- 清理过时文档、死代码与无用依赖 ([6b03a41](https://github.com/BingqiangZhou/Sonde/commit/6b03a4153ac6c98552f02356cb46dab1f7ed9349))
- 完成 Flutter/Python 清除——重写历史、清理磁盘残留 ([d0cc106](https://github.com/BingqiangZhou/Sonde/commit/d0cc106bba15112876dcec56b8b644e6ed0acf40))
- 将 CHANGELOG 重置为 v1.0 基线，发版 skill 适配 TS 技术栈 ([5b40b53](https://github.com/BingqiangZhou/Sonde/commit/5b40b5386bf0a68a1c752681d7ad48b7731b9232))

### 🐛 问题修复

- *(podcast)* 修复 Redis 合并遗留的运行时故障 ([0fb5bdf](https://github.com/BingqiangZhou/Sonde/commit/0fb5bdf71ddfccb69ec5c2ea77f9ea8fc468af0f))
- *(backend)* 让全新数据库的部署真正可用 ([0811255](https://github.com/BingqiangZhou/Sonde/commit/0811255be8fb6fc9a39ee3c2d2c83ddbd3209d17))
- *(admin)* 用 API Key 输入替换过期的用户名/密码登录表单 ([d1ebef9](https://github.com/BingqiangZhou/Sonde/commit/d1ebef94a060446c223a15175976f22f274642b5))
- *(frontend)* 配对扫码失败时显示手动输入提示 ([b0edf19](https://github.com/BingqiangZhou/Sonde/commit/b0edf19c8bb9ea51a713ebd3f1cf5b8f1c6eef04))
- *(web)* 自定义服务器提供静态资源并整体重设计界面 ([f645565](https://github.com/BingqiangZhou/Sonde/commit/f645565da60afdb68c95f1ca813ec68b3c9a6510))

### 📚 文档

- 标记 TS 重写 v1 完成，README 增加本地 mock 开发指南 ([c7b2551](https://github.com/BingqiangZhou/Sonde/commit/c7b2551f790f4242e79233c1a015b139e2391a27))

### 🚀 新功能

- *(core)* 按请求生成 id 的中间件与日志关联 ([c03de9f](https://github.com/BingqiangZhou/Sonde/commit/c03de9f9df0758f454c48167900fec443b9ba619))
- *(admin)* AI Key 导出改用口令加密，移除明文导出 ([9b2ae79](https://github.com/BingqiangZhou/Sonde/commit/9b2ae7971efda8657326b76b681f0cb7ad60a492))
- *(backend)* 应用配对二维码页面与单集增量同步接口 ([3c85bf8](https://github.com/BingqiangZhou/Sonde/commit/3c85bf894d0729a8094bd40fc9a94544bb1a7eaa))
- *(frontend)* 连接后端的二维码配对流程 ([c62e3b3](https://github.com/BingqiangZhou/Sonde/commit/c62e3b3a4427c21fe14c61f7cf5f7d1d55e8cbf1))
- *(frontend)* 本地事实表与单集缓存增量同步 ([36d1b2a](https://github.com/BingqiangZhou/Sonde/commit/36d1b2aa8bfde60da2aac5ef3bf2826d87547e11))
- *(frontend)* 播放、队列、历史、统计本地化迁移到 Drift ([71a9a3d](https://github.com/BingqiangZhou/Sonde/commit/71a9a3d9221abcc191675ff620e9a55ae420ed6d))
- *(scaffold)* TS monorepo 骨架——api/worker/web、pg-boss 队列、SQL 迁移、Docker Compose ([d7a2d9c](https://github.com/BingqiangZhou/Sonde/commit/d7a2d9c6920a683ea3746862bb4a823204d50c4c))
- *(core)* LLM/转写 provider（含成本台账）、prompt 渲染器、时区与 JSON 工具 ([477cd36](https://github.com/BingqiangZhou/Sonde/commit/477cd3659d22a409bfe924da492e07ec1199e318))
- *(pipeline)* RSS 源抓取 + 六步转写流水线 ([2f11546](https://github.com/BingqiangZhou/Sonde/commit/2f11546de6ee1803a208fe0b6d4b033575e67ee1))
- *(analyze+report)* 评分/写作流水线与日报成刊 ([0926761](https://github.com/BingqiangZhou/Sonde/commit/09267610fe88a9147100df59e8274e7a5004e2dd))
- *(site)* 阅读站——首页/日报/单集/归档页面 + 站点读 API ([641b756](https://github.com/BingqiangZhou/Sonde/commit/641b75619d3e28eee2fbf10621712358d695112a))
- *(admin)* 后台控制台——订阅源管理、单集诊断、日报、成本 ([28f75a2](https://github.com/BingqiangZhou/Sonde/commit/28f75a2695495dab7f7bd748b30d56736badbb50))
- *(web)* 改为 AIHOT 风格的左侧栏布局 ([d8366b1](https://github.com/BingqiangZhou/Sonde/commit/d8366b13cd4d11dcf4b73f11792b69d87b634122))

### 🚜 重构

- *(ai)* 将四套 AI HTTP 栈合并进 ai 领域 ([dc188fe](https://github.com/BingqiangZhou/Sonde/commit/dc188fea78e1d0312fdc58f6034f31a5648c1b8f))
- *(podcast)* 移除只写的 Redis 镜像与进度 monkey-patch ([c13aece](https://github.com/BingqiangZhou/Sonde/commit/c13aece50d64f5aa06ea57e85521bcd0810a4ff9))
- *(podcast)* 拆分巨型仓库为聚合仓库 ([46f903c](https://github.com/BingqiangZhou/Sonde/commit/46f903c5a800f1b01b124016f5ff125bf1ac5114))
- *(podcast)* 转写引擎改为组合而非继承 ([0ea4afc](https://github.com/BingqiangZhou/Sonde/commit/0ea4afc963eeb66d4616d31c0e70d396e0a03f49))
- *(ai)* AI Key 全部改由后台面板配置，移除环境变量回退 ([5bbc47b](https://github.com/BingqiangZhou/Sonde/commit/5bbc47bcf61f8b5bd28937d7c7e9c0c6b4c17a6e))
- *(admin)* 移除 setup-auth 服务壳，频率分发去重 ([242143b](https://github.com/BingqiangZhou/Sonde/commit/242143bab7cb0558146d2c5e7fbd8d999c7c4211))
- *(http)* 解散 app/http 包并入 bootstrap 与全局处理器 ([db2d714](https://github.com/BingqiangZhou/Sonde/commit/db2d714ebac4ed25885b066ee7bb94be5eadaa9e))
- *(ai)* 合并模型配置服务为单类，抽出 BaseModelManager ([4dc432f](https://github.com/BingqiangZhou/Sonde/commit/4dc432ffa5c95e210ce437d5ad9a98092d85abea))
- *(podcast)* 订阅流统一为游标分页、历史仅分页、单一 repo provider ([e85940f](https://github.com/BingqiangZhou/Sonde/commit/e85940fb8d5eb13d8955e05f6ada0a52a1029463))
- *(podcast)* RSS 解析统一到 SecureRSSParser，移除 feedparser 技术栈 ([f2df0fb](https://github.com/BingqiangZhou/Sonde/commit/f2df0fb7825d5c0804b96e046af3858e4959fed8))
- *(core)* 中间件包扁平化为单模块 ([96ddd93](https://github.com/BingqiangZhou/Sonde/commit/96ddd9319c305d3b18e70c82769316a08953411f))
- *(podcast)* 摘要生成与转写引擎解耦 ([7bca7e9](https://github.com/BingqiangZhou/Sonde/commit/7bca7e9b70d83dc6040975709372e0f775f9647b))
- *(podcast)* 转写服务层合并为单一工作流 ([9455eb5](https://github.com/BingqiangZhou/Sonde/commit/9455eb5c0462863b0fa5026e23b94b427cbb994f))
- *(ai)* 激活模型解析统一为单一共享辅助函数 ([d47b6d3](https://github.com/BingqiangZhou/Sonde/commit/d47b6d37f74f275df593ce7844f35636909d6f53))
- *(podcast)* 移除失效的转写/摘要代码路径 ([051eba3](https://github.com/BingqiangZhou/Sonde/commit/051eba37d101c8b384ef099021bb80b56b463c62))
- *(ai)* 移除从未读取的 ai_model_configs 列 ([0b233cb](https://github.com/BingqiangZhou/Sonde/commit/0b233cbeb86c0470b5c8748e88ec8beed8bc87f9))
- *(podcast)* 修复乱码 docstring，精简转写日志 ([1af9f55](https://github.com/BingqiangZhou/Sonde/commit/1af9f5522faff7f76a343b89a4992d600b48819e))
- *(podcast)* 转写/摘要数据改以权威存储为源 ([f6661b0](https://github.com/BingqiangZhou/Sonde/commit/f6661b06cab9b7d127c21b239ca61174248185fc))
- *(podcast)* 移除任务行内容副本与 summary_version ([df7ba2d](https://github.com/BingqiangZhou/Sonde/commit/df7ba2d6335e9e698fa454c49a8a4ea22d54a0d2))
- *(podcast)* 移除 episode 模型中未使用的 summaryVersion 字段 ([82cb3cf](https://github.com/BingqiangZhou/Sonde/commit/82cb3cfe9ec268a4ace3143a35c8d0d3a8a1a188))
- *(backend)* 剥离鉴权、播放、队列、统计、搜索、管理页面 ([44b1cb5](https://github.com/BingqiangZhou/Sonde/commit/44b1cb5f8ef942d65175e1a89b8799cef6f9d7c5))
- *(frontend)* 退役 JWT 鉴权 UI，配对成为唯一登录方式 ([87a7c11](https://github.com/BingqiangZhou/Sonde/commit/87a7c11ac264f318b497dbb1dc6aa564d725aa77))
- *(infra)* 用 procrastinate 替换 Celery+Redis，用 Caddy 替换 nginx ([d04e84e](https://github.com/BingqiangZhou/Sonde/commit/d04e84e14f215e2822f822aa7dac7ddbf24a6ddf))
- 为 TS 重写移除 Python 后端、Flutter 应用与旧 docker/CI ([c5636cb](https://github.com/BingqiangZhou/Sonde/commit/c5636cbc2ca7eddba567ab436a0bb10fb42ab343))

### 🧪 测试

- *(backend)* 增加真实技术栈的集成测试层 ([68796d1](https://github.com/BingqiangZhou/Sonde/commit/68796d107dc9fd434064bf71c5bf6ab2f807e362))
- 删除零价值与重复用例，修复过期测试产物 ([98a238a](https://github.com/BingqiangZhou/Sonde/commit/98a238aa179014697bf0fcc46400173bbb8ebd09))
- 合并重叠的测试套件到统一归属 ([96b6f5c](https://github.com/BingqiangZhou/Sonde/commit/96b6f5ca9033ba5ec4615df388af94b0f51cd1b4))

---

> 基线说明：v1.0.x 起为 TS 重写版（声读 Sonde 播客日报站，Node/React 架构）。
> v0.x（Python/Flutter 时代）的发版历史见远程仓库的 v0.x 标签与 `git log`。
