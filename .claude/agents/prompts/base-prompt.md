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

You are working on the **PodcastInsight v2** project, a podcast ranking monitor + Get笔记 AI summarization/note-taking + semantic search web platform. The system fetches podcast rankings from xyzrank.com, uses Get笔记 OpenAPI for AI-powered summarization and knowledge management, and provides semantic search capabilities.

## Tech Stack Summary

### Frontend (全栈应用)
- **Framework**: Next.js 16 (App Router)
- **Language**: React 19 + TypeScript 5
- **Styling**: TailwindCSS 4
- **Components**: shadcn/ui
- **Server State**: TanStack Query v5
- **Client State**: Zustand
- **Icons**: Lucide
- **Toasts**: Sonner

### 数据引擎
- **Get笔记 OpenAPI**: 笔记 CRUD、知识库管理、语义搜索
- **xyzrank.com API**: 播客排行榜数据
- **RSS Feed**: 剧集列表获取

### 架构
- **纯 Next.js**: 无独立后端，BFF 代理层注入 API Key
- **部署**: Vercel / Cloudflare Pages / 静态托管
- **包管理**: pnpm（NEVER npm/yarn）

## Architecture: Next.js App Router

### Core Principles
1. **App Router**: 使用 app/ 目录，NOT Pages Router
2. **BFF 代理层**: Route Handlers 做代理，注入 API Key
3. **服务端状态**: TanStack Query 管理所有服务端状态
4. **组件库**: shadcn/ui，NOT 自定义 UI
5. **响应式**: 移动端优先，桌面端侧边栏布局

### API Routes (BFF 代理层)
- `/api/getnote/*` — Get笔记 API 代理（笔记、知识库、语义搜索）
- `/api/podcasts/*` — 播客数据代理（xyzrank 排行、RSS 解析）

### 页面结构
- `/podcasts` — 播客排行榜 + 详情
- `/episodes/[id]` — 笔记详情（AI 摘要 + 内容展示）
- `/search` — 语义搜索
- `/settings` — API Key 配置

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
- **BFF 代理模式**: Route Handlers 做代理，注入认证
- **Get笔记即后端**: 无独立后端，Get笔记知识库即数据库
- **Fail gracefully**: Handle errors without leaking details
- **Optimize for maintainability**: Clear code over clever code

## Code Quality Standards

### TypeScript Standards
```typescript
// Use strict TypeScript
interface Podcast {
  id: string;
  name: string;
  rank: number;
  logoUrl: string;
  category: string;
}

// Use TanStack Query for server state
const { data, isLoading } = useQuery({
  queryKey: ['podcasts', page],
  queryFn: () => api.getPodcasts(page),
});
```

### API Design Standards
- **RESTful conventions**: GET (read), POST (create), PUT/PATCH (update), DELETE
- **HTTP status codes**: Use semantically correct status codes
- **Error responses**: Consistent error format with error codes
- **BFF proxy**: Route Handlers inject auth headers, never expose API keys to client

### Testing Standards
- **Unit tests**: Use Vitest for testing
- **Test structure**: Arrange-Act-Assert pattern
- **Mocking**: Only for external dependencies

### Security Standards
- **Input validation**: Always validate/sanitize inputs
- **API keys**: Stored in Zustand (localStorage) and/or .env.local, injected via BFF
- **Sensitive data**: Never log API keys, tokens, or credentials

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

### BFF API Route Pattern
```typescript
// app/api/getnote/notes/route.ts
export async function GET(request: Request) {
  const apiKey = request.headers.get('x-api-key');
  const res = await fetch(`${GETNOTE_API_URL}/notes`, {
    headers: { 'Authorization': `Bearer ${apiKey}` },
  });
  return Response.json(await res.json());
}
```

### TanStack Query Hook Pattern
```typescript
// lib/hooks/use-podcasts.ts
export function usePodcasts(page: number) {
  return useQuery({
    queryKey: ['podcasts', page],
    queryFn: () => fetchAPI(`/api/podcasts/rankings?page=${page}`),
  });
}
```

Remember: You are part of a team of specialized agents. Always consider how your work affects other domains and communicates with other agents through well-defined interfaces.
