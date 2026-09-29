# 本地优先架构重设计：app 为真相源，云端只留 AI 工作流

- 日期：2026-08-21
- 状态：**已取消（2026-08-21 最终定夺：去掉本地模式，保持现有 app + 全功能后端架构）**
- 定夺：不做平台、个人自用。**云端（后端）只保留转录与 AI 总结工作流，其余功能全部本地化到 Flutter app。**
- 取消原因：同日多次方向迭代后的最终决定——维持现状架构，定时获取更新/AI 总结由后端 celery beat 服务端定时承担（比移动端后台调度可靠）。本方案仅作思路存档。

## 一、核心思想

架构翻转：现在"后端是真相源、app 是视图"；改造后 **"app 是真相源（本地 Drift/SQLite），后端退化为无状态 AI 算力服务"**。

```
┌─────────────── Flutter app（真相源 + 全部业务）───────────────┐
│ 订阅管理 │ RSS 抓取/解析 │ 剧集元数据 │ 播放/下载 │ 队列/历史    │
│ 日报编排 │ 转写结果/摘要存储 │ 设置（含服务器地址+API key）      │
└──────────────┬──────────────────────────────────────────────┘
               │ 仅两类调用（API key 认证）
               ▼
┌───────── 云端后端（AI 工作流服务）─────────┐
│ 转录管道：URL 下载 → 分段 → 转写 API → 文本 │
│ 摘要管道：prompt 组装 → LLM 调用 → 结果     │
│ AI key 管理（ai_model_configs + 管理页）    │
│ 任务表（暂存结果，TTL 清理）                │
└────────────────────────────────────────────┘
```

后端不再知道"播客/订阅/用户"的存在——它只认 `audio_url` 和 `待总结文本`。

## 二、后端瘦身设计

### 保留（改造后）

| 模块 | 说明 |
|------|------|
| `core/` | config/db/redis/celery/auth(仅 API key)/中间件/限流/日志 全保留 |
| `domains/ai/` 整域 | model configs、key_resolver、invocation、model_manager 原样保留 |
| 转录执行内核 | 从 podcast 域拆出：按 URL 下载音频 → 分段 → 调转写 API → 重试 → 文本。**去 episode 耦合**（输入由 API 提供，不从 podcast 表读） |
| 摘要执行内核 | 同上：接受原文+任务类型 → prompt 模板 → LLM → 结果。**去 pending 扫库模式** |
| `admin/` 只留 apikeys 页 | AI 模型 key 增删改测（登录机制不变：API_KEY→HMAC cookie）；新增可选的任务列表页（观测转写队列） |
| 健康检查 | `/api/v1/health`、`/ready` 保留 |

### 新增：任务 API（后端唯一面向 app 的业务接口）

```
POST /api/v1/jobs/transcriptions
  请求 {audio_url, title?, language?, model_hint?}
  响应 {job_id, status: "queued"}
GET  /api/v1/jobs/transcriptions/{job_id}
  响应 {status: queued|running|succeeded|failed,
        transcript_text?, error?, created_at}
POST /api/v1/jobs/summaries
  请求 {source_text, task_type: episode_summary|daily_brief, title?, context?}
  响应 {job_id, status}          # LLM 调用 10~30s，统一走异步任务
GET  /api/v1/jobs/summaries/{job_id}
  响应 {status, content?, error?}
```

- 认证：`X-API-Key` / Bearer（单用户部署密钥，沿用现有 `require_api_key` 的 key 分支即可）；
- 任务表：`transcription_jobs` / `summary_jobs`（自包含上下文：audio_url/title 冗余存储，不引用任何播客表）；
- **结果暂存 TTL 30 天**：app 拉取后落本地库为真相；过期由维护任务清理（唯一的周期任务）；
- 下载由后端完成（v1 不做文件上传）：播客 enclosure 基本是公开 CDN 直链，app 传 URL 即可；签名过期链接是少数场景，留作 v2 上传通道；
- SSRF 注意：job 提交需 API key，攻击面已收窄；`SecureRSSParser` 同源的私网地址校验逻辑应复用到音频 URL 校验上。

