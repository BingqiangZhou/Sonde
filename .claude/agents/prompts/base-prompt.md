---
name: "Base Agent Prompt"
description: "Shared knowledge base and project context for all agents"
version: "1.1.0"
language_policy: "bilingual"
---

# PodcastInsight — Base Agent Prompt

## 🌐 Language Policy / 语言政策

**MANDATORY: This project follows a strict bilingual (Chinese/English) policy**

**必须：本项目严格遵循中英文双语政策**

### Core Language Rules / 核心语言规则

1. **Response Language Matching / 回复语言匹配**
   ```yaml
   rule: "MUST respond in the same language as user input"
   中文输入 → 中文回复
   English input → English response
   Mixed input → Match primary language or ask for clarification
   ```

2. **Inter-Agent Communication / Agent 间通信**
   ```yaml
   rule: "Maintain language consistency across workflow"
   Match the language of the original task/request
   Status updates match requirement document language
   ```

3. **Documentation Language / 文档语言**
   ```yaml
   Code comments: Team's primary language
   API docs: English primary, Chinese translations as needed
   User-facing text: Must support both languages
   Error messages: Bilingual format (en + zh)
   ```

### Implementation Standards / 实现标准

#### Backend Error Response Format
```python
class ErrorResponse(BaseModel):
    """Standard bilingual error response / 标准双语错误响应"""
    error_code: str
    message_en: str  # English message / 英文消息
    message_zh: str  # Chinese message / 中文消息
    detail: Optional[str] = None
```

---

## Project Overview

You are working on the **PodcastInsight v3** project. Processing logic is encapsulated as Agent Skills (SKILL.md + deterministic TypeScript scripts). Data is stored as structured JSON/Markdown files in git. The frontend is a read-only static site (SSG). The system fetches podcast rankings from xyzrank.com, parses RSS feeds, scrapes episode content, and generates AI summaries via the agent's own capability (no external LLM API).

## Tech Stack Summary

### Skills (核心)
- **确定性脚本技能**: fetch-rankings / parse-rss / scrape-episode（CI 定时或 agent 触发）
- **agent 原生技能**: podcast-summarize（agent 读正文 → 自己生成摘要 → 调 writeSummary 写回）
- **共享层**: skills/_shared（类型、路径解析、原子 IO、校验、索引重建）
- **运行时**: tsx

### Frontend (只读静态站)
- **Framework**: Next.js 16 (App Router, SSG)
- **Language**: React 19 + TypeScript 5
- **Styling**: TailwindCSS 4
- **Components**: shadcn/ui
- **数据读取**: `src/lib/loaders.ts`（唯一数据读取层，构建期读 data/）

### 架构
- **无后端服务**: 数据即 git 文件，前端构建期读 data/ 烤进静态 HTML
- **无数据库 / 无 Get笔记 / 无 BFF / 无状态管理**
- **包管理**: pnpm workspace（NEVER npm/yarn）

## Architecture: Skills + Static Frontend

### Core Principles
1. **Skills 是核心**: 处理逻辑 = SKILL.md + 确定性 run.ts 脚本，TDD
2. **技能发现**: SKILL.md 放 `.agents/skills/`（ZCode 发现目录），代码在 `skills/` pnpm 包
3. **数据布局单一真相**: 路径一律走 `skills/_shared/src/paths.ts`
4. **原子写入**: 经 `_shared/fs.ts`（写 .tmp 再 rename）
5. **幂等**: 所有 skill 重复执行安全，按 id 去重
6. **前端只读**: 无 BFF/API Routes/状态管理，构建期读 data/，无运行时写入
7. **App Router**: 使用 app/ 目录，NOT Pages Router

### Skills
- `fetch-rankings` — 抓 xyzrank Top 排行榜（CI 每周）
- `parse-rss` — 解析订阅播客 RSS，发现新剧集（CI 每日）
- `scrape-episode` — 抓剧集网页正文
- `podcast-summarize` — agent 原生生成摘要（无需外部 API）

### 前端页面
- `/` — 仪表盘（已订阅播客 + 最近摘要）
- `/podcasts` — 播客排行榜
- `/podcasts/[id]` — 播客详情 + 剧集列表
- `/podcasts/[id]/[episodeId]` — 剧集详情（AI 摘要 + 正文）
- `/search` — 关键词搜索（客户端过滤 search-index.json）

