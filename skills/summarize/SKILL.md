---
name: summarize
description: 为已抓取正文的剧集生成 AI 摘要和标签，写回 data/podcasts/<id>/episodes/*.md 与 *.json。由 agent 实时调用，需要 LLM_API_KEY。
---

# summarize

读取 pending 剧集的正文，调用 LLM 生成中文摘要和标签，写回 markdown 和 episode meta。

## 何时使用

- **由 agent 实时调用**（不在 CI 定时中）
- 用户说"生成摘要""处理 pending 剧集""给 XX 播客最近的剧集做摘要"时
- 不建议大批量调用（LLM 成本）；可先用 parse-rss + scrape-episode 准备好素材

## 前置条件

- 环境变量 `LLM_API_KEY` 必须设置（本地 .env 或运行环境注入）
- 可选：`LLM_BASE_URL`（默认 OpenAI，可指向兼容网关）、`LLM_MODEL`（默认 gpt-4o-mini）

## 如何执行

```bash
# 批量处理所有 pending 剧集
cd skills/summarize
pnpm run

# 处理单集
pnpm run -- --episode=<podcastId>/<episodeId>
```

## 输入

`scrape_status: done` 且 `summary_status: pending` 的剧集，及其 `.md` 中的 `## 正文`。

## 输出

- 在 `.md` 中插入 `## AI 摘要` 和 `## 标签` 段落，更新 frontmatter `summary_status: done`
- 在 `<eid>.json` 中更新 `summary_status: done` 和 `tags`
- 重建 `data/index.json` 和 `data/search-index.json`

## LLM 接口

使用 OpenAI 兼容的 chat completions 接口。System prompt 要求严格返回 `{"summary","tags"}` JSON。

## 失败处理

单集失败标记 failed 但不影响其他集；未抓取正文的剧集标记 skipped。

## 幂等

已 done 的剧集不重复处理。
