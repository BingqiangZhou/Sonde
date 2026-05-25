# PodcastInsight v2 — Get笔记 Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the heavy FastAPI+PostgreSQL+Redis+Celery backend with a pure Next.js application that uses Get笔记 OpenAPI as the core data/processing engine.

**Architecture:** Next.js App Router with Route Handlers as BFF proxy layer. Get笔记 knowledge bases replace the database. localStorage manages subscription mappings. No backend services needed.

**Tech Stack:** Next.js 16, React 19, TypeScript 5, TailwindCSS 4, shadcn/ui, TanStack Query v5, Zustand

---

## Dependency Graph & Parallelization

```
Group 1 (parallel, no deps):
  Task 1: Cleanup old backend/docker/config
  Task 2: TypeScript types

Group 2 (parallel, depends on Task 2):
  Task 3: Get笔记 API client + subscription store
  Task 4: xyzrank API client + RSS parser

Group 3 (parallel, depends on Tasks 3, 4):
  Task 5: API routes - Get笔记 notes
  Task 6: API routes - Get笔记 knowledge + recall
  Task 7: API routes - Podcasts

Group 4 (parallel, depends on Tasks 5, 6, 7):
  Task 8: TanStack Query hooks
  Task 9: Layout + sidebar rewrite

Group 5 (parallel, depends on Task 8):
  Task 10: Settings page
  Task 11: Dashboard page
  Task 12: Podcasts list page
  Task 13: Podcast detail page
  Task 14: Note detail page
  Task 15: Search page

Group 6 (parallel, depends on Task 1):
  Task 16: Config + docs updates
```

---

## Task 1: Cleanup — Remove Old Backend, Docker, Config

**Files:**
- Delete: `backend/` (entire directory)
- Delete: `docker/` (entire directory)
- Delete: `cliff.toml`
- Modify: `.gitignore`
- Modify: `.env.example`

- [ ] **Step 1: Delete backend and docker directories and cliff.toml**

```bash
rm -rf backend/ docker/ cliff.toml
```

- [ ] **Step 2: Update .gitignore**

Replace `.gitignore` with:

```
# Node
node_modules/
.next/
out/
.npm

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
.superpowers/

# OS
.DS_Store
Thumbs.db

# Generated
frontend/next-env.d.ts
frontend/tsconfig.tsbuildinfo
```

- [ ] **Step 3: Update .env.example**

Replace `.env.example` with:

```env
# Get笔记 OpenAPI
GETNOTE_API_KEY=gk_live_xxxxx
GETNOTE_CLIENT_ID=cli_xxxxx

# Frontend
NEXT_PUBLIC_API_URL=/api
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove backend, docker, and old config for v2 architecture"
```

---

## Task 2: TypeScript Types

**Files:**
- Replace: `frontend/src/types/index.ts`

- [ ] **Step 1: Write the types file**

Replace `frontend/src/types/index.ts` with:

```typescript
// ========== Get笔记 API Types ==========

export interface GetNoteConfig {
  apiKey: string;
  clientId: string;
}

// --- Notes ---

export type NoteType = "plain_text" | "link" | "img_text";

export interface Note {
  note_id: string;
  title: string;
  content: string;
  note_type: string;
  tags: NoteTag[];
  topics: NoteTopic[];
  created_at: string;
  updated_at: string;
}

export interface NoteDetail extends Note {
  audio?: {
    original: string;
    play_url: string;
    duration: number;
  };
  web_page?: {
    content: string;
    url: string;
    excerpt: string;
  };
  attachments?: Attachment[];
}

export interface NoteTag {
  id: string;
  name: string;
  type: string;
}

export interface NoteTopic {
  topic_id: string;
  name: string;
}

export interface Attachment {
  type: "image" | "audio" | "link" | "pdf";
  url: string;
  name?: string;
}

export interface NoteListResponse {
  notes: Note[];
  has_more: boolean;
  cursor: string;
}

export interface SaveNoteRequest {
  note_type?: NoteType;
  title?: string;
  content?: string;
  tags?: string[];
  link_url?: string;
  image_urls?: string[];
  topic_id?: string;
}

export interface SaveNoteResponse {
  note_id?: string;
  title?: string;
  created_at?: string;
  updated_at?: string;
  tasks?: { task_id: string; url?: string }[];
  created_count?: number;
}

// --- Tasks ---

export type TaskStatus = "pending" | "processing" | "success" | "failed";

export interface TaskProgress {
  status: TaskStatus;
  note_id?: string;
}

// --- Knowledge Base ---

export interface KnowledgeBase {
  topic_id: string;
  name: string;
  description: string;
  stats: {
    note_count: number;
  };
}

export interface KnowledgeListResponse {
  topics: KnowledgeBase[];
}

export interface KnowledgeNotesResponse {
  notes: Note[];
  has_more: boolean;
  page: number;
}

// --- Semantic Recall ---

export interface RecallRequest {
  query: string;
  top_k?: number;
}

export interface KnowledgeRecallRequest extends RecallRequest {
  topic_id: string;
}

export interface RecallResult {
  note_id: string;
  note_type: string;
  title: string;
  content: string;
  created_at: string;
}

export interface RecallResponse {
  results: RecallResult[];
}

// --- Quota ---

export interface QuotaInfo {
  daily: { limit: number; used: number; remaining: number; reset_at: number };
  monthly: { limit: number; used: number; remaining: number; reset_at: number };
}

export interface RateLimitInfo {
  read: QuotaInfo;
  write: QuotaInfo;
}

// --- API Response ---

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  error?: {
    code: number;
    message: string;
    reason?: string;
    rate_limit?: RateLimitInfo;
  };
}

// ========== xyzrank Types ==========

export interface XyzrankPodcast {
  id: string;
  name: string;
  rank: number;
  logo_url: string;
  category: string;
  author: string;
  rss_feed_url: string;
  track_count: number;
  avg_duration: number;
  avg_play_count: number;
}

export interface XyzrankResponse {
  podcasts: XyzrankPodcast[];
  total: number;
}

// ========== RSS Types ==========

export interface RssEpisode {
  title: string;
  link: string;
  description: string;
  audio_url: string;
  duration: number;
  published_at: string;
  image_url?: string;
}

export interface RssFeedResult {
  title: string;
  description: string;
  episodes: RssEpisode[];
}

// ========== Local Types ==========

export interface Subscription {
  xyzrankId: string;
  topicId: string;
  podcastName: string;
  rssUrl: string;
  logoUrl: string;
  category: string;
}

export interface SubscriptionMap {
  [xyzrankId: string]: Subscription;
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/src/types/index.ts
git commit -m "feat: replace backend types with Get笔记 API types"
```

