---
name: podcast-summarize
description: |
  Generate AI summaries and tags for podcast episodes using YOUR OWN capabilities (you are the LLM — no external API needed). Reads episode body text, you write a concise Chinese summary + tags, then writes back to markdown and json.

  Use this skill when:
  - User says "生成摘要" / "做总结" / "总结一下" / "summarize episodes" / "generate summary"
  - User wants AI summaries for pending episodes
  - User asks to process/summarize a specific podcast's episodes
  - After scrape-episode fetched content, to create the summaries
  - User mentions episodes are "pending" and need summaries
---

# podcast-summarize

为已抓取正文的剧集生成 AI 摘要和标签。

**关键点：你（agent）自己就是 LLM。** 你直接阅读剧集正文，用自己的理解生成摘要，不需要调用任何外部 API，不需要 LLM_API_KEY。

## 工作流程

### 单集处理

1. **读取待处理剧集**：运行以下命令拿到正文（替换 `<podcastId>` 和 `<episodeId>`）：

```bash
node --input-type=module -e "
import { prepareEpisode } from './skills/summarize/src/run.ts';
const r = await prepareEpisode('<podcastId>', '<episodeId>');
console.log(JSON.stringify(r, null, 2));
" 2>/dev/null || npx tsx -e "
import { prepareEpisode } from './skills/summarize/src/run.ts';
const r = await prepareEpisode('<podcastId>', '<episodeId>');
console.log(JSON.stringify(r, null, 2));
"
```

   或直接用文件工具读取 `data/podcasts/<podcastId>/episodes/<episodeId>.md` 的 `## 正文` 段落。

2. **你生成摘要**：基于读到的正文，生成：
   - 一段 **150-300 字的中文摘要**，提炼核心观点
   - **2-5 个标签**（简短词语，如"人工智能"、"科技"、"创业"）

3. **写回**：运行以下命令把摘要落盘（替换参数）：

```bash
node --input-type=module -e "
import { writeSummary } from './skills/summarize/src/run.ts';
const r = await writeSummary('<podcastId>', '<episodeId>', '<你生成的摘要>', ['标签1', '标签2']);
console.log(JSON.stringify(r));
" 2>/dev/null || npx tsx -e "
import { writeSummary } from './skills/summarize/src/run.ts';
const r = await writeSummary('<podcastId>', '<episodeId>', '<你生成的摘要>', ['标签1', '标签2']);
console.log(JSON.stringify(r));
"
```

   `writeSummary` 会原子写回 `.md`（插入 `## AI 摘要` 和 `## 标签` 段落）和 `.json`（更新 `summary_status: done` + `tags`），并重建索引。

### 批量处理

1. **查看待处理列表**：

```bash
pnpm --filter @podcastinsight/skill-summarize refresh
```

   这会列出所有 `summary_status: pending` 的剧集。

2. **逐集处理**：对列表中的每集，重复"单集处理"流程。建议每次处理 3-5 集，避免一次性过多。

## 前置条件

- 剧集已抓取正文（`scrape_status: done`），即 `.md` 文件里有 `## 正文` 段落
- 剧集状态为 `summary_status: pending`

## 摘要质量要求

- **忠实原文**：基于正文内容，不编造
- **中文摘要**：150-300 字，提炼核心观点而非复述细节
- **标签精炼**：2-5 个，反映主题（不是人名、不是日期）
- **客观中立的语气**

## 幂等

已 `done` 的剧集会返回 `already-done`，不会重复处理。

## 输出格式契约（writeSummary 已自动保证）

写回的 `.md` 结构：
```
---
episode_id: "..."
title: "..."
summary_status: "done"
generated_at: "..."
model: "agent"
---

## AI 摘要
<你生成的摘要>

## 标签
#标签1 #标签2

## 正文
<原始正文>
```
