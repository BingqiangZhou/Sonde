---
name: parse-rss
description: 解析所有已订阅播客的 RSS feed，为新剧集写入 data/podcasts/<id>/episodes/*.json。由 GitHub Actions 每日定时执行。
---

# parse-rss

遍历 `data/podcasts/` 中所有 `subscribed: true` 的播客，抓取并解析其 RSS feed，为**新**剧集写入 episode meta。

## 何时使用

- GitHub Actions 每日 08:00 UTC 自动执行
- agent 手动触发：用户说"检查新剧集""解析一下订阅"时

## 如何执行

```bash
cd skills/parse-rss
pnpm refresh
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