---

## Task 3: Get笔记 API Client + Subscription Store

**Files:**
- Create: `frontend/src/lib/getnote-api.ts`
- Create: `frontend/src/lib/subscription-store.ts`

- [ ] **Step 1: Write Get笔记 API client**

Create `frontend/src/lib/getnote-api.ts`:

```typescript
import type {
  ApiResponse,
  NoteListResponse,
  NoteDetail,
  SaveNoteRequest,
  SaveNoteResponse,
  TaskProgress,
  KnowledgeListResponse,
  KnowledgeNotesResponse,
  RecallRequest,
  KnowledgeRecallRequest,
  RecallResponse,
  RateLimitInfo,
} from "@/types";

const BASE_URL = "https://openapi.biji.com/open/api/v1";

class GetNoteApiError extends Error {
  code: number;
  reason?: string;
  rateLimit?: RateLimitInfo;

  constructor(code: number, message: string, reason?: string, rateLimit?: RateLimitInfo) {
    super(message);
    this.name = "GetNoteApiError";
    this.code = code;
    this.reason = reason;
    this.rateLimit = rateLimit;
  }
}

async function request<T>(
  apiKey: string,
  clientId: string,
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${BASE_URL}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: apiKey,
      "X-Client-ID": clientId,
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  if (res.status === 429) {
    const body = await res.json();
    const error = body.error ?? body;
    throw new GetNoteApiError(
      42900,
      "请求过于频繁，请稍后再试",
      error.reason,
      error.rate_limit
    );
  }

  const body: ApiResponse<T> = await res.json();

  if (!body.success) {
    const error = body.error;
    throw new GetNoteApiError(
      error?.code ?? res.status,
      error?.message ?? "请求失败",
      error?.reason
    );
  }

  return body.data;
}

// --- Notes ---

export async function listNotes(
  apiKey: string,
  clientId: string,
  cursor?: string
): Promise<NoteListResponse> {
  const params = cursor ? `?cursor=${cursor}` : "";
  return request<NoteListResponse>(apiKey, clientId, `/resource/note/list${params}`);
}

export async function getNoteDetail(
  apiKey: string,
  clientId: string,
  noteId: string
): Promise<{ note: NoteDetail }> {
  return request<{ note: NoteDetail }>(
    apiKey,
    clientId,
    `/resource/note/detail?id=${noteId}`
  );
}

export async function saveNote(
  apiKey: string,
  clientId: string,
  data: SaveNoteRequest
): Promise<SaveNoteResponse> {
  return request<SaveNoteResponse>(apiKey, clientId, "/resource/note/save", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export async function deleteNote(
  apiKey: string,
  clientId: string,
  noteId: string
): Promise<void> {
  return request<void>(apiKey, clientId, "/resource/note/delete", {
    method: "POST",
    body: JSON.stringify({ note_id: noteId }),
  });
}

// --- Tasks ---

export async function getTaskProgress(
  apiKey: string,
  clientId: string,
  taskId: string
): Promise<TaskProgress> {
  return request<TaskProgress>(apiKey, clientId, "/resource/note/task/progress", {
    method: "POST",
    body: JSON.stringify({ task_id: taskId }),
  });
}

// --- Knowledge Base ---

export async function listKnowledgeBases(
  apiKey: string,
  clientId: string,
  page = 1
): Promise<KnowledgeListResponse> {
  return request<KnowledgeListResponse>(
    apiKey,
    clientId,
    `/resource/knowledge/list?page=${page}`
  );
}

export async function createKnowledgeBase(
  apiKey: string,
  clientId: string,
  name: string,
  description?: string
): Promise<{ topic_id: string }> {
  return request<{ topic_id: string }>(apiKey, clientId, "/resource/knowledge/create", {
    method: "POST",
    body: JSON.stringify({ name, description }),
  });
}

export async function getKnowledgeNotes(
  apiKey: string,
  clientId: string,
  topicId: string,
  page = 1
): Promise<KnowledgeNotesResponse> {
  return request<KnowledgeNotesResponse>(
    apiKey,
    clientId,
    `/resource/knowledge/notes?topic_id=${topicId}&page=${page}`
  );
}

export async function addNotesToKnowledgeBase(
  apiKey: string,
  clientId: string,
  topicId: string,
  noteIds: string[]
): Promise<void> {
  return request<void>(apiKey, clientId, "/resource/knowledge/note/batch-add", {
    method: "POST",
    body: JSON.stringify({ topic_id: topicId, note_ids: noteIds }),
  });
}

// --- Semantic Recall ---

export async function globalRecall(
  apiKey: string,
  clientId: string,
  req: RecallRequest
): Promise<RecallResponse> {
  return request<RecallResponse>(apiKey, clientId, "/resource/recall", {
    method: "POST",
    body: JSON.stringify(req),
  });
}

export async function knowledgeRecall(
  apiKey: string,
  clientId: string,
  req: KnowledgeRecallRequest
): Promise<RecallResponse> {
  return request<RecallResponse>(apiKey, clientId, "/resource/recall/knowledge", {
    method: "POST",
    body: JSON.stringify(req),
  });
}

// --- Quota ---

export async function getQuota(
  apiKey: string,
  clientId: string
): Promise<RateLimitInfo> {
  return request<RateLimitInfo>(apiKey, clientId, "/resource/rate-limit/quota");
}

export { GetNoteApiError };
```

