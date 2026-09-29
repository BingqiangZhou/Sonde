# 服务端流水线架构：后端只留"定时更新 + 转写 + AI 总结"，前端扫码接入、本地消费

- 日期：2026-08-21
- 状态：设计稿，待评审后实施
- 定夺：后端保留 **定时获取播客更新 + 转录 + AI 总结及相关功能**，其余全部删除；前端**扫码接入**后端，播放/队列/设置等消费功能本地化。
- 与前两份已搁置方案的关系：LOCAL_FIRST 的变体——**RSS 定时抓取留在服务端**（保住 beat 的 7×24 可靠性），后端仍是剧集元数据的真相源，app 是缓存+消费端。前端最大的工作量（Dart RSS 引擎）因此消失。

## 一、边界划分

```
┌────────── 云端后端（更新 + AI 流水线，真相源）──────────┐
│ 订阅目录/剧集存储（beat 定时抓 RSS，现有能力不动）        │
│ 转写管道 → transcripts │ 摘要管道 → summaries │ 日报      │
│ AI key 管理（admin apikeys 页）│ 接入 QR 页（新增）        │
│ 面向 app 的精简读 API：订阅 CRUD / 剧集增量同步 / AI 产物  │
└──────────────────┬─────────────────────────────────────┘
                   │ 扫码接入（地址 + API key），无账号体系
┌──────────────────▼──── Flutter app（消费 + 本地状态）─────┐
│ 剧集缓存（增量同步）│ 播放状态/队列/设置 → Drift 本地      │
│ 搜索（本地缓存上）│ 转写/摘要/日报展示（拉取+缓存离线读）  │
└─────────────────────────────────────────────────────────┘
```

## 二、后端改造清单

### 保留（多数零改动）

| 模块 | 说明 |
|------|------|
| feeds/subscriptions/episodes 表 + beat 定时刷新 | 后端必须知道"抓什么"；现有 `tasks_subscription` 原样 |
| 转写/摘要管道 + 日报 | `tasks_transcription` / `tasks_summary` / `tasks_daily_report` 原样 |
| `domains/ai/` 整域 | model configs / key_resolver / invocation 不动 |
| 订阅 CRUD API | `routes_subscriptions`（增删改/test-url/OPML）保留——后端要维护抓取目录 |
| 剧集读 API（收敛为增量同步） | `routes_episodes` 的 feed/详情保留，**新增 `GET /podcasts/episodes/sync?since=<ts>`** 供 app 缓存；history/playback/搜索端点删 |
| 转写/摘要触发与结果 API | `routes_transcriptions` 保留 |
| admin：login + apikeys | 登录机制不变（API_KEY→HMAC cookie） |

### 新增：接入 QR

- admin 面板新增"接入"页（登录后可见）：展示二维码 + 可复制的原始串；
- QR 内容：`sonde://connect?host=<scheme://host:port>&key=<API_KEY>`；
- 备选通道：CLI（`docker compose exec backend ...` 终端打印 ASCII QR），无浏览器场景用；
- 安全注记：QR 含部署密钥，只在 owner 已通过 API key 登录的页面展示，单用户部署可接受；不做一次性配对 token（复杂度不值）。

### 删除

| 模块 | 处置 |
|------|------|
| `domains/auth/` 整域 | JWT 注册/登录/刷新/改昵称全删；app 无账号概念，认证回归单 API key |
| 播放状态同步 | `routes_episodes` 中 playback/history 端点 + `playback_repository` |
| 队列 API | `routes_queue` + `queue_repository`（播放队列纯本地化；与 worker 无关） |
| 统计/搜索 | `routes_stats` + `stats_repository`、`search_repository`（本地缓存上算） |
| 用户设置 API | audio settings / 频率偏好等（`settings` 相关端点）|
| admin 三页 | dashboard / settings / subscriptions 页及服务（保留 login + apikeys + 新增接入页） |
| 数据库 | 最终迁移 drop：`podcast_playback_states`、`podcast_queues(+items)`、`users`（或保留单行维持 FK，实施时按依赖定）；`podcast_daily_reports.user_id` 等挂 user 的列收敛为单用户语义 |

### 部署

compose 不变（6 容器，beat 是本架构的核心组件，与 LOCAL_FIRST 方案相反）。`require_api_key` 简化为单模式（JWT 分支删除）。

## 三、前端改造清单

1. **扫码接入替代登录/注册**：首次启动 → 扫码（`mobile_scanner`）→ 解析 host/key → 调 `server_health_service` 验证 → `flutter_secure_storage` 保存 → 进入首页。`features/auth`（登录/注册/忘记密码）整块删除；
2. **Drift 本地化**：`playback_states` / `queue_items` / `settings` 新表；`EpisodesCache` 升格为增量同步缓存（记录 `last_synced_at`，调 sync 端点拉增量）；
3. **provider 层切换**：播放进度、队列、偏好读写改走 Local repository；剧集列表 = 缓存 + 后台刷新；
4. **AI 产物消费**：转写/摘要/日报调现有保留端点，结果落本地缓存（离线可读）；
5. **搜索/统计**：本地 SQL over 缓存表。

## 四、实施阶段（每阶段独立可发布，阶段 3 前可回滚）

| 阶段 | 内容 | 验收 |
|------|------|------|
| 1 | 后端：接入 QR 页 + sync 增量端点（纯新增，零破坏） | Docker 冒烟：admin 见 QR、app 模拟器扫码连通 |
| 2 | 前端：扫码接入 + 播放/队列/设置/搜索本地化 + 剧集缓存同步 | flutter test + 模拟器全功能摸底（新旧认证并存期） |
| 3 | 后端删除：auth 域 + 播放/队列/统计/搜索/设置 API + admin 三页 + drop 迁移 + require_api_key 收敛 | pytest 全绿；四类 API 404 确认 |
| 4 | 前端删 `features/auth`；旧 JWT 流程退役 | 全量回归 |

## 五、风险与开放问题

1. ** breaking change**：阶段 3/4 后旧版 app（JWT 登录）无法使用——发版说明需标注"需先升级 app 再升级后端"，或阶段 3 延后一个版本；
2. QR 里的 API key 即部署密钥，等同 `.env` 泄露面——接入页只对已登录 admin 展示；
3. 增量同步端点的 `since` 语义（updated_at 游标 vs id 游标）实施时定，参照 feed 现有 keyset 分页模式；
4. iOS 后台限制不再相关（刷新在服务端），app 只需前台/回前台时拉增量。
