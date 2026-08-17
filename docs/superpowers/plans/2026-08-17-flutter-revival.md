# PodcastInsight v4 — Flutter 复活 + Skills 数据引擎：详细实施规划

**日期**: 2026-08-17
**状态**: Planned（待批准开工）
**前置结论**: 后台收听是刚需 → 走原生 Flutter 路线；PWA 播放器投入取消，Web 静态站保留只读浏览。

## 1. 目标架构

```
[PC：agent + skills（唯一写入端）]     [git 仓库 data/（唯一真相）]      [Flutter App（读取/播放端）]
  fetch-rankings ──────写───▶   rankings/latest.json        ◀──拉──  GitHub raw/Contents API
  parse-rss ───────────写───▶   podcasts/<id>/meta.json              （只读 PAT + 缓存）
  scrape-episode ──────写───▶   podcasts/<id>/episodes/<id>.md              │
  summarize(+highlights)─写──▶  episodes/*.json + 摘要 frontmatter          │
  daily-report ────────写───▶   reports/YYYY-MM-DD.md                      │
  transcribe(可选) ─────写───▶  transcripts/<id>.md                        │
  bundle(新增) ────────写───▶   bundle.json（App 单文件快照）               ▼
                                                                  ┌─────────────────────┐
                                                                  │ App 内：             │
                                                                  │ · 后台播放(audio_service)│
                                                                  │ · 音频直连播客 CDN     │
                                                                  │ · Drift 本地库：进度/  │
                                                                  │   队列/下载/剧集缓存   │
                                                                  └─────────────────────┘
                                        └──▶ frontend/（Next.js 只读静态站，保持现状）
```

原则（继承 v3，按 2026-08-17 决策修订）：

- **双写入端**：确定性刷新（排行榜/RSS/正文抓取）由 **GitHub Actions 定时任务**（`refresh.yml`，已恢复）自动执行并 commit；智能操作（订阅、摘要、转写）仍由 PC 上 agent 触发。CI 不做摘要（无 LLM，与 v3 无 API Key 原则一致）。
- **App 纯只读 + 本地私有状态**：订阅/数据来自 git；播放进度、队列、下载是设备私有（Drift），不进 git。
- **音频不走自有设施**：App 直接流式播放 RSS enclosure 指向的播客 CDN；离线下载同理。
- **零后端零运维**：不复活 FastAPI/Celery/Redis/Docker；唯一的"服务"是 GitHub 本身（Actions + raw）。

## 2. 代码资产盘点（考古结论，规划依据）

### 2.1 v0.52.0 Flutter 资产（`git archive v0.52.0 frontend` 可完整取出）

| 资产 | 状态 | 规划处置 |
|------|------|----------|
| `features/podcast/`（124 文件） | 完整：feed/episodes/detail(5文件)/daily_report/highlights/downloads/discover 页面全在 | 保留主体，换数据源 |
| `core/network/`（仅 5 文件） | dio_client + 异常解析 + 服务器健康检查 + token 刷新 | 删 4 留 dio_client 改造 |
| `features/auth/`（19 文件） | JWT 登录/2FA/会话 | 整体删除 |
| `core/database/`（Drift） | playback_dao / episode_cache_dao / download_dao 三个 DAO 齐全 | 原样保留（Phase 2 主力） |
| 播放栈 | audioplayers 6.6 + audio_service 0.18；manifest 已配 FOREGROUND_SERVICE_MEDIA_PLAYBACK、MediaButtonReceiver；曾在 Android 15 + Vivo OriginOS 实机调优音频焦点 | 原样保留（本规划的核心价值） |
| 设计系统 | Liquid Glass + Cupertino 适配 + 深浅主题 + i18n | 原样保留，不再投入设计 |
| `core/storage/` | flutter_secure_storage | 保留，改存 GitHub 只读 PAT |
| retrofit 代码生成层 | REST client 生成物 | 删除，换 DataRepository |

依赖新鲜度：riverpod 3 / go_router 17 / drift 2.31 / dio 5.9（2026-04 版本），距今约 4 个月，先原版跑通再升级。

### 2.2 当前 v3 资产

| 资产 | 状态 | 差距 |
|------|------|------|
| 4 个 skill + `_shared` | 代码完成，TDD | summarize 需扩展 highlights |
| `EpisodeMeta` schema | **已有 `audio_url` + `duration`**（播放刚需字段现成） | 缺 highlights / transcript_path / image_url，无 schema_version |
| `data/` | **空**（仅 .gitkeep） | Phase 0 必须先跑出真实数据 |
| Web 静态站 | 5 页只读 SSG | 保持现状，不加音频 |
| CI | release.yml + **refresh.yml（定时刷新，已恢复）** | 后续加 APK 构建 |