- [ ] **Step 2: Write subscription store**

Create `frontend/src/lib/subscription-store.ts`:

```typescript
import type { Subscription, SubscriptionMap } from "@/types";

const STORAGE_KEY = "podcastinsight_subscriptions";

export function getSubscriptions(): SubscriptionMap {
  if (typeof window === "undefined") return {};
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

export function getSubscription(xyzrankId: string): Subscription | null {
  const map = getSubscriptions();
  return map[xyzrankId] ?? null;
}

export function saveSubscription(sub: Subscription): void {
  const map = getSubscriptions();
  map[sub.xyzrankId] = sub;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
}

export function removeSubscription(xyzrankId: string): void {
  const map = getSubscriptions();
  delete map[xyzrankId];
  localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
}

export function clearSubscriptions(): void {
  localStorage.removeItem(STORAGE_KEY);
}

export function isSubscribed(xyzrankId: string): boolean {
  return xyzrankId in getSubscriptions();
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/lib/getnote-api.ts frontend/src/lib/subscription-store.ts
git commit -m "feat: add Get笔记 API client and subscription store"
```

---

## Task 4: xyzrank API Client + RSS Parser

**Files:**
- Create: `frontend/src/lib/xyzrank-api.ts`
- Create: `frontend/src/lib/rss-parser.ts`

- [ ] **Step 1: Write xyzrank API client**

Create `frontend/src/lib/xyzrank-api.ts`:

```typescript
import type { XyzrankPodcast } from "@/types";

const BASE_URL = "https://xyzrank.com/api/podcasts";

export async function fetchRankings(
  offset = 0,
  limit = 50
): Promise<{ podcasts: XyzrankPodcast[]; total: number }> {
  const res = await fetch(`${BASE_URL}?offset=${offset}&limit=${limit}`);
  if (!res.ok) throw new Error(`xyzrank API error: ${res.status}`);
  return res.json();
}

export async function fetchAllRankings(): Promise<XyzrankPodcast[]> {
  const all: XyzrankPodcast[] = [];
  const batchSize = 50;
  let offset = 0;

  const first = await fetchRankings(offset, batchSize);
  all.push(...(first.podcasts ?? []));
  const total = first.total ?? 0;

  while (all.length < total) {
    offset += batchSize;
    const batch = await fetchRankings(offset, batchSize);
    all.push(...(batch.podcasts ?? []));
  }

  return all;
}
```

- [ ] **Step 2: Write RSS parser**

Create `frontend/src/lib/rss-parser.ts`:

