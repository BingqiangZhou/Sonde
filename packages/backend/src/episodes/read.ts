/** 时间线读取层：按发布时间倒序列出全部单集（直接读 episodes，无 AI 分析依赖）。
 *  支持按源(sourceId)与关键词(q,标题/简介 ILIKE)筛选 —— 关键词直查数据库,
 *  单表量小,零额外运行成本。 */

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
  /** 当前筛选条件命中的总条数;无筛选时为 null(保持"免每页 count"的既有设计) */
  total: number | null;
}

export interface EpisodeFilters {
  sourceId?: number;
  q?: string;
}

export interface SourceWithCount {
  id: number;
  name: string;
  imageUrl: string | null;
  episodeCount: number;
}

const PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 100;
const MAX_QUERY_LENGTH = 100;

/** 组装共享 WHERE(published_at 非空 + 可选筛选),返回片段文本与参数。
 *  片段由常量模板拼接(用户输入只经 $n 占位符),列表与 COUNT 两条查询复用。 */
function buildWhere(filters: EpisodeFilters): { clause: string; values: unknown[]; filtered: boolean } {
  const parts = ['e.published_at IS NOT NULL'];
  const values: unknown[] = [];

  const sourceId =
    typeof filters.sourceId === 'number' && Number.isInteger(filters.sourceId) && filters.sourceId > 0
      ? filters.sourceId
      : null;
  if (sourceId !== null) {
    values.push(sourceId);
    parts.push(`s.id = $${values.length}`);
  }

  const q = typeof filters.q === 'string' ? filters.q.trim().slice(0, MAX_QUERY_LENGTH) : '';
  if (q) {
    values.push(`%${q}%`);
    parts.push(`(e.title ILIKE $${values.length} OR e.shownotes ILIKE $${values.length})`);
  }

  return { clause: parts.join('\n      AND '), values, filtered: sourceId !== null || q !== '' };
}

/** 分页列出单集（含停抓源的历史单集；无发布日期的不进时间线）。
 *  LIMIT+1 探测 hasMore;仅在有筛选时跑一次同条件 COUNT 给前端展示"共 N 集"。 */
export async function listEpisodes(
  limit = PAGE_SIZE,
  offset = 0,
  filters: EpisodeFilters = {},
): Promise<EpisodesPage> {
  const safeLimit = Math.min(Math.max(Math.trunc(limit), 1), MAX_PAGE_SIZE);
  const safeOffset = Math.max(Math.trunc(offset), 0);
  const where = buildWhere(filters);

  const result = await rows<EpisodeListItem>({
    text: `SELECT e.id::int AS id, e.source_id::int AS "sourceId", s.name AS podcast, s.image_url AS "imageUrl",
           e.title, COALESCE(e.url, e.enclosure_url) AS url,
           e.published_at AS "publishedAt", e.duration_seconds AS "durationSeconds",
           e.shownotes
    FROM episodes e
    JOIN sources s ON s.id = e.source_id
    WHERE ${where.clause}
    ORDER BY e.published_at DESC, e.id DESC
    LIMIT $${where.values.length + 1} OFFSET $${where.values.length + 2}`,
    values: [...where.values, safeLimit + 1, safeOffset],
  });

  let total: number | null = null;
  if (where.filtered) {
    const counted = await rows<{ total: number }>({
      text: `SELECT COUNT(*)::int AS total
      FROM episodes e
      JOIN sources s ON s.id = e.source_id
      WHERE ${where.clause}`,
      values: where.values,
    });
    total = counted[0]?.total ?? 0;
  }

  return {
    items: result.slice(0, safeLimit),
    hasMore: result.length > safeLimit,
    pageSize: safeLimit,
    total,
  };
}

/** 列出"有历史单集"的源及其条数(筛选 chips 数据)。
 *  含停更源 —— 时间线本就展示其历史;0 集的源没有可筛内容,不出现。
 *  id 是 BIGINT IDENTITY,pg 驱动会回字符串 —— ::int 转型保证 JSON 里是数字,
 *  前端拿它与 URL 里的 ?source= 数字做严格比较。 */
export async function listSourcesWithCounts(): Promise<SourceWithCount[]> {
  const result = await rows<{ id: number; name: string; imageUrl: string | null; episodeCount: number }>(sql`
    SELECT s.id::int AS id, s.name, s.image_url AS "imageUrl", COUNT(e.id)::int AS "episodeCount"
    FROM sources s
    JOIN episodes e ON e.source_id = s.id AND e.published_at IS NOT NULL
    GROUP BY s.id, s.name, s.image_url
    HAVING COUNT(e.id) > 0
    ORDER BY COUNT(e.id) DESC, s.name ASC
  `);
  return result;
}
