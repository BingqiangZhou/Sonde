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
  /** 筛选/搜索命中的总条数;无筛选时为 null */
  total: number | null;
}

/** 资源路由 /resources/episodes 的单批响应(无限滚动追加页):EpisodesPage 的瘦载荷。 */
export interface EpisodesBatch {
  items: EpisodeListItem[];
  page: number;
  hasMore: boolean;
  /** api 暂不可达:items 恒空,客户端应提示并允许重试 */
  error?: true;
}

/** 订阅源(筛选 chips 数据):含停更源的历史,0 集的源不下发。 */
export interface SourceListItem {
  id: number;
  name: string;
  imageUrl: string | null;
  episodeCount: number;
}

export interface SourcesList {
  items: SourceListItem[];
}