```typescript
import type { RssEpisode, RssFeedResult } from "@/types";

function parseDuration(durationStr: string | undefined): number {
  if (!durationStr) return 0;
  const n = parseInt(durationStr, 10);
  if (!isNaN(n)) return n;
  const parts = durationStr.split(":").map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return 0;
}

export async function parseRssFeed(feedUrl: string): Promise<RssFeedResult> {
  // Use a CORS proxy route or server-side fetching
  const res = await fetch(feedUrl, {
    headers: { Accept: "application/xml, text/xml, application/rss+xml" },
  });
  if (!res.ok) throw new Error(`Failed to fetch RSS: ${res.status}`);

  const text = await res.text();
  const parser = new DOMParser();
  const xml = parser.parseFromString(text, "text/xml");

  const channel = xml.querySelector("channel");
  const title = channel?.querySelector("title")?.textContent ?? "";
  const description = channel?.querySelector("description")?.textContent ?? "";

  const items = xml.querySelectorAll("item");
  const episodes: RssEpisode[] = [];

  items.forEach((item) => {
    const enclosure = item.querySelector("enclosure");
    const audioUrl = enclosure?.getAttribute("url") ?? "";
    const audioType = enclosure?.getAttribute("type") ?? "";

    if (!audioUrl || !audioType.startsWith("audio/")) return;

    episodes.push({
      title: item.querySelector("title")?.textContent ?? "",
      link: item.querySelector("link")?.textContent ?? "",
      description: item.querySelector("description")?.textContent ?? "",
      audio_url: audioUrl,
      duration: parseDuration(
        item.querySelector("duration")?.textContent ??
        item.getElementsByTagNameNS("http://www.itunes.com/dtds/podcast-1.0.dtd", "duration")[0]?.textContent
      ),
      published_at:
        item.querySelector("pubDate")?.textContent ?? "",
      image_url:
        item.getElementsByTagNameNS("http://www.itunes.com/dtds/podcast-1.0.dtd", "image")[0]?.getAttribute("href") ?? undefined,
    });
  });

  return { title, description, episodes };
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/lib/xyzrank-api.ts frontend/src/lib/rss-parser.ts
git commit -m "feat: add xyzrank API client and RSS parser"
```

---

## Task 5: API Routes — Get笔记 Notes

**Files:**
- Create: `frontend/src/app/api/getnote/notes/route.ts`
- Create: `frontend/src/app/api/getnote/notes/[id]/route.ts`
- Create: `frontend/src/app/api/getnote/task/route.ts`

- [ ] **Step 1: Write notes list/save route**

Create `frontend/src/app/api/getnote/notes/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key") || process.env.GETNOTE_API_KEY;
  const clientId = req.headers.get("X-Client-ID") || process.env.GETNOTE_CLIENT_ID;
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function GET(req: NextRequest) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const cursor = req.nextUrl.searchParams.get("cursor") ?? undefined;
    const data = await getnote.listNotes(apiKey, clientId, cursor);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const body = await req.json();
    const data = await getnote.saveNote(apiKey, clientId, body);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}
```

- [ ] **Step 2: Write note detail route**

Create `frontend/src/app/api/getnote/notes/[id]/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key") || process.env.GETNOTE_API_KEY;
  const clientId = req.headers.get("X-Client-ID") || process.env.GETNOTE_CLIENT_ID;
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { apiKey, clientId } = getCredentials(_req);
    const { id } = await params;
    const data = await getnote.getNoteDetail(apiKey, clientId, id);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}
```

- [ ] **Step 3: Write task progress route**

Create `frontend/src/app/api/getnote/task/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key") || process.env.GETNOTE_API_KEY;
  const clientId = req.headers.get("X-Client-ID") || process.env.GETNOTE_CLIENT_ID;
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function POST(req: NextRequest) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const { task_id } = await req.json();
    const data = await getnote.getTaskProgress(apiKey, clientId, task_id);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add frontend/src/app/api/
git commit -m "feat: add Get笔记 notes and task API routes"
```

---

## Task 6: API Routes — Get笔记 Knowledge + Recall

**Files:**
- Create: `frontend/src/app/api/getnote/knowledge/route.ts`
- Create: `frontend/src/app/api/getnote/knowledge/[id]/route.ts`
- Create: `frontend/src/app/api/getnote/recall/route.ts`

- [ ] **Step 1: Write knowledge base list/create route**

Create `frontend/src/app/api/getnote/knowledge/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key") || process.env.GETNOTE_API_KEY;
  const clientId = req.headers.get("X-Client-ID") || process.env.GETNOTE_CLIENT_ID;
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function GET(req: NextRequest) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const page = parseInt(req.nextUrl.searchParams.get("page") ?? "1", 10);
    const data = await getnote.listKnowledgeBases(apiKey, clientId, page);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const { name, description } = await req.json();
    const data = await getnote.createKnowledgeBase(apiKey, clientId, name, description);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}
```

- [ ] **Step 2: Write knowledge base notes route**

