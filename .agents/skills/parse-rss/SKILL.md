---
name: parse-rss
description: |
  Parse RSS feeds of all subscribed podcasts and discover new episodes. Writes new episode metadata to data/podcasts/<id>/episodes/*.json.

  Use this skill when:
  - User says "检查新剧集" / "解析订阅" / "发现新剧集" / "parse rss" / "check new episodes"
  - User wants to pull latest episodes from subscribed podcasts
  - After subscribing a new podcast to fetch its episodes
  - User asks to update episode lists
---

# parse-rss

遍历 `data/podcasts/` 中所有 `subscribed: true` 的播客，抓取并解析其 RSS feed，为**新**剧集写入 episode meta。

## 前置条件

至少有一个播客的 `data/podcasts/<id>/meta.json` 设置了 `subscribed: true` 且填了 `rss_feed_url`。

## 如何执行

从仓库根目录运行：

```bash
pnpm --filter @podcastinsight/skill-parse-rss refresh
```

## 输入

读取 `data/podcasts/*/meta.json` 中 `subscribed: true` 的播客及其 `rss_feed_url`。

## 输出

- 对每个新剧集：`data/podcasts/<id>/episodes/<eid>.json`（`summary_status: pending`）
- 重建 `data/index.json`

## 剧集 ID 计算

优先用 RSS `<guid>`；缺失时用 `audio_url` 的 SHA-1 前 12 位。保证幂等。

## 失败处理

单个播客 RSS 解析失败不影响其他播客；错误收集后汇总输出，退出码 1。

## 幂等

按 episode id 判断存在性，已存在的剧集跳过，只写增量。