## Collaboration Principles

### Inter-Agent Communication
1. **Always clarify ambiguous requirements** before starting work
2. **Document assumptions** when making design decisions
3. **Provide context** for code changes (why, not just what)
4. **Consider cross-domain impacts** when implementing features
5. **Update shared documentation** when domain knowledge changes

### Code Collaboration
1. **Follow existing patterns** and conventions
2. **Create reusable abstractions** for common operations
3. **Write self-documenting code** with clear naming
4. **Include comprehensive tests** for new functionality
5. **Consider performance implications** at scale

### Design Philosophy
- **Skills 为核心**: 确定性逻辑做脚本（可定时、可测试），智能逻辑交给 agent 自身
- **数据即文件**: 结构化 JSON/MD 存 git，有版本历史，无外部依赖
- **Fail gracefully**: 单个 skill/剧集失败不影响整体
- **Optimize for maintainability**: Clear code over clever code

## Code Quality Standards

### TypeScript Standards
```typescript
// Use strict TypeScript
// Skills 共享类型来自 @podcastinsight/shared
import type { EpisodeMeta, PodcastMeta } from "@podcastinsight/shared";

// 前端 server component 直接 await loaders（无 TanStack Query）
import { loadEpisodes } from "@/lib/loaders";
export default async function Page({ params }) {
  const episodes = await loadEpisodes(id);
  // ...
}
```

### Data Layer Standards
- **Skills 写 data/**: 通过 _shared/fs.ts 原子写入，通过 _shared/paths.ts 解析路径
- **Frontend 只读 data/**: 通过 loaders.ts 在构建期读取，无运行时写入
- **No API routes**: 前端无 BFF，无服务端状态管理

### Testing Standards
- **Unit tests**: Use Vitest for testing
- **Test structure**: Arrange-Act-Assert pattern
- **Mocking**: Only for external dependencies (HTTP, filesystem via tmpdir + env var)

### Security Standards
- **No API keys**: v3 无需任何 API Key（摘要由 agent 自身生成）
- **Input validation**: Always validate/sanitize inputs (via _shared/validate.ts)

## Development Workflow

### Before Starting
1. Read the relevant domain documentation
2. Check for existing implementations or patterns
3. Understand the cross-domain impacts
4. Create/update tests as needed

### During Development
1. Write failing tests first (TDD when possible)
2. Implement the minimum viable solution
3. Refactor for clarity and maintainability
4. Add logging at appropriate levels
5. Consider edge cases and error conditions

### Before Completing
1. Run all tests and ensure they pass
2. Check for TODO comments and address them
3. Verify code follows project standards
4. Update documentation if needed
5. Consider if the implementation is testable

## Common Patterns

### Skill Script Pattern (确定性脚本)
```typescript
// skills/fetch-rankings/src/run.ts
import { rankingsFile, writeJsonAtomic, rebuildIndexes } from "@podcastinsight/shared";

export async function fetchAndSaveRankings() {
  const podcasts = await fetchAllRankings(); // 抓取
  validateRankingsSnapshot({ fetched_at, source, podcasts }); // 校验
  await writeJsonAtomic(rankingsFile(), { fetched_at, source, podcasts }); // 原子写
  await rebuildIndexes(); // 重建索引
}
```

### Frontend Loader Pattern (只读静态)
```typescript
// frontend/src/app/podcasts/page.tsx
import { loadRankings } from "@/lib/loaders";

export default async function PodcastsPage() {
  const data = await loadRankings(); // 构建期读 data/
  // 渲染静态 HTML
}
```

### Agent-Native Summarize Pattern (agent 自身智能)
```typescript
// agent 对话中:读正文 → 自己生成摘要 → 调写回函数
import { prepareEpisode, writeSummary } from "./skills/summarize/src/run.ts";
const prepared = await prepareEpisode(podcastId, episodeId); // 读正文
// agent 用自己的能力理解 prepared.body，生成 summary + tags
await writeSummary(podcastId, episodeId, summary, tags); // 写回
```

Remember: You are part of a team of specialized agents. Always consider how your work affects other domains and communicates with other agents through well-defined interfaces.
