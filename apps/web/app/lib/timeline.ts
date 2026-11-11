/** 时间线纯函数:?page/&source/&q 的宽容解析、api 路径组装、按北京日分组。
 *  home 首屏 loader 与 /resources/episodes 资源路由共用,两侧解析永不漂移。 */
import type { EpisodeListItem } from './types.ts';

import { formatWeekdayCn, shanghaiYmd } from './format.ts';

export interface TimelineQuery {
  page: number;
  source: number | null;
  q: string | null;
}

/** ?page=&source=&q= 的宽容解析(垃圾值一律回落,语义与 api 路由一致)。 */
export function parseTimelineQuery(url: URL): TimelineQuery {
  const page = Math.max(1, Number.parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
  const sourceParam = Number.parseInt(url.searchParams.get('source') ?? '', 10);
  const source = Number.isInteger(sourceParam) && sourceParam > 0 ? sourceParam : null;
  const q = (url.searchParams.get('q') ?? '').trim().slice(0, 100) || null;
  return { page, source, q };
}

/** 组装 /site/episodes 的 api 路径(q 编码,缺省筛选省略)。 */
export function episodesApiPath(query: TimelineQuery): string {
  let path = `/site/episodes?page=${query.page}`;
  if (query.source) {
    path += `&source=${query.source}`;
  }
  if (query.q) {
    path += `&q=${encodeURIComponent(query.q)}`;
  }
  return path;
}

export interface TimelineDay {
  /** 'YYYY-MM-DD'(北京日键)| 'unknown' */
  key: string;
  /** '2026' | null(未知日期组) */
  year: string | null;
  /** '11月5日'(月日不补零)| '日期未知' */
  label: string;
  /** '周三' | null */
  weekday: string | null;
  /** <time dateTime> 用 */
  isoDate: string | null;
  items: EpisodeListItem[];
}

function labelFromYmd(ymd: string): string {
  const [, month = '1', day = '1'] = ymd.split('-');
  return `${Number(month)}月${Number(day)}日`;
}

/** 把单集列表按北京日合并为「天」:单趟遍历,只合并**连续**同日条目。
 *  输入来自 api(ORDER BY published_at DESC, id DESC),追加批严格更早,
 *  连续合并天然把首页尾部与无限滚动追加批的头部熔为同一天。
 *  空/非法日期(防御路径,后端已排除)落入「日期未知」组。 */
export function groupTimelineDays(items: readonly EpisodeListItem[]): TimelineDay[] {
  const groups: TimelineDay[] = [];
  for (const entry of items) {
    const ymd = shanghaiYmd(entry.publishedAt);
    const key = ymd ?? 'unknown';
    const last: TimelineDay | undefined = groups[groups.length - 1];
    if (last && last.key === key) {
      last.items.push(entry);
      continue;
    }
    groups.push(
      ymd
        ? {
            key,
            year: ymd.slice(0, 4),
            label: labelFromYmd(ymd),
            weekday: formatWeekdayCn(entry.publishedAt),
            isoDate: ymd,
            items: [entry],
          }
        : { key, year: null, label: '日期未知', weekday: null, isoDate: null, items: [entry] },
    );
  }
  return groups;
}
