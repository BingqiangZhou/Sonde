---
name: release
description: 发布新版本 - 生成CHANGELOG（含中英双语AI摘要）、更新版本号、创建tag并推送。用法：/release <version>（如 /release 1.0.0）
---

# Release Workflow Command

当收到 `/release <版本号>` 命令时，按以下步骤自动执行发布流程：

## 步骤1: 生成 CHANGELOG 骨架

> ⚠️ CHANGELOG.md 已存在时**必须用 `--unreleased --prepend`，切勿用 `-o`**：
> `-o` 按模板全量重生成，会把历史版本段里已注入的 AI 摘要抹回 `<!-- AI_SUMMARY -->` 占位符。

1. 记录生成前的版本段数：`grep -c '^## \[' CHANGELOG.md`
2. 生成新版本段（cliff.toml 模板会在版本标题后输出 `<!-- AI_SUMMARY -->` 占位符）：
   - TS 重写后的首次发布（v1.0.0）：`git cliff --tag v<版本号> d04e84e1..HEAD --unreleased --prepend CHANGELOG.md`
     （本地 v0.x 标签已删除，必须显式限定范围 `d04e84e1..HEAD` = TS 重写链，否则会把 Python/Flutter 时代的提交一并列出）
   - 后续发布（本地已存在上一个 v1.x tag）：`git cliff --tag v<版本号> --unreleased --prepend CHANGELOG.md`
   - 注意：`--prepend` 在 git-cliff 2.x 必须搭配 `--unreleased` 或 `--latest`，否则报 ArgumentError
3. 防护校验：生成后版本段数必须 = 生成前 + 1。若不等（说明历史被覆盖或写入异常），
   立即 `git checkout -- CHANGELOG.md` 恢复，检查命令后重试

## 步骤1.5: 注入中英双语 AI 摘要

把新版本段顶部的 `<!-- AI_SUMMARY -->` 占位符替换为中英双语摘要。摘要由 agent 基于该版本段的
分组与条目内容自己撰写（中文在前、英文在后，内容对应，概括最核心的功能/修复/重构及影响端），格式：

```markdown
> <2-3 句中文自然语言总结>
>
> <2-3 English sentences covering the same points>
>
> 共 <N> commits：<分组名> <n> | <分组名> <n> | ...
```

- 统计行只写一次，分组名用渲染后的英文名称（🚀 Features、🐛 Bug Fixes、📚 Documentation、
  🚜 Refactor、🎨 Styling、⚡ Performance、🧪 Testing、⚙️ Miscellaneous Tasks），与下方条目分组一致
- N = 该版本段的条目总数；各分组数字 = 对应 `###` 小节的条目数，只列非零分组
- Full diff 链接不用写在摘要里——版本标题行已带 compare 链接
- 用 Edit 工具做精确替换，保持占位符前后的空行不变
- 替换后校验：`grep -c 'AI_SUMMARY' CHANGELOG.md` 必须为 0
- 手工增补/修改条目时，完整 commit 哈希必须取自 `git rev-parse <短哈希>`，禁止凭记忆拼接
  （v1.1.0 曾因手写哈希错误导致链接 404，事后修正）

## 步骤2: 更新版本号
1. 读取根目录 `package.json` 的 `version` 字段（当前 1.0.0）
2. 更新为用户提供的新版本号（无构建号）

## 步骤3: 创建提交
创建 commit，message 格式为：
```
chore(release): update version to <版本号> and generate changelog
```

## 步骤4: 推送提交
将提交推送到远程仓库

## 步骤5: 创建并推送 Tag
创建 tag（格式: v<版本号>），例如: v1.0.0，推送到远程仓库。
推送 `v*` tag 后 `.github/workflows/release.yml` 自动触发：typecheck/test/build →
git-cliff 生成该版本说明 → 创建 GitHub Release（无需手动创建）。
发版后用 `https://api.github.com/repos/BingqiangZhou/Sonde/actions/runs?per_page=3` 或
仓库 Actions 页确认运行成功、Release 已生成。

注意：**tag 必须指向包含 workflow 文件的提交**（首次给仓库加 workflow 后发版时，先推 workflow 提交再打 tag）。

## 示例
输入: `/release 1.0.0`
- 当前版本: `1.0.0`（package.json）
- 新版本: `1.0.0`
- Tag: v1.0.0
- Commit message: `chore(release): update version to 1.0.0 and generate changelog`
