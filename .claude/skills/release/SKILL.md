---
name: release
description: 发布新版本 - 生成中英双份 CHANGELOG（含 AI 摘要）、更新版本号、创建 tag 并推送，GitHub Actions 自动发布双语 Release。用法：/release <version>（如 /release 1.1.0）
---

# Release Workflow Command

当收到 `/release <版本号>` 命令时，按以下步骤自动执行发布流程。

项目维护两份更新日志：`CHANGELOG.md`（中文版）与 `CHANGELOG_EN.md`（英文版）。
Release 正文由 GitHub Actions 从这两份文件提取对应版本段落拼装（中文段 + English 段），因此
**两份文件的新版本段必须在推送 tag 前完全就位**。

## 步骤1: 生成 CHANGELOG 骨架（两个文件）

> ⚠️ 已存在时**必须用 `--unreleased --prepend`，切勿用 `-o`**：
> `-o` 按模板全量重生成，会把历史版本段里已注入的 AI 摘要抹回 `<!-- AI_SUMMARY -->` 占位符。

1. 记录生成前的版本段数：`grep -c '^## \[' CHANGELOG.md` 与 `grep -c '^## \[' CHANGELOG_EN.md`
2. 生成新版本段（两份配置的模板一致，仅分组名/头部语言不同）：
   - 英文版：`git cliff --config cliff.toml --tag v<版本号> --unreleased --prepend CHANGELOG_EN.md`
   - 中文版：`git cliff --config cliff.zh.toml --tag v<版本号> --unreleased --prepend CHANGELOG.md`
   - 注意：`--prepend` 在 git-cliff 2.x 必须搭配 `--unreleased` 或 `--latest`，否则报 ArgumentError
3. 防护校验：两个文件的版本段数都必须 = 生成前 + 1。若不等（说明历史被覆盖或写入异常），
   立即 `git checkout -- CHANGELOG.md CHANGELOG_EN.md` 恢复，检查命令后重试

## 步骤1.5: 注入 AI 摘要（各写各的语言）

两个文件新版本段顶部的 `<!-- AI_SUMMARY -->` 占位符分别替换为对应语言的摘要。
摘要由 agent 基于该版本段的分组与条目内容自己撰写（内容对应，互为翻译），格式：

```markdown
> <2-3 句自然语言总结（中文版用中文 / 英文版用 English）>
>
> 共 <N> commits：<分组名> <n> | <分组名> <n> | ...
```

- 中文版统计行：`共 N 个提交：🚀 新功能 n | 🐛 问题修复 n | ...`（中文分组名）
- 英文版统计行：`N commits: 🚀 Features n | 🐛 Bug Fixes n | ...`（English 分组名）
- N = 该版本段的条目总数；各分组数字 = 对应 `###` 小节的条目数，只列非零分组；
  **数字必须与下方实际条目数一致**（v1.0.1 曾因换 tag 重发未同步统计行而写错为 13/实际 57）
- Full diff 链接不用写在摘要里——版本标题行已带 compare 链接
- 用 Edit 工具做精确替换，保持占位符前后的空行不变
- 替换后校验：`grep -c 'AI_SUMMARY' CHANGELOG.md CHANGELOG_EN.md` 两文件都必须为 0
- 手工增补/修改条目时，完整 commit 哈希必须取自 `git rev-parse <短哈希>`，禁止凭记忆拼接
  （v1.1.0 曾因手写哈希错误导致链接 404，事后修正）

## 步骤1.6: 翻译中文版条目

英文版条目保持 commit message 原文；中文版需把新版本段内的每条 entry 翻译成中文：

- 分组标题已是中文（cliff.zh.toml 的分组名），条目正文 = 翻译后的 message
- 保留 `*(scope)*` 前缀与 `([hash](链接))` 尾部原样，只翻译中间的 message 文本
- 专名/模块名（React Router、Drift、pg-boss、sidecar 等）保留原文

## 步骤2: 更新版本号

1. 读取根目录 `package.json` 的 `version` 字段
2. 更新为用户提供的新版本号（无构建号）

## 步骤3: 创建提交

创建 commit，message 格式为：
```
chore(release): update version to <版本号> and generate changelog
```
（`chore(release)` 前缀会被 cliff 跳过，不会出现在任何版本的 changelog 里；
发版相关的补录提交也一律用 `chore(release):` 开头）

## 步骤4: 推送提交

将提交推送到远程仓库

## 步骤5: 创建并推送 Tag

创建 tag（格式: v<版本号>），例如: v1.1.0，推送到远程仓库。
推送 `v*` tag 后 `.github/workflows/release.yml` 自动触发：typecheck/test/build →
从 CHANGELOG.md / CHANGELOG_EN.md 提取该版本段落拼成中英双语正文 → 创建 GitHub Release。
发版后用 `https://api.github.com/repos/BingqiangZhou/Sonde/actions/runs?per_page=3` 或
仓库 Actions 页确认运行成功、Release 正文包含 🇨🇳 中文 与 🇬🇧 English 两段。

注意：**tag 必须指向包含最新 workflow 文件与两份 CHANGELOG 的提交**（首次加 workflow 后发版时，
先推 workflow 提交再打 tag）。

## 示例
输入: `/release 1.2.0`
- 当前版本: 1.1.0（package.json）
- 新版本: 1.2.0
- Tag: v1.2.0
- Commit message: `chore(release): update version to 1.2.0 and generate changelog`
