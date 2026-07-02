---
name: fetch-rankings
description: |
  Fetch the Chinese podcast Top rankings from xyzrank.com and write to data/rankings/latest.json.

  Use this skill when:
  - User says "更新排行榜" / "抓排行" / "刷新排行" / "fetch rankings" / "refresh rankings"
  - User asks to get/update podcast ranking data
  - User mentions the rankings data is stale or missing
  - User wants to see the latest Top podcasts
---

# fetch-rankings

从 xyzrank.com 抓取中文播客排行榜（Top 1000+），规范化后写入 `data/rankings/latest.json`。

## 如何执行

从仓库根目录运行：

```bash
pnpm --filter @podcastinsight/skill-fetch-rankings refresh
```

抓取约需 30-60 秒（分页拉取全量数据）。

## 输入

无。全量抓取。

## 输出

- `data/rankings/latest.json` — 完整排行榜快照（整体覆写）
- `data/index.json` — 自动重建（更新 rankings_updated_at）

## 失败处理

抓取失败时保留上一次快照，不删除旧数据。退出码 1。

## 幂等

整体覆写，重复执行安全。