## 3. 数据 schema v2（向后兼容增补）

`skills/_shared/src/types.ts`：

```ts
// EpisodeMeta 增补（全部可选，老数据不破坏）
interface EpisodeMeta {
  // ...现有字段不变...
  image_url?: string;            // 剧集封面（RSS itunes:image）
  audio_mime?: string;           // "audio/mpeg" 等
  highlights?: string[];         // AI 金句（summarize 产出）
  transcript_path?: string;      // "transcripts/<id>.md"（transcribe 产出）
}

// 新增
interface Bundle {               // bundle skill 产出，App 单文件快照
  schema_version: 2;
  updated_at: string;
  podcasts: (PodcastMeta & { episode_count: number })[];
  episodes: EpisodeMeta[];       // 已订阅播客的全部剧集（元数据）
  rankings_updated_at: string;
}
```

- `meta.json` / `bundle.json` 增加 `schema_version`，App 端按版本降级兼容。
- 新增数据布局：`data/reports/YYYY-MM-DD.md`（日报）、`data/transcripts/<id>.md`（转写稿）、`data/bundle.json`（App 快照）。
- 路径一律走 `skills/_shared/src/paths.ts`（既定约定），新增三个路径常量。

## 4. 里程碑总览

| 里程碑 | 内容 | 工作量 | 验收标准 |
|--------|------|--------|----------|
| **M0** | 数据管线跑通 + schema v2 + bundle skill | 1 天 | data/ 有真实数据；`pnpm test` 绿；bundle.json 生成 |
| **M1** | Flutter MVP：剥壳 + 数据层 + 后台播放 | 5–8 天 | 手机后台播放 30 分钟不断、锁屏可控、下拉刷新见新数据 |
| **M2** | 离线下载 + 播放体验补齐 | 2–3 天 | 无网环境可播放已下载剧集；自动下载生效 |
| **M3** | 知识层：highlights / 日报 / 转写 / OPML | 每项 0.5–1 天 | App 内可见金句、日报日历、（可选）转写稿 |
| **横切** | CI 加 APK 构建、tag 恢复、文档 | 1 天 | push tag 自动出 APK |

总量约 3–4 周业余时间。M1 是核心工程，其余大量复用。

## 5. M0 — 数据管线跑通（一切的前提）

### 5.0 管线现状（代码级事实）

- 全部环节都汇聚到 `rebuildIndexes()`（`_shared/index-builder.ts`）：每个 skill 收尾时调用，重扫 data/ 生成 `index.json` + `search-index.json`。**bundle 并入此处**，所有 skill 自动获得 bundle 刷新，无需独立 skill 包。
- 格式契约（改字段时不能破坏）：.md 必须含 `## AI 摘要`（index-builder 正则提取）与 `## 正文`（前端 markdown.ts 与 summarize 提取）两段。
- 测试隔离机制：`PODCASTINSIGHT_DATA_DIR` 环境变量指向临时目录（paths.ts 每次实时解析，见其注释）。

### 5.1 代码改动（先于跑数）

1. **schema v2**（`_shared`）：`EpisodeMeta` 增可选字段 `image_url` / `audio_mime` / `highlights` / `transcript_path`；新增 `Bundle` 类型与 `schema_version`；`paths.ts` 增 `bundleFile()` / `reportsDir()` / `transcriptsDir()`；`validate.ts` 同步；全部向后兼容（可选字段，老数据不破坏）。
2. **parse-rss 增强**：rss-parser 抽取 `itunes:image`（episode 级）与 enclosure `@_type` → `audio_mime`；`--limit N` 参数（首跑只取每播客最近 N 集，避免一次写入上千文件）。
3. **scrape-episode 兜底**：无 `link` 或抓取结果为空时，若 `description` 清洗后仍有一定长度（阈值 ~200 字符），以 description 为 `## 正文` 写 .md 并标 done（v0.1.5 经验复用），否则才标 failed。
4. **bundle 产出**（`_shared/index-builder.ts`）：`rebuildIndexes()` 同时聚合写 `data/bundle.json`——rankings 时间戳 + 订阅播客 meta + 每播客最近 50 集元数据（体积控制；全集走按需目录拉取）。
5. **subscribe 辅助命令**（fetch-rankings 包内加子命令或参数）：按排行榜名次/关键词从 latest.json 选播客，生成 `data/podcasts/<id>/meta.json`（`subscribed: true`）。id 用名称 slug + 短哈希。

### 5.2 数据刷新：定时任务方式（2026-08-17 决策，替代手动/agent 触发）

**refresh.yml 已恢复**（从 21bd7d62 找回，修正两处：脚本名 `run`→`refresh`（135c9d79 改名）；加 `concurrency` 防重叠）。机制：

