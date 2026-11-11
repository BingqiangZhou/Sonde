/** 时间线读取层：按发布时间倒序列出全部单集（直接读 episodes，无 AI 分析依赖）。 */

import { rows, sql } from '../db/db.ts';

export interface EpisodeListItem {
  id: number;
  sourceId: number;
  podcast: string;
  imageUrl: string | null;
  title: string;
  /** 单集页面链接；feed 缺 <link> 时兜底音频地址 */
  url: string | null;
  publishedAt: Date | null;
  durationSeconds: number | null;
  shownotes: string | null;
}

export interface EpisodesPage {
  items: EpisodeListItem[];
  hasMore: boolean;
  pageSize: number;
}

const PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 100;

/** 分页列出全部单集（含停抓源的历史单集；无发布日期的不进时间线）。
 *  LIMIT+1 探测 hasMore，免每页 count(*)。 */
export async function listEpisodes(limit = PAGE_SIZE, offset = 0): Promise<EpisodesPage> {
  const safeLimit = Math.min(Math.max(Math.trunc(limit), 1), MAX_PAGE_SIZE);
  const safeOffset = Math.max(Math.trunc(offset), 0);
  const result = await rows<EpisodeListItem>(sql`
    SELECT e.id, e.source_id AS "sourceId", s.name AS podcast, s.image_url AS "imageUrl",
           e.title, COALESCE(e.url, e.enclosure_url) AS url,
           e.published_at AS "publishedAt", e.duration_seconds AS "durationSeconds",
           e.shownotes
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    WHERE e.published_at IS NOT NULL
    ORDER BY e.published_at DESC, e.id DESC
    LIMIT ${safeLimit + 1} OFFSET ${safeOffset}
  `);
  return {
    items: result.slice(0, safeLimit),
    hasMore: result.length > safeLimit,
    pageSize: safeLimit,
  };
}
