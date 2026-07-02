---
name: scrape-episode
description: 抓取 pending 剧集的网页正文，写入 data/podcasts/<id>/episodes/*.md。通常在 parse-rss 之后执行。
---

# scrape-episode

遍历所有 `scrape_status: pending` 的剧集，抓取其 `link` 网页，提取正文写入对应 `.md` 文件。

## 何时使用

- 在 parse-rss 之后链式执行（抓完 RSS 发现新剧集后顺带抓正文）
- agent 触发：用户说"抓正文""处理新剧集内容"时
- 命令行手动执行

## 如何执行

```bash
cd skills/scrape-episode
pnpm refresh
```

## 输入

`data/podcasts/*/episodes/*.json` 中 `scrape_status: pending` 的剧集。

## 输出

- 成功：写 `episodes/<eid>.md`（frontmatter + `## 正文`），更新 `scrape_status: done`
- 失败：`scrape_status: failed`，不写 .md（摘要步骤会跳过）
- 重建 `data/index.json`

## 正文提取

简易 readability：剥离 script/style/nav，优先 article/main，提取 h*/p/li 段落文本，截断 8000 字符。

## 幂等

已 done/failed 的剧集跳过；已存在的 .md 不重复写。
