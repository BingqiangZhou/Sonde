# Phase C · AI 评分与三刊成刊

> 状态：⬜ 未开始　|　前置：Phase B　|　下一步：Phase D

## 目标

把 ts-era 的核心流水线移植进 Python：转写完成 → LLM 评分（tier 门槛）→ 过线中文写作 → 全局日/周/月三刊自动成刊；所有付费调用入 `ai_receipts` 台账；旧 per-user 日报退役。

参考实现（ts-era 分支）：`packages/backend/src/{providers/llm.ts, pipeline/analyze.ts, reports/daily.ts, prompts/loader.ts+renderer.ts, util/time.ts+json.ts}` 与 `industry/prompts/*.md`、`industry/selection.ts`。逻辑照搬，语言翻译，**行为对齐**。

## 任务清单

### C1 数据表（alembic 026）

- [ ] `ai_analyses`（episode_id FK、score 0-100、selected、reason、tags jsonb、category、title_zh/summary_zh/reason_zh、model、prompt_version、is_current）
- [ ] `reports`（kind、report_key、window_start/end、content jsonb、model、revision、generated_at；UNIQUE(kind, report_key)）
- [ ] `ai_receipts`（service、operation、model、prompt_tokens、completion_tokens、audio_seconds、ok、error、duration_ms、created_at）
- [ ] drop `podcast_daily_reports` / `podcast_daily_report_items`；代码中同步删除旧日报服务/路由/任务（reports/daily 端点、generate-daily-podcast-reports beat）

### C2 provider 层

- [ ] `chat_json()`：基于 `core/ai_client.py` 封装——system+user 渲染 prompt、重试、**容错 JSON 提取**（剥 `<think>`/代码围栏/前后杂文，对齐 ts-era util/json.ts）、pydantic 校验、异常类型化（ProviderError）
- [ ] 记账钩子：chat_json 与 `transcription/transcriber.py` 每次调用写 `ai_receipts`（失败也记 ok=false；记账异常仅日志）
- [ ] 单测：JSON 容错提取、重试、记账行写入

### C3 prompt 渲染器与 industry 接线

- [ ] `app/industry/prompts_loader.py`：加载 + 渲染 `{{var}}`/`{{> file}}`；缺失值/文件抛硬错误；prompt_version=`name@hash8`
- [ ] 单测：变量替换、include、缺失报错、版本号稳定
- [ ] 核对 ts-era prompts 全套迁入（A 阶段已迁文件）：score/write/daily/weekly/monthly + includes

### C4 评分任务（analyze）

- [ ] Celery 任务 `analyze_episode(episode_id)`：读全文转录（`podcast_episode_transcripts`）→ 评分（截断 10k 字符）→ `threshold_for(tier)` 判定 → 过线写作（30k 字符）→ 事务写 `ai_analyses`（旧 is_current 翻 false）
- [ ] tier 来源：`subscriptions` 增列 `tier`（T1|T2，默认 T2，迁移并入 026）——ts-era 语义：T1 精选源门槛低、T2 普通源门槛高；订阅创建/编辑可设
- [ ] 接入点：转写任务完成回调处（`transcription/service.py` 完成分支）派发 analyze；另加每 30 分钟 sweep 兜底（对齐 ts-era analyze sweep）
- [ ] 单测：门槛判定、落选不写作、is_current 翻转、转录截断

### C5 三刊成刊

- [ ] `reports/service.py`：`generate_report(kind, report_key?, force)`——Asia/Shanghai 窗口计算（日/周（周一键）/月），窗口内 selected 单集（score DESC，按 kind 限额）→ 主编 prompt → {title, leadParagraph, highlights≤8, sections（taxonomy 序）} → upsert + revision+1
- [ ] Celery beat：reports.daily 08:00 / weekly 周一 08:30 / monthly 1 日 08:30（**显式沪时区**，吸取旧日报 19:30 UTC 教训）+ 每小时 catch-up 兜底
- [ ] 手动触发入口：面板（Phase D 做 UI，本阶段先留服务函数）
- [ ] 单测：日/周/月窗口计算、空窗口、revision 递增、taxonomy 分节顺序

### C6 端到端验收

- [ ] mock LLM/ASR（对齐 ts-era `scripts/dev/mock-llm.mjs` 思路，Python 实现一个本地 mock 或用 pytest monkeypatch）跑通：新集入库 → 转写（mock）→ 评分 → 写作 → 三刊生成
- [ ] 真实 feed + 真实 Key 冒烟一次（少量单集），核对 receipts 记账与成本页数据源可用

## 验收标准

1. C2/C3/C4/C5 单测全绿；ruff 通过。
2. mock 全链路：一集走完 转写→评分→（过线）写作→ai_analyses；三刊按时窗生成、revision 正确。
3. 旧日报表已删且无死引用（grep：daily_report 相关路由/任务/模型清理干净）。
4. 每次 LLM/转写调用在 `ai_receipts` 有行；记账失败不影响业务。

## 注意事项

- 时区：窗口计算全部 ZoneInfo("Asia/Shanghai")，DB 存 timestamptz（UTC）；测试覆盖跨月/跨周边界。
- `subscriptions.tier` 增列后，管理面板订阅编辑同步暴露 tier（轻改，D 阶段一并美化）。
- prompt 渲染的 include 路径一律相对 `app/industry/prompts/`。