Create `frontend/src/app/api/getnote/knowledge/[id]/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key") || process.env.GETNOTE_API_KEY;
  const clientId = req.headers.get("X-Client-ID") || process.env.GETNOTE_CLIENT_ID;
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const { id } = await params;
    const page = parseInt(req.nextUrl.searchParams.get("page") ?? "1", 10);
    const data = await getnote.getKnowledgeNotes(apiKey, clientId, id, page);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}
```

- [ ] **Step 3: Write recall route**

Create `frontend/src/app/api/getnote/recall/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key") || process.env.GETNOTE_API_KEY;
  const clientId = req.headers.get("X-Client-ID") || process.env.GETNOTE_CLIENT_ID;
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function POST(req: NextRequest) {
  try {
    const { apiKey, clientId } = getCredentials(req);
    const body = await req.json();

    const data = body.topic_id
      ? await getnote.knowledgeRecall(apiKey, clientId, {
          query: body.query,
          top_k: body.top_k,
          topic_id: body.topic_id,
        })
      : await getnote.globalRecall(apiKey, clientId, {
          query: body.query,
          top_k: body.top_k,
        });

    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message, code: e.code } },
      { status: e.code === 42900 ? 429 : 500 }
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add frontend/src/app/api/getnote/knowledge/ frontend/src/app/api/getnote/recall/
git commit -m "feat: add Get笔记 knowledge base and recall API routes"
```

---

## Task 7: API Routes — Podcasts (xyzrank + RSS)

**Files:**
- Create: `frontend/src/app/api/podcasts/rankings/route.ts`
- Create: `frontend/src/app/api/podcasts/feed/route.ts`

- [ ] **Step 1: Write rankings route**

Create `frontend/src/app/api/podcasts/rankings/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";
import { fetchRankings } from "@/lib/xyzrank-api";

export async function GET(req: NextRequest) {
  try {
    const offset = parseInt(req.nextUrl.searchParams.get("offset") ?? "0", 10);
    const limit = parseInt(req.nextUrl.searchParams.get("limit") ?? "50", 10);
    const data = await fetchRankings(offset, limit);
    return NextResponse.json({ success: true, data });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message } },
      { status: 500 }
    );
  }
}
```

- [ ] **Step 2: Write RSS feed route**

Create `frontend/src/app/api/podcasts/feed/route.ts`:

```typescript
import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const { url } = await req.json();
    if (!url) {
      return NextResponse.json(
        { success: false, error: { message: "缺少 RSS feed URL" } },
        { status: 400 }
      );
    }

    // Server-side fetch to avoid CORS
    const res = await fetch(url, {
      headers: { Accept: "application/xml, text/xml, application/rss+xml" },
    });
    if (!res.ok) throw new Error(`Failed to fetch RSS: ${res.status}`);

    const text = await res.text();

    // Parse XML on server side using regex (no DOMParser in Node)
    const titleMatch = text.match(/<title>(?:<![CDATA[)?(.*?)(?:]]>)?<\/title>/s);
    const descMatch = text.match(/<description>(?:<![CDATA[)?(.*?)(?:]]>)?<\/description>/s);

    const episodeRegex = /<item>([\s\S]*?)<\/item>/g;
    const episodes: {
      title: string;
      link: string;
      description: string;
      audio_url: string;
      duration: number;
      published_at: string;
    }[] = [];

    let match;
    while ((match = episodeRegex.exec(text)) !== null) {
      const item = match[1];
      const enclosureMatch = item.match(/<enclosure[^>]*url="([^"]*)"[^>]*type="([^"]*)"/);
      if (!enclosureMatch || !enclosureMatch[2].startsWith("audio/")) continue;

      const itemTitle = item.match(/<title>(?:<![CDATA[)?(.*?)(?:]]>)?<\/title>/s);
      const itemLink = item.match(/<link>(?:<![CDATA[)?(.*?)(?:]]>)?<\/link>/s);
      const itemDesc = item.match(/<description>(?:<![CDATA[)?(.*?)(?:]]>)?<\/description>/s);
      const itemPubDate = item.match(/<pubDate>(.*?)<\/pubDate>/);
      const itemDuration =
        item.match(/<itunes:duration>(.*?)<\/itunes:duration>/) ??
        item.match(/<duration>(.*?)<\/duration>/);

      let duration = 0;
      if (itemDuration) {
        const d = parseInt(itemDuration[1], 10);
        if (!isNaN(d)) duration = d;
      }

      episodes.push({
        title: itemTitle?.[1]?.trim() ?? "",
        link: itemLink?.[1]?.trim() ?? "",
        description: itemDesc?.[1]?.trim() ?? "",
        audio_url: enclosureMatch[1],
        duration,
        published_at: itemPubDate?.[1]?.trim() ?? "",
      });
    }

    return NextResponse.json({
      success: true,
      data: {
        title: titleMatch?.[1]?.trim() ?? "",
        description: descMatch?.[1]?.trim() ?? "",
        episodes,
      },
    });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message } },
      { status: 500 }
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/app/api/podcasts/
git commit -m "feat: add podcast rankings and RSS feed API routes"
```

