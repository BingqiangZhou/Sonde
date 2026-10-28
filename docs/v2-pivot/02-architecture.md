# 02 · 目标架构（v2）

> 本文定义 v2 的最终形态。各 Phase 实施时以此为准；变更须回写。

## 1. 进程与流量

```
Flutter App（核心客户端）─┐
                         ├─→ nginx(:80/443) ─→ FastAPI backend(:8000) ─→ PostgreSQL 15
web/ 阅读站（SSR）───────┘         │                  │
（只经 HTTP 读 API）               │                  └→ Redis（缓存/锁/限流 + Celery broker）
                                  └─→ Celery worker(-B)：feed 刷新 / 转写 / 评分 / 摘要 / 三刊 / 清理
```

- backend 与 worker 同镜像两进程（沿用 v0 compose）。
- web 为 React Router SSR（自 ts-era 迁入 `web/`），只经 HTTP 调 backend，不直连 DB。

## 2. 数据模型变更

### 新增（alembic 025 起）

| 表 | 字段 | 说明 |
|---|---|---|
| `ai_analyses` | id、episode_id FK、score(0-100)、selected bool、reason、tags jsonb、category、title_zh、summary_zh、reason_zh、model、prompt_version、is_current、created_at | 每集判定追加式留史；`is_current` 标记最新 |
| `reports` | id、kind(daily\|weekly\|monthly)、report_key（daily/weekly=`YYYY-MM-DD`（周一）、monthly=`YYYY-MM`）、window_start/end、content jsonb、model、revision、generated_at；UNIQUE(kind, report_key) | 全局三刊；重生成 revision+1 |
| `ai_receipts` | id、service(llm\|transcription)、operation(score\|write\|report\|transcribe\|summary)、model、prompt_tokens、completion_tokens、audio_seconds、ok、error、duration_ms、created_at | 成本台账；失败也记，绝不抛给业务 |
| `user_favorites` | user_id、episode_id、created_at；UNIQUE(user_id, episode_id) | 收藏同步（替代 web localStorage 收藏与 is_user_favorited） |

### 恢复

- `users` ORM 模型（表已在库；补模型并对齐 024 后列集）。
- `user_sessions`（随 auth 域恢复重建：session_token、refresh_token、device_info、ip/ua、expires_at、is_active）。

### 淘汰

- `podcast_daily_reports` / `podcast_daily_report_items` → drop（被全局三刊取代）。
- `episode_highlights.is_user_favorited` → 废弃（由 user_favorites 承担，列保留不写或后续清理）。

### 保持不变

`subscriptions`（全局 feed 去重）、`user_subscriptions`、`podcast_episodes`、`podcast_episode_transcripts`、`transcription_tasks`、`podcast_playback_states`、`podcast_queues(_items)`、`ai_model_configs`、`system_settings`。

## 3. API 变更

### 恢复：`/api/v1/auth/*`（Phase B）

按 `backend/docs/AUTHENTICATION.md` 契约：register、login、refresh、me、logout、logout-all。新增变化：
- `REGISTRATION_OPEN`（默认 **false**）：关闭时 register 返回 403；管理员经面板/CLI 建号。
- forgot-password / reset-password：首版不做邮件，返回 501 提示走管理员重置。
- 登录/注册接口挂 slowapi 限流。

### 新增：`/api/v1/discover/*`（Phase C 后随面板/随 E 前置）

- `GET /api/v1/discover?q=&limit=` —— 后端多国（`ITUNES_COUNTRIES`，默认 CN,US）并发搜索 iTunes 并按 feedUrl 合并去重，标记 `subscribed`。
- `GET /api/v1/discover/charts?country=&limit=` —— 国家热门榜（名次 + 批量 lookup 换 feedUrl）。
- 出站定制：`ITUNES_DNS`（自定义解析，回退系统）/ `ITUNES_PROXY_URL`（HTTP 代理，优先于 DNS）；5 分钟内存缓存尊重限频。实现参考 ts-era `packages/backend/src/sources/itunes.ts`。

### 新增：`/api/v1/favorites`（Phase B）

- `GET /api/v1/favorites`（当前用户收藏单集列表）
- `PUT /api/v1/favorites/{episode_id}` / `DELETE /api/v1/favorites/{episode_id}`

### 新增：`/api/v1/site/*`（Phase D，公开读，供 web）