- 每周一 08:00 UTC（北京时间 16:00）：fetch-rankings；
- 每日 08:00 UTC：parse-rss + scrape-episode；
- 每次跑完自动 commit + push `data/`（含 index/search-index/bundle，随 `rebuildIndexes()` 自动产出）；
- 支持 workflow_dispatch 手动触发（rankings | rss | scrape | all），首轮种子和调试用。

**一次性种子（CI 只刷新已有订阅，冷启动仍需人工一次）**：

1. 恢复后的 workflow 先手动 dispatch 一次 `rankings`，产出 `rankings/latest.json`；
2. 用 subscribe 辅助命令（或 agent 手动）建 3–5 个 `meta.json` 订阅并 commit；
3. 再 dispatch 一次 `rss`，完成首轮剧集 + 正文抓取（parse-rss 带 `--limit 50` 控制首跑规模）。

此后进入常态：**每日 CI 自动发现新剧集、抓正文、推 bundle；agent 对话只负责摘要**（CI 无 LLM，摘要无法定时化——这是 v3 无 API Key 原则的既定边界）。

注意事项：GitHub 会自动停用 60 天无活动的仓库的定时 workflow（任何 push 会重置计时，本项目有每日数据 push，不受影响）；私有仓库 Actions 分钟数消耗约每日 3–5 分钟，免费额度（2000 分钟/月）充足。

### 5.3 提交切分与验收

提交序列：① 恢复 refresh.yml（已完成）② shared schema v2 ③ parse-rss 增强 ④ scrape 兜底 ⑤ bundle 产出 ⑥ subscribe 命令 ⑦ 首批订阅种子数据（+ README 快速开始同步）。

验收：workflow_dispatch 全绿且 `data/` 出现 CI bot 的自动提交；`data/` 六类文件齐全且非空（rankings/podcasts/episodes .json+.md/index/search-index/bundle）；`pnpm test` 全绿；`pnpm build` 后 Web 站有真实内容；scrape 失败率 < 30%（兜底生效的证据）。

## 6. M1 — Flutter MVP（核心工程）

### 6.1 导出与重命名（0.5 天）

```bash
git archive v0.52.0 frontend | tar -x -C app/    # monorepo 新顶层目录 app/
```

- 包名 `com.opc.stella` → `com.bingqiang.podcastinsight`（applicationId + iOS bundle id + manifest 里 `com.opc.stella.DownloadService` 引用同步改）。
- `pubspec.yaml`：name 改 `podcastinsight_app`；删 retrofit/retrofit_generator；`flutter pub get` 确认可解析。

### 6.2 剥壳（1–1.5 天）

**删除**：

- `features/auth/` 全部（19 文件）+ 路由表中的 auth 守卫 + `token_refresh_service.dart` + `server_health_service.dart`；
- `features/splash/` 的登录跳转逻辑（保留启动画面本身）；
- `features/profile/` 中：服务器配置对话框、多设备会话、2FA 相关；
- `features/settings/` 中：API Key 管理、音频处理配置（后端概念）；
- retrofit 生成物 `*.g.dart`（API client 层）；
- `main.dart` / `app.dart` 中的认证 bootstrap。

**保留不动**：`features/podcast/` 全部页面与组件、`core/database`、`core/theme`、`core/platform`、`core/widgets`、`core/localization`、`audio_handler.dart`、`podcast_playback_providers.dart`、AndroidManifest 的音频服务声明。

### 6.3 数据层重建（2–3 天，唯一的"新代码"）

新建 `app/lib/core/datasource/`：

- `github_data_source.dart`：GitHub Contents API（列目录、ETag/If-None-Match 缓存）+ raw 拉文件；私有仓库走 `Authorization: Bearer <PAT>`（fine-grained、只读 Contents 权限、单独小号 token 控制泄露半径）；dio + dio_cache_interceptor（v0.x 现成经验）。
- `data_repository.dart`：`bundle.json` → 首页/列表模型；`episodes/<id>.md` → 正文+摘要（frontmatter 解析）；`reports/*.md` → 日报列表。
- PAT 配置页：设置页加一个"数据源"卡片（repo + token 输入，flutter_secure_storage 存储）。

**换接策略**：尽量保持 Riverpod provider 的对外签名不变，只替换 repository 实现——presentation 层（124 文件的大头）基本不动。原 `features/podcast/data/repositories/` 逐个改继承 DataRepository 或删除。

### 6.4 播放接通（1 天）

- `audio_handler` 播放源改为 `EpisodeMeta.audio_url`（字段现成）；
- 播放队列从 Drift playback_dao 读（不再依赖后端 queue API）；
- 倍速、睡眠定时、进度记忆走本地（v0.x 逻辑保留，去掉 API 同步分支）。

