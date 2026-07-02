// ========== Rankings ==========

export interface RankingPodcast {
  id: string;
  name: string;
  rank: number;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  author: string;
}

export interface RankingsSnapshot {
  fetched_at: string; // ISO timestamp
  source: string; // "xyzrank.com"
  podcasts: RankingPodcast[];
}

// ========== Podcast Meta ==========

export interface PodcastMeta {
  id: string;
  name: string;
  author: string;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  xyzrank_rank: number;
  subscribed: boolean;
  subscribed_at?: string; // ISO date
}

// ========== Episode ==========

export type ScrapeStatus = "pending" | "done" | "failed";
export type SummaryStatus = "pending" | "done" | "skipped";

export interface EpisodeMeta {
  id: string;
  podcast_id: string;
  title: string;
  audio_url: string;
  duration: number;
  published_at: string; // ISO timestamp
  link: string;
  description?: string;
  scraped_content_path: string; // 相对路径，如 "episodes/<id>.md"
  scrape_status: ScrapeStatus;
  summary_status: SummaryStatus;
  tags: string[];
}

// ========== Episode Markdown frontmatter ==========

export interface EpisodeMarkdownFrontmatter {
  episode_id: string;
  title: string;
  summary_status: SummaryStatus;
  generated_at?: string;
  model?: string;
}

// ========== Index ==========

export interface IndexSubscribedPodcast {
  id: string;
  name: string;
  logo_url: string;
  category: string;
  episode_count: number;
}

export interface IndexRecentEpisode {
  episode_id: string;
  podcast_id: string;
  podcast_name: string;
  title: string;
  summary_status: SummaryStatus;
  published_at: string;
}

export interface DataIndex {
  updated_at: string;
  subscribed_podcasts: IndexSubscribedPodcast[];
  recent_summarized_episodes: IndexRecentEpisode[];
  rankings_updated_at: string;
}

// ========== Search Index ==========

export interface SearchIndexEntry {
  episode_id: string;
  podcast_id: string;
  podcast_name: string;
  title: string;
  summary: string;
  published_at: string;
}

export interface SearchIndex {
  updated_at: string;
  entries: SearchIndexEntry[];
}