---

## Task 8: TanStack Query Hooks

**Files:**
- Create: `frontend/src/lib/queries.ts`

- [ ] **Step 1: Write all TanStack Query hooks**

Create `frontend/src/lib/queries.ts`:

```typescript
"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import type { SaveNoteRequest, Subscription } from "@/types";
import * as subscriptionStore from "@/lib/subscription-store";

// ========== Query Keys ==========

export const queryKeys = {
  notes: {
    all: ["notes"] as const,
    list: (cursor?: string) => [...queryKeys.notes.all, cursor] as const,
    detail: (id: string) => ["notes", id] as const,
  },
  knowledge: {
    all: ["knowledge"] as const,
    list: (page?: number) => [...queryKeys.knowledge.all, page] as const,
    notes: (topicId: string, page?: number) =>
      ["knowledge", topicId, "notes", page] as const,
  },
  rankings: {
    all: ["rankings"] as const,
    page: (offset: number, limit: number) =>
      ["rankings", offset, limit] as const,
  },
  feed: (url: string) => ["feed", url] as const,
  recall: {
    global: (query: string) => ["recall", query] as const,
    knowledge: (topicId: string, query: string) =>
      ["recall", topicId, query] as const,
  },
  task: (taskId: string) => ["task", taskId] as const,
  subscriptions: ["subscriptions"] as const,
};

// ========== Helper ==========

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const baseUrl = "/api/getnote";
  const res = await fetch(`${baseUrl}${path}`, init);
  const body = await res.json();
  if (!body.success) {
    throw new Error(body.error?.message ?? "请求失败");
  }
  return body.data;
}

// ========== Note Hooks ==========

export function useNotes(cursor?: string) {
  return useQuery({
    queryKey: queryKeys.notes.list(cursor),
    queryFn: () => apiFetch<any>(`/notes${cursor ? `?cursor=${cursor}` : ""}`),
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useNoteDetail(noteId: string) {
  return useQuery({
    queryKey: queryKeys.notes.detail(noteId),
    queryFn: () => apiFetch<any>(`/notes/${noteId}`),
    enabled: !!noteId,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useSaveNote() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: SaveNoteRequest) =>
      apiFetch<any>("/notes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.notes.all });
      qc.invalidateQueries({ queryKey: queryKeys.knowledge.all });
    },
  });
}

export function useTaskProgress(taskId: string) {
  return useQuery({
    queryKey: queryKeys.task(taskId),
    queryFn: () =>
      apiFetch<any>("/task", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ task_id: taskId }),
      }),
    enabled: !!taskId,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      if (status === "success" || status === "failed") return false;
      return 5000;
    },
    retry: 1,
  });
}

// ========== Knowledge Base Hooks ==========

export function useKnowledgeBases(page = 1) {
  return useQuery({
    queryKey: queryKeys.knowledge.list(page),
    queryFn: () => apiFetch<any>(`/knowledge?page=${page}`),
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useCreateKnowledgeBase() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ name, description }: { name: string; description?: string }) =>
      apiFetch<any>("/knowledge", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, description }),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.knowledge.all });
    },
  });
}

export function useKnowledgeNotes(topicId: string, page = 1) {
  return useQuery({
    queryKey: queryKeys.knowledge.notes(topicId, page),
    queryFn: () => apiFetch<any>(`/knowledge/${topicId}?page=${page}`),
    enabled: !!topicId,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

// ========== Recall Hooks ==========

export function useGlobalRecall(query: string) {
  return useQuery({
    queryKey: queryKeys.recall.global(query),
    queryFn: () =>
      apiFetch<any>("/recall", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query, top_k: 5 }),
      }),
    enabled: query.length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useKnowledgeRecall(topicId: string, query: string) {
  return useQuery({
    queryKey: queryKeys.recall.knowledge(topicId, query),
    queryFn: () =>
      apiFetch<any>("/recall", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query, top_k: 5, topic_id: topicId }),
      }),
    enabled: !!topicId && query.length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

// ========== Subscription Hooks ==========

export function useSubscriptions() {
  return useQuery({
    queryKey: queryKeys.subscriptions,
    queryFn: () => subscriptionStore.getSubscriptions(),
    staleTime: 0,
  });
}

export function useSubscribe() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (sub: Subscription) => {
      subscriptionStore.saveSubscription(sub);
      return sub;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.subscriptions });
    },
  });
}

export function useUnsubscribe() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (xyzrankId: string) => {
      subscriptionStore.removeSubscription(xyzrankId);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.subscriptions });
    },
  });
}

// ========== Podcast Rankings Hooks ==========

export function useRankings(offset = 0, limit = 50) {
  return useQuery({
    queryKey: queryKeys.rankings.page(offset, limit),
    queryFn: async () => {
      const res = await fetch(`/api/podcasts/rankings?offset=${offset}&limit=${limit}`);
      const body = await res.json();
      if (!body.success) throw new Error(body.error?.message);
      return body.data;
    },
    staleTime: 60 * 60 * 1000,
    retry: 1,
  });
}

// ========== RSS Feed Hooks ==========

export function useRssFeed(feedUrl: string) {
  return useMutation({
    mutationFn: async (url: string) => {
      const res = await fetch("/api/podcasts/feed", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url }),
      });
      const body = await res.json();
      if (!body.success) throw new Error(body.error?.message);
      return body.data;
    },
  });
}
```

