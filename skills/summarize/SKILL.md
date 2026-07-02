---
name: summarize
description: 摘要读写工具包。提供 prepareEpisode（读正文）、writeSummary（写回摘要）、listPending（列出待处理）三个函数，供 agent 在对话中生成摘要后调用。本身不调用任何外部 LLM API。
---

# summarize（代码包）

这是摘要技能的代码实现包。注意：**agent 发现入口在 `.agents/skills/podcast-summarize/SKILL.md`**，本文件是代码包的说明。

## 设计

本 skill **不调用任何外部 LLM API**。摘要由 agent 自身能力生成。本包只提供三个工具函数：

| 函数 | 职责 |
|------|------|
| `prepareEpisode(pid, eid)` | 读取剧集正文，返回 `{ ok, title, body }` 给 agent |
| `writeSummary(pid, eid, summary, tags)` | 接收 agent 生成的摘要，原子写回 `.md` + `.json` + 重建索引 |
| `listPending()` | 列出所有 `summary_status: pending` 的剧集 |

## 如何执行（CLI）

```bash
# 列出待处理剧集（辅助 agent 和人工查看）
pnpm --filter @podcastinsight/skill-summarize refresh
```

CLI 模式只列出 pending 列表，**不生成摘要**。摘要生成由 agent 在对话中完成。

## 输出格式契约

writeSummary 写回的 `.md` 结构（下游 index-builder 和前端依赖此格式）：

```
---
episode_id: "..."
title: "..."
summary_status: "done"
generated_at: "..."
model: "agent"
---

## AI 摘要
<摘要>

## 标签          （仅当 tags 非空）
#tag1 #tag2

## 正文
<原始正文>
```

## 幂等

已 done 的剧集返回 `already-done`，不会重复处理。