### 删除

| 模块 | 处置 |
|------|------|
| `domains/podcast/` 大部 | routes×6、repositories×11、services、SecureRSSParser、platform_detector、models 中订阅/剧集/队列/播放/日报全部删除；转写/摘要执行内核拆走保留 |
| `domains/auth/`（JWT 多用户） | 整域删除：无账号概念，单 API key 足够；users 表随最终迁移 drop |
| admin 的 dashboard/settings/subscriptions 页 | 删除（对应服务同删） |
| beat 周期调度 | 订阅刷新/日报/扫库任务全消失；仅剩任务清理一个周期 job——直接用 worker 内嵌 beat 跑（现状 `-B` 正好），独立 beat 容器可从 compose 移除 |
| 数据库表 | 最终迁移 drop：subscriptions/user_subscriptions/podcast_episodes/playback_states/queues/report*/users 等；保留 ai_model_configs，新增两张 job 表 |

### 部署形态变化

docker compose：postgres + redis + backend + worker（内嵌 beat）+ 可选 nginx（需要 TLS/公网暴露时才挂）。5→4 容器（beat 移除、nginx 可选化）。PG 保留（asyncpg/Celery 基建现成，不为省事降级 SQLite）。

## 三、前端本地化设计

### Drift 库升格为真相源（新增表）

```
feeds            id, rss_url(unique), title, author, artwork_url,
                 last_fetched_at, platform, etag/last_modified
subscriptions    id, feed_id, added_at, is_archived
episodes         id, feed_id, guid(unique per feed), title, description,
                 pub_date, duration, audio_url, image_url, is_downloaded
transcripts      episode_id(unique), status(pending|submitted|running|done|failed),
                 job_id, submitted_at, attempts, text, language, model, updated_at
summaries        episode_id(unique), status(同上), job_id, submitted_at, attempts,
                 content(json), model, updated_at
briefs           date(unique), content, generated_at
playback_states  episode_id(unique), position, updated_at
queue_items      episode_id, position
settings         key, value          # 服务器地址、语言偏好等
```

（`DownloadTasks`/`EpisodesCache`/`ResponseCache` 现有缓存表保留/复用。）

### 新建本地引擎（repository 接口的 Local 实现）

1. **RSS 引擎**：http 抓取（UA/超时/大小上限/etag 协商）+ 安全解析（实体炸弹防护、字段长度截断）+ `platform_detector` 的 Dart 移植（喜马拉雅/小宇宙 URL 规整）；
2. **下载管理**：现有 `audio_download_service` + `DownloadTasks` 直接复用；
3. **播放**：本地文件优先，未下载直连 `audio_url` 流播（现行为不变）；
4. **云客户端**：新的极简 jobs 客户端（提交/轮询/取回），替换现有大部分 `@RestApi` 面；
5. **转写/摘要编排**（app 侧状态机）：详情页"转写"按钮 → 提交 job（带 audio_url）→ 后台轮询 → 取回文本落 `transcripts` 表；摘要/日报同理；
6. **日报编排**：workmanager 晨间触发 → 本地收集昨日新集/已听数据 → 组装上下文 → 调 `jobs/summaries(task_type=daily_brief)` → 落 `briefs` 表（**编排本地化，算力云端**——与"云端只留 AI 工作流"不矛盾）；
7. **后台刷新**：见下节"定时同步设计"。

### 定时同步设计（获取更新 + AI 总结的本地编排）

**架构红利**：长耗时（转写/总结）在云端跑，本地定时任务只剩"检查 RSS 新集 + 领取结果"——每次几秒、几百 KB，iOS 的 ~30s 后台预算都够。

**三层触发**（三层跑的是同一个 `podcastSync()`）：

| 层 | 机制 | 定位 |
|----|------|------|
| 定时后台 | workmanager PeriodicWork 6~12h（Android 准时；iOS BGTaskScheduler 尽力） | 锦上添花 |
| **前台补做** | app 启动/回前台时 last_synced_at 超阈值即同步 | **真正保底**，iOS 主力 |
| 事件驱动 | 下拉刷新/新订阅/打开详情页顺带检查 | 免费加成 |

