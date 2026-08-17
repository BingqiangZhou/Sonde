# PodcastInsight v2 文档与代码全面清理

**日期**: 2026-05-30
**状态**: Approved

## 背景

PodcastInsight v2 迁移已完成（纯 Next.js 全栈应用），但项目中残留 v1 时代的文档、CSS 和未使用组件，以及部分文档描述与实际代码不一致。需要全面清理。

## 发现的问题

| # | 问题 | 类型 | 影响 |
|---|------|------|------|
| 1 | README.md 项目结构列出不存在的 `hooks/` 目录 | 文档不准确 | 误导开发者 |
| 2 | CLAUDE.md 架构图列出不存在的 `hooks/` 目录 | 文档不准确 | 误导开发者 |
| 3 | globals.css 有 ~200 行 v1 遗留代码 | 死代码 | 增加维护负担 |
| 4 | `search-bar.tsx` 未被任何页面引用 | 死代码 | 增加维护负担 |
| 5 | docs/ 中有 2 个 v1 时代的过期 spec | 过期文档 | 混淆当前架构 |
| 6 | CHANGELOG.md 停留在 v1.0.0 | 缺失文档 | 无法追溯 v2 变更 |

## 设计

### 1. 修正 README.md

移除项目结构树中不存在的 `hooks/` 目录行。所有 React hooks 实际集中在 `lib/queries.ts`（TanStack Query hooks）。

### 2. 修正 CLAUDE.md

- 移除架构图中 `hooks/` 目录行
- 在 lib/ 描述中补充说明 hooks 集中在 `lib/queries.ts`

### 3. 清理 globals.css

移除以下 v1 遗留内容：

**CSS 变量**（12 行）：
- `:root` 中的 `--player-bg/fg/muted/accent/track/buffered`
- `.dark` 中的 `--player-bg/fg/muted/accent/track/buffered`
- `@theme inline` 中的 `--color-player-*` 映射

**音频播放器样式**（~50 行）：
- `input[type="range"].audio-slider` 及其伪元素样式

**动画**（~20 行）：
- `@keyframes equalizer-1/2/3`
- `@keyframes slide-up`

**播放器组件样式**（~45 行）：
- `.progress-tooltip` 及其变体
- `.player-shadow-top`
- `.animate-slide-up`

**Shownotes prose 样式**（~65 行）：
- `.shownotes-content` 及其所有子元素样式

**保留**：所有 TailwindCSS 主题变量、sidebar 变量、scrollbar 样式、fade-in/pulse-soft 动画、card-hover-lift、stagger delays。

### 4. 移除未使用组件

- 删除 `frontend/src/components/search-bar.tsx`

### 5. 归档 v1 文档

- 创建 `docs/superpowers/specs/archive/` 目录
- 移动以下文件到 archive/：
  - `2026-04-22-episode-detail-redesign.md`
  - `2026-04-22-episode-detail-implementation-plan.md`

### 6. v2.0.0 CHANGELOG 条目

在 CHANGELOG.md 顶部添加 v2.0.0 条目，基于 git log `e34ba66e..93464756` 的 commit 记录。

**Highlights**: PodcastInsight v2.0.0 — 架构全面升级为纯 Next.js 全栈应用，移除 FastAPI 后端，以 Get笔记 OpenAPI 作为核心数据引擎。集成 xyzrank 播客排行榜、RSS feed 解析、AI 摘要生成、知识库管理和语义搜索。

分类包含：
- 🚀 Features：v2 全部页面和功能
- 🚜 Refactor：后端移除、架构迁移
- 📚 Documentation：文档和配置更新

## 交付方式

所有变更在一次 commit 中完成：
```
docs: update documentation and clean up v1 legacy code for v2

- Fix README.md and CLAUDE.md project structure (remove non-existent hooks/ directory)
- Remove ~200 lines of unused v1 audio player CSS from globals.css
- Remove unused search-bar.tsx component
- Archive v1-era spec documents to docs/superpowers/specs/archive/
- Add v2.0.0 CHANGELOG entry
```
