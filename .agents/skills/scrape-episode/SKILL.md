---
name: scrape-episode
description: |
  Scrape web page content for pending episodes and write to markdown files. Extracts main article text from episode links.

  Use this skill when:
  - User says "抓正文" / "抓剧集内容" / "处理正文" / "scrape episodes" / "fetch episode content"
  - After parse-rss discovered new episodes, to fetch their full text
  - User wants to prepare episode content for summarization
  - User mentions episodes are pending and need content extraction
---

# scrape-episode

遍历所有 `scrape_status: pending` 的剧集，抓取其 `link` 网页，提取正文写入对应 `.md` 文件。

## 前置条件

已运行 parse-rss，存在 `scrape_status: pending` 的剧集（即刚发现的新剧集）。

## 如何执行

从仓库根目录运行：

```bash
pnpm --filter @podcastinsight/skill-scrape-episode refresh
```

## 输入

`data/podcasts/*/episodes/*.json` 中 `scrape_status: pending` 的剧集。

## 输出

- 成功：写 `episodes/<eid>.md`（frontmatter + `## 正文`），更新 `scrape_status: done`
- 失败：`scrape_status: failed`，不写 .md（summarize 会跳过）
- 重建 `data/index.json`

## 正文提取

简易 readability：剥离 script/style/nav，优先 article/main，提取 h*/p/li 段落文本，截断 8000 字符。

## 幂等

已 done/failed 的剧集跳过；已存在的 .md 不重复写。