JSON 形状对齐 ts-era `/api/site/*`（web 迁移成本最小化）：
- `GET /api/v1/site/meta` —— 站点身份（industry/site）
- `GET /api/v1/site/episodes?limit=` —— 入选单集时间线（按发表倒序）
- `GET /api/v1/site/episodes/all?page=` —— 全部已分析单集分页（含落选：灰分+理由）
- `GET /api/v1/site/episodes/{id}` —— 详情：**audio_url、duration_seconds**、zh 三件套、score、category、transcript
- `GET /api/v1/site/reports/{kind}/latest`、`/{kind}/{key}`、`/{kind}?page=&size=`

### 改造：`/api/v1/podcasts/*` 鉴权（Phase B）

- `require_api_key` → `require_user`（JWT access token → user_id）。
- `X-API-Key`/Bearer-API_KEY 保留为**运维通道**：命中 `settings.API_KEY` 时映射为管理员用户（is_superuser），供面板与脚本使用。

### 管理面板扩展（Phase D）

Jinja2 面板新增：成本页（ai_receipts 汇总/最近明细）、报告页（三刊列表 + 手动触发）、单集诊断（转写/评分状态排查）、订阅页"发现"入口（复用 discover 接口）、用户管理（建号/重置密码/停用）。

## 4. 流水线设计

```
feed 刷新（Celery 每小时，per-user 计划判定）
  → 新集入库（全局去重：item_link）
  → 转写（现有六步：下载/ffmpeg/分块/转写/合并/回填）
  → 评分 analyze（新增，Phase C）：
      chatJson(prompt=score.md, 全文截断 10k 字符) → {score, reason, tags}
      → industry.selection.threshold_for(tier) 门槛判定
      → 过线才写作：chatJson(write.md, ≤30k 字符) → {title_zh, summary_zh, reason_zh}
      → ai_analyses 落库（is_current 翻转，事务）
  → 三刊成刊（新增，Phase C）：
      reports.daily 08:00 / reports.weekly 周一 08:30 / reports.monthly 1 日 08:30（Asia/Shanghai 窗口）
      窗口内 selected 单集（score DESC，按 kind 截断）→ 主编 prompt →
      {title, leadParagraph, highlights≤8, sections[taxonomy 序]}
      → upsert（UNIQUE(kind, report_key)，重生成 revision+1）
      另设每小时 catch-up 兜底漏刊
```

### 记账（Phase C）

- `chatJson` 与转写 provider 层统一写 `ai_receipts`（tokens / audio_seconds / ok / 耗时）。
- 任何记账失败只记日志，不阻塞业务。

### industry 定制层（Phase A 迁入骨架，Phase C 使用）

```
backend/app/industry/
  __init__.py        # 对外暴露 SITE / TAXONOMY / THRESHOLDS / INTEREST_PROFILE / threshold_for(tier)
  site.py            # 站点名/主题/tagline（web 与 app 共用）
  taxonomy.py        # 分类有序表（中文标签）
  selection.py       # tier 门槛（T1/T2 → 0-100）+ interest_profile（注入评分 prompt）
  prompts/           # *.md，自 ts-era industry/prompts 原样迁入（score/write/daily/weekly/monthly…）
```

- 渲染器：`{{var}}` 替换 + `{{> file}}` 包含；缺失值/文件**硬错误**；版本号 `name@hash8` 随渲染结果入库。
- prompt 文本永不内联进 Python 代码。

## 5. 多用户与成本控制

- feed/转写/评分/成刊**全局一次**（`subscriptions` 去重既有）；per-user 只有：订阅关系、播放状态、队列、收藏。
- 注册默认关闭；无邀请系统；`MAX_PODCAST_SUBSCRIPTIONS` 全局上限保留。
- 成本可观测：面板成本页 + receipts 台账。
- 报告与评分为全局"总编"视角——所有用户看到同一份三刊；个性化（per-user 日报）明确不在 v2 范围。

## 6. Web 阅读站（自 ts-era 迁入）

- 目录 `web/`（独立 npm 项目，解开原 workspace 耦合）；保留全部公开页面：首页 / 日/周/月三刊 / 全部动态 / 单集详情 / 收藏（改为登录同步或保持本地，首版保持 localStorage）/ changelog / about。
- 数据全部来自 `/api/v1/site/*`；原 `/admin` React 页面**不迁**（用 Jinja2 面板）。
- web 端播放首版不做（与 ts-era 一致：阅读 + 外链；App 承担播放）。
