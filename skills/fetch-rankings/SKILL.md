---
name: fetch-rankings
description: 从 xyzrank.com 抓取中文播客 Top 排行榜，写入 data/rankings/latest.json。由 GitHub Actions 每周定时执行，也可手动触发。
---

# fetch-rankings

抓取 xyzrank.com 的播客排行榜（Top 1000），规范化后写入 `data/rankings/latest.json`。

## 何时使用

- GitHub Actions 每周一 08:00 UTC 自动执行
- agent 手动触发：用户说"更新排行榜""抓一下排行"时
- 排行榜数据过期需要刷新时

## 如何执行

```bash
cd skills/fetch-rankings
pnpm refresh
```

## 输入

无。全量抓取。

## 输出

- `data/rankings/latest.json` — 完整排行榜快照（整体覆写）
- `data/index.json` — 自动重建（更新 rankings_updated_at）

## 失败处理

抓取失败时保留上一次快照，不删除旧数据。退出码 1。

## 幂等

整体覆写，重复执行安全。
