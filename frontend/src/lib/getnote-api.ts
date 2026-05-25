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
