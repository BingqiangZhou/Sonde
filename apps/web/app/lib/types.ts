/** 站点 API 返回类型（与 apps/api site 路由对齐）。 */

export interface SiteMeta {
  name: string;
  nameEn: string;
  subject: string;
  homeTitle: string;
  description: string;
  tagline: string;
}

/** 时间线条目：全部信息来自 RSS 本身（无 AI 字段）。 */
export interface EpisodeListItem {
  id: number;
  sourceId: number;
  podcast: string;
  imageUrl: string | null;
  title: string;
  /** 单集页面链接；feed 缺 <link> 时为音频地址 */
  url: string | null;
  /** ISO 字符串 */
  publishedAt: string | null;
  durationSeconds: number | null;
  shownotes: string | null;
}

export interface EpisodesPage {
  items: EpisodeListItem[];
  page: number;
  pageSize: number;
  hasMore: boolean;
}