- [ ] **Step 2: Remove old api.ts and queries.ts**

Delete `frontend/src/lib/api.ts` (the old backend API client).
The old `frontend/src/lib/queries.ts` is already replaced by the new file above.

```bash
rm frontend/src/lib/api.ts
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/lib/queries.ts
git rm frontend/src/lib/api.ts
git commit -m "feat: add TanStack Query hooks for Get笔记 API and remove old API client"
```

---

## Task 9: Layout + Sidebar Rewrite

**Files:**
- Modify: `frontend/src/components/layout/sidebar.tsx`
- Delete: `frontend/src/components/audio-player.tsx`
- Delete: `frontend/src/hooks/use-audio-player.ts`
- Delete: `frontend/src/stores/audio-store.ts`
- Delete: `frontend/src/components/transcript-viewer.tsx`
- Delete: `frontend/src/components/summary-card.tsx`
- Delete: `frontend/src/components/episode-tabs.tsx`
- Delete: `frontend/src/components/episode-info-card.tsx`
- Delete: `frontend/src/components/provider-form.tsx`
- Delete: `frontend/src/components/providers.tsx`
- Delete: `frontend/src/components/skeletons.tsx`
- Delete: `frontend/src/components/status-badge.tsx`

- [ ] **Step 1: Update sidebar navigation**

The sidebar in `frontend/src/components/layout/sidebar.tsx` currently has 4 nav items. Replace them with the new v2 navigation:

| Label | Route | Icon |
|-------|-------|------|
| 仪表盘 | `/` | LayoutDashboard |
| 播客 | `/podcasts` | Podcast |
| 搜索 | `/search` | Search |
| 设置 | `/settings` | Settings |

Update the version label from "PodcastInsight v1.0" to "PodcastInsight v2".

- [ ] **Step 2: Delete unused v1 components**

```bash
rm frontend/src/components/audio-player.tsx
rm frontend/src/hooks/use-audio-player.ts
rm frontend/src/stores/audio-store.ts
rm frontend/src/components/transcript-viewer.tsx
rm frontend/src/components/summary-card.tsx
rm frontend/src/components/episode-tabs.tsx
rm frontend/src/components/episode-info-card.tsx
rm frontend/src/components/provider-form.tsx
rm frontend/src/components/skeletons.tsx
rm frontend/src/components/status-badge.tsx
```

