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
