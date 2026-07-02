// ========== 前端展示用类型（来自 data/） ==========

export interface RankingPodcast {
  id: string;
  name: string;
  rank: number;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  author: string;
}

export interface RankingsData {
  fetched_at: string;
  source: string;
  podcasts: RankingPodcast[];
}

export interface PodcastMeta {
  id: string;
  name: string;
  author: string;
  category: string;
  logo_url: string;
  rss_feed_url: string;
  xyzrank_rank: number;
  subscribed: boolean;
  subscribed_at?: string;
}

export type ScrapeStatus = "pending" | "done" | "failed";
export type SummaryStatus = "pending" | "done" | "skipped";

export interface EpisodeMeta {
  id: string;
  podcast_id: string;
  title: string;
  audio_url: string;
  duration: number;
  published_at: string;
  link: string;
  description?: string;
  scraped_content_path: string;
  scrape_status: ScrapeStatus;
  summary_status: SummaryStatus;
  tags: string[];
}

export interface DataIndex {
  updated_at: string;
  subscribed_podcasts: {
    id: string;
    name: string;
    logo_url: string;
    category: string;
    episode_count: number;
  }[];
  recent_summarized_episodes: {
    episode_id: string;
    podcast_id: string;
    podcast_name: string;
    title: string;
    summary_status: SummaryStatus;
    published_at: string;
  }[];
  rankings_updated_at: string;
}

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

/** episode .md 解析结果（frontmatter + 摘要 + 正文） */
export interface EpisodeContent {
  frontmatter: {
    episode_id: string;
    title: string;
    summary_status: SummaryStatus;
    generated_at?: string;
    model?: string;
  };
  summary: string;
  tags: string[];
  body: string;
}