把"定时"语义从**日历时间**换成**使用时间**：用户打开 app 的那一刻数据必然新鲜。

**同步任务状态机**（单入口）：

```
① 到期检查  feeds WHERE last_fetched_at + frequency < now（并发≤3）
② RSS 拉取  etag/last-modified 协商，未变零成本跳过
③ 差异入库  按 guid diff 新剧集
④ 提交任务  自动总结的新剧集：无转写 → POST /jobs/transcriptions
⑤ 领取结果  轮询未完结 job → 转写完 → POST /jobs/summaries → 摘要完落库
```

④⑤ 为两级链（转写→总结），**跨会话续接**：状态长在 `transcripts`/`summaries` 表的 job 跟踪列上（status/job_id/submitted_at/attempts），app 被杀重启不丢；`failed && attempts<3` 下次同步重提；episode_id 唯一约束保证幂等（防重复付费）。

**频率**：全局默认 12h，设置页三档（每天/12h/6h，语义沿用后端 `UpdateFrequency`），单订阅可覆盖。

**日报衔接**：晨间 `briefs` 无昨日行 → 触发同步+补链再生成（Android 大概率夜间已完成；iOS 首开 2 秒转圈）。

**不做推送**（FCM/APNs）：轮询领取模式下结果晚知几小时无损失；若要"转写完成"提示，本地通知零服务端成本，留 v2。

### UI 变化

- `auth/` feature（登录/注册）**删除**，替换为"服务器配置页"：后端地址 + API key（`flutter_secure_storage`），复用现有 `server_health_service` 连通性检查；
- `settings/`/`profile/` 收编：设置项读写全走本地；AI key 仍由 Web 管理页配置（保持既有决策）；
- `podcast/` feature 页面骨架不动，数据源切到 Local repository。

## 四、既有数据迁移（一次性）

后端 → 本地：
1. **订阅**：用现成的 OPML 导出（`subscriptions_opml_service`）→ app 导入（RSS 重新拉取元数据）；
2. **播放历史/队列**：加一个临时导出端点吐 JSON → app 导入；
3. **转写文本/摘要**：同 JSON 导出 → app 落库（避免重复付费）；
4. 导出工具放在瘦身的过渡版本里，跑完即弃。

## 五、实施阶段（每阶段独立可发布）

| 阶段 | 内容 | 验收 |
|------|------|------|
| 1 后端任务 API | jobs 两接口 + 转写/摘要内核去 episode 耦合 + job 表迁移；旧接口并存 | pytest + curl 提交/轮询全链路；Docker 冒烟 |
| 2 前端本地化 | Drift 新表 + RSS 引擎 + Local repository + 服务器配置页；订阅/剧集/播放/队列切本地；转写摘要切 jobs API | flutter test + 模拟器全功能摸底 |
| 3 后端删除 | 删 podcast 域/auth 域/admin 三页 + drop 表迁移 + compose 去 beat、nginx 可选 | pytest 全绿；`docker compose up -d` 四容器健康 |
| 4 迁移工具 + 日报 | OPML/JSON 导入工具；日报本地编排 + 晨间任务 | 真实数据迁移演练一遍 |

## 六、风险与开放问题

1. **audio_url 过期**（v1 无上传通道）：播客 enclosure 极少签名过期；出现时重新拉 feed 刷新 URL 再提交；
2. **job 结果 30 天未取**：重新转写烧钱——app 取回即落库，风险窗口很小；可在管理页加"未领取任务"提醒（可选）；
3. **iOS 后台限制**：日报/刷新时效降级为"打开 app 时补做"，可接受；
4. **两套 AI 调用路径并存期**（阶段 1-2 之间）：后端旧管道与新 jobs 并存，注意 key_resolver 只有一份不会双花；
5. **回滚**：阶段 3 之前旧架构完整保留，随时可退。