### 6.5 页面接通与 MVP 裁剪（1–1.5 天）

MVP 页面集：**feed（首页时间线）→ 剧集列表 → 剧集详情（摘要 tab + 播放）**。

- `podcast_daily_report_page` / `podcast_highlights_page`：保留代码、暂隐藏入口（M3 接数据后放开）；
- `podcast_downloads_page`：保留、隐藏入口（M2 放开）；
- discover 页接 `rankings` 数据做只读浏览（可选加分项，订阅仍在 agent 侧做）。

### 6.6 构建与真机验收（0.5–1 天）

```bash
cd app && flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

验收清单（Vivo 实机）：后台播放 30 分钟不断；锁屏控件（播放/暂停/快进）可用；通知栏常驻；拔耳机自动暂停；来电后恢复；下拉刷新拉到新数据；断网时浏览已缓存内容。

## 7. M2 — 离线与播放体验（2–3 天，几乎全是复用）

1. **离线下载**：download_dao + 下载队列 + 队列自动下载（v0.36 现成），下载源 = enclosure CDN；前台服务声明已在 manifest。
2. **锁屏/通知栏增强**：封面、队列上一首/下一首（audio_service capability 已配）。
3. **可选**：home widget（v0.47 有脚手架）、应用内自更新（v0.0.8 DownloadService，M1 改包名时保留引用）。

## 8. M3 — 知识层技能（App 的差异化价值）

| 任务 | 内容 | App 端 |
|------|------|--------|
| highlights | summarize prompt 扩展：摘要+金句+标签一次生成；写 EpisodeMeta.highlights + md frontmatter | highlights 页面放开（UI 现成） |
| daily-report | 新 skill：聚合当日新剧集+摘要 → `data/reports/YYYY-MM-DD.md` | daily_report 页 + table_calendar 放开（UI 现成） |
| opml-import | parse-rss 加 `--opml <file>`：批量建 meta.json 订阅 | 无（agent/CLI 触发） |
| transcribe（可选，按需） | 新 skill：剧集无正文时用 enclosure 音频走 whisper（本地 faster-whisper 或 API）→ `transcripts/<id>.md`；成本高，agent 按需触发 | 详情页加"转写稿" tab |

## 9. 横切事项

- **monorepo 布局**：`skills/ + data/ + frontend/(web) + app/(flutter)`；pnpm workspace 不含 app（Flutter 用自己的工具链），根 package.json 加 `app:dev` 之类的脚本即可。
- **CI**：release.yml 增加 job——tag `v*` 触发 `flutter build apk` 并挂到 GitHub Release（私有仓库 Release 仅自己可见，作为 APK 分发通道）。
- **版本**：恢复 git-cliff 流程，本规划落地版本定为 **v4.0.0**；M1 完成打 v4.0.0-alpha。
- **隐私与安全**：仓库保持私有；PAT 用 fine-grained 只读 token；App 内 PAT 存 secure_storage；bundle/episodes 数据不含任何密钥。
- **文档**：CLAUDE.md 增补 app/ 约定（App 只读、本地状态不进 git、数据变更一律走 skill）；本计划文档随进度更新状态。

## 10. 风险与对策

| 风险 | 概率 | 对策 |
|------|------|------|
| 剥壳牵连比预期深（provider 链里藏 auth 依赖） | 中 | 剥壳从 main.dart 向下追依赖树删除，编译器驱动；先删后接 |
| Flutter SDK / 依赖 4 个月漂移 | 低 | 先用原版 pubspec 跑通，再统一 `flutter pub upgrade`；不中途升 |
| 国产 ROM 后台播放回归（机型相关） | 中 | v0.0.8 的 OriginOS 调优已包含；真机验收清单兜底；必要时加前台服务保活说明页 |
| GitHub API 限流/网络 | 低 | Contents API 认证后 5000 req/h；dio 缓存 + 失败读本地 Drift 缓存 |
| whisper 转写成本 | 中 | 定位可选；先只对"无正文可抓"剧集按需触发；本地 GPU 优先 |
| app/ 与 frontend/ 双客户端漂移 | 低 | 数据 schema 单一真相在 `_shared/types.ts`；bundle skill 是唯一聚合出口 |

## 11. 执行顺序建议（串行，每步可提交）

M0（1 天）→ M1.1 导出 → M1.2 剥壳 → M1.3 数据层 → M1.4 播放 → M1.5 页面 → M1.6 真机（M1 合计 5–8 天）→ 横切 CI → M2（2–3 天）→ M3 按价值排序逐个上（highlights → daily-report → opml → transcribe）。

每个子步骤独立 commit，M1 期间 app/ 允许处于"可编译但不完整"状态，主线 skills/data 不受影响。