Keep: `badge.tsx`, `button.tsx`, `card.tsx`, `dialog.tsx`, `input.tsx`, `select.tsx`, `skeleton.tsx`, `table.tsx`, `tabs.tsx`, `textarea.tsx` (shadcn/ui primitives).
Keep: `podcast-card.tsx`, `episode-card.tsx`, `expandable-description.tsx`, `search-bar.tsx` (will be adapted in page tasks).
Keep: `sidebar.tsx`, `sidebar-context.tsx`, `theme-provider.tsx`, `providers.tsx` (layout).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: update sidebar navigation and remove v1 components"
```

---

## Task 10: Settings Page

**Files:**
- Replace: `frontend/src/app/settings/page.tsx`

- [ ] **Step 1: Rewrite settings page**

The settings page needs:
- Get笔记 API Key input
- Client ID input
- Connection test button (calls `/api/getnote/notes` with credentials)
- Subscribed podcasts list with unsubscribe buttons
- "从 Get笔记 同步" button (calls `/api/getnote/knowledge` and rebuilds localStorage)
- "清除所有订阅数据" button
- API Key and Client ID stored in a Zustand store (persisted to localStorage)

Create `frontend/src/stores/settings-store.ts`:

```typescript
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface SettingsState {
  apiKey: string;
  clientId: string;
  setApiKey: (key: string) => void;
  setClientId: (id: string) => void;
  clear: () => void;
  isConfigured: () => boolean;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set, get) => ({
      apiKey: "",
      clientId: "",
      setApiKey: (key) => set({ apiKey: key }),
      setClientId: (id) => set({ clientId: id }),
      clear: () => set({ apiKey: "", clientId: "" }),
      isConfigured: () => !!(get().apiKey && get().clientId),
    }),
    { name: "podcastinsight_settings" }
  )
);
```

The `apiFetch` helper in `queries.ts` reads from this store and passes credentials via `X-Api-Key` / `X-Client-ID` headers. All API routes (Tasks 5-7) already read from headers first, then fall back to env vars.

- [ ] **Step 2: Commit**

```bash
git add frontend/src/app/settings/ frontend/src/stores/settings-store.ts
git commit -m "feat: rewrite settings page with Get笔记 API key management"
```

---

## Task 11: Dashboard Page

**Files:**
- Replace: `frontend/src/app/page.tsx`

- [ ] **Step 1: Rewrite dashboard**

The new dashboard shows:
- Search bar at top (links to `/search?q=...`)
- "已订阅播客" section: grid of subscribed podcasts from localStorage + knowledge base info
- "最近笔记" section: latest notes from `/api/getnote/notes`
- Quick actions: "发现播客" link to `/podcasts`

No stat cards, no pipeline view, no production stats (all v1 concepts removed).

- [ ] **Step 2: Commit**

```bash
git add frontend/src/app/page.tsx
git commit -m "feat: rewrite dashboard page for v2"
```

---

## Task 12: Podcasts List Page

**Files:**
- Replace: `frontend/src/app/podcasts/page.tsx`

- [ ] **Step 1: Rewrite podcasts list**

The new page shows:
- xyzrank ranking table with pagination (50 per page)
- Each row: rank, logo, name, author, category, subscribe/unsubscribe button
- Category filter dropdown
- Search filter
- Already-subscribed podcasts highlighted

- [ ] **Step 2: Commit**

```bash
git add frontend/src/app/podcasts/page.tsx
git commit -m "feat: rewrite podcasts list page with xyzrank rankings"
```

---

## Task 13: Podcast Detail Page

**Files:**
- Replace: `frontend/src/app/podcasts/[id]/page.tsx`

- [ ] **Step 1: Rewrite podcast detail**

The new page shows:
- Podcast header (logo, name, author, category, rank)
- Subscribe/unsubscribe button
- "解析 RSS" button → calls `/api/podcasts/feed` with the podcast's RSS URL
- Episode list from parsed RSS (title, date, duration)
- Each episode has a "处理" button → saves link to Get笔记 knowledge base
- Below: knowledge base notes for this podcast (from `/api/getnote/knowledge/{topicId}`)
- Processing status indicator for episodes being processed

- [ ] **Step 2: Commit**

```bash
git add frontend/src/app/podcasts/[id]/page.tsx
git commit -m "feat: rewrite podcast detail page with RSS parsing and note processing"
```

---

## Task 14: Note Detail Page

**Files:**
- Replace: `frontend/src/app/episodes/[id]/page.tsx`
- Delete: `frontend/src/app/episodes/page.tsx` (no longer needed as standalone list)

- [ ] **Step 1: Rewrite note detail**

The new page (routed as `/episodes/[noteId]`) shows:
- Note title
- AI 摘要 card (from `web_page.excerpt`, styled as a highlighted card)
- Markdown content (rendered from `content`)
- Original content collapsible section (from `web_page.content`)
- Tags as badges
- Created/updated timestamps
- Back navigation to the podcast page

- [ ] **Step 2: Delete standalone episodes list page**

```bash
rm frontend/src/app/episodes/page.tsx
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: rewrite note detail page with AI summary and content display"
```

---

## Task 15: Search Page

**Files:**
- Create: `frontend/src/app/search/page.tsx`

- [ ] **Step 1: Create search page**

The search page shows:
- Search input (pre-filled from `?q=` URL param)
- Knowledge base filter dropdown (optional, from subscribed podcasts)
- Search results list (from `/api/getnote/recall`)
- Each result: title, content snippet, date, link to note detail
- Empty state when no query

- [ ] **Step 2: Commit**

```bash
git add frontend/src/app/search/
git commit -m "feat: add semantic search page"
```

---

## Task 16: Config + Docs Updates

**Files:**
- Replace: `CLAUDE.md`
- Replace: `README.md`
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Rewrite CLAUDE.md**

Update CLAUDE.md to reflect v2 architecture:
- No backend, pure Next.js
- Get笔记 OpenAPI as core
- Commands section: only frontend commands
- Tech stack: no Python/FastAPI/PostgreSQL/Redis/Celery
- API endpoints: BFF proxy routes
- Remove gotchas about pip, sync DB, etc.

- [ ] **Step 2: Update README.md**

Update README to reflect v2:
- Get笔记 integration overview
- Simplified setup (just frontend + .env.local)
- Remove Docker, backend, Celery sections

- [ ] **Step 3: Update release workflow**

Simplify `.github/workflows/release.yml`:
- Remove backend build steps
- Remove Docker image builds for backend
- Keep frontend build + lint + test
- Keep GitHub Release creation
- Remove Docker-related steps

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README.md .github/
git commit -m "docs: update CLAUDE.md, README, and CI for v2 architecture"
```

---

## Post-Implementation Verification

- [ ] `cd frontend && pnpm build` passes with no errors
- [ ] `cd frontend && pnpm lint` passes
- [ ] All pages render without runtime errors
- [ ] API routes return correct responses when Get笔记 credentials are configured
