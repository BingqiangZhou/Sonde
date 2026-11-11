/** xyzrank(中文播客榜)榜单接入:拉取排名前 N 的播客,映射为订阅条目。
 *  API:GET /api/podcasts?offset=&limit=(limit 单次上限 100,按 rank 升序,无需鉴权);
 *  每条 links[] 里的 {"name":"rss"} 即该播客的 RSS 地址 —— 没有 rss 链接的跳过并计数。
 *  每天 10 次请求,零运行成本。 */

import { AppError } from '../errors.ts';

import { USER_AGENT } from './rss.ts';
import type { SeedSourceEntry } from './sync.ts';

export const XYZRANK_API_BASE = 'https://xyzrank.com/api/podcasts';
export const XYZRANK_SYNC_INTERVAL_MINUTES = 10;

const PAGE_SIZE = 100;
const PAGE_TIMEOUT_MS = 30_000;

export interface XyzrankPodcastLink {
  name: string;
  url: string;
}

export interface XyzrankPodcast {
  id: string;
  rank: number;
  name: string;
  /** Apple 中文一级/二级分类混排(如「休闲」「幽默对谈」),经 rollupGenre 归并 */
  primaryGenreName?: string;
  links?: XyzrankPodcastLink[];
}

/** 一级分类词表(17 个):chips 的全部可能取值(「其他」除外,由 NULL 分类产生)。 */
export const CATEGORY_VOCABULARY: ReadonlySet<string> = new Set([
  '休闲',
  '社会与文化',
  '商务',
  '犯罪纪实',
  '科技',
  '喜剧',
  '宗教与心灵',
  '教育',
  '新闻',
  '音乐',
  '艺术',
  '科学',
  '体育',
  '儿童与家庭',
  '健康',
  '影视',
  '人文',
]);

/** xyzrank primaryGenreName(一级+二级混排)→ 一级分类。
 *  判断均可编辑:改字典后,下一次每日同步(或 worker 重启)即全量生效。
 *  未收录/为空 → null,前端归入「其他」。 */
export const GENRE_ROLLUP: Readonly<Record<string, string>> = {
  // —— 恒等(14 个一级,原样保留)——
  休闲: '休闲',
  社会与文化: '社会与文化',
  商务: '商务',
  犯罪纪实: '犯罪纪实',
  科技: '科技',
  喜剧: '喜剧',
  宗教与心灵: '宗教与心灵',
  教育: '教育',
  新闻: '新闻',
  音乐: '音乐',
  艺术: '艺术',
  科学: '科学',
  体育: '体育',
  儿童与家庭: '儿童与家庭',
  // —— 改名(2)——
  健康与健身: '健康',
  电视与电影: '影视',
  // —— 社会与文化 ←
  个人日记: '社会与文化',
  情感与人际关系: '社会与文化',
  旅行与地方文化: '社会与文化',
  纪实: '社会与文化',
  // —— 喜剧 ←
  幽默对谈: '喜剧',
  即兴表演: '喜剧',
  // —— 商务 ←
  投资: '商务',
  职业: '商务',
  创业: '商务',
  营销: '商务',
  管理: '商务',
  // —— 健康 ←
  医学: '健康',
  心理健康: '健康',
  自我完善: '健康',
  // —— 人文 ←
  历史: '人文',
  哲学: '人文',
  图书: '人文',
  社会科学: '人文',
  小说: '人文',
  剧情: '人文',
  喜剧小说: '人文',
  // —— 教育 ←
  语言学习: '教育',
  课程: '教育',
  实用知识: '教育',
  // —— 新闻 ←
  商业新闻: '新闻',
  新闻评论: '新闻',
  娱乐新闻: '新闻',
  每日新闻: '新闻',
  // —— 音乐 ←
  音乐专访: '音乐',
  // —— 影视 ←
  影评: '影视',
  电影专访: '影视',
  电视评论: '影视',
  动画与漫画: '影视',
  节目漫谈: '影视',
  // —— 艺术 ←
  表演艺术: '艺术',
  视觉艺术: '艺术',
  设计: '艺术',
  // —— 休闲 ←
  爱好: '休闲',
  汽车: '休闲',
  饮食文化: '休闲',
};

/** primaryGenreName → 一级分类;trim 后查表,未收录/空 → null(前端「其他」)。 */
export function rollupGenre(raw: string | undefined | null): string | null {
  const trimmed = typeof raw === 'string' ? raw.trim() : '';
  return trimmed ? (GENRE_ROLLUP[trimmed] ?? null) : null;
}

interface XyzrankPage {
  items: XyzrankPodcast[];
  total: number;
}

/** 榜单条目 → 订阅条目(纯函数,单测覆盖)。
 *  要求 items 按 rank 升序传入(API 天然如此);同 feedUrl 去重时保留首个(名次更高)。 */
export function xyzrankToEntries(
  items: XyzrankPodcast[],
  options: { maxRank?: number; intervalMinutes?: number } = {},
): { entries: SeedSourceEntry[]; skipped: number } {
  const { maxRank = 1000, intervalMinutes = XYZRANK_SYNC_INTERVAL_MINUTES } = options;
  const seen = new Set<string>();
  const entries: SeedSourceEntry[] = [];
  let skipped = 0;

  for (const item of items) {
    if (typeof item.rank !== 'number' || item.rank > maxRank) {
      continue;
    }
    const name = typeof item.name === 'string' ? item.name.trim() : '';
    const feedUrl = item.links?.find((l) => l?.name === 'rss' && typeof l.url === 'string')?.url.trim() ?? '';
    if (!name || !feedUrl) {
      skipped++;
      continue;
    }
    const key = feedUrl.toLowerCase();
    if (seen.has(key)) {
      skipped++;
      continue;
    }
    seen.add(key);
    entries.push({ name, feedUrl, intervalMinutes, category: rollupGenre(item.primaryGenreName) });
  }

  return { entries, skipped };
}

/** 拉取榜单前 maxRank 名并映射为订阅条目(每页失败重试一次,全败抛 AppError)。 */
export async function fetchXyzrankTopPodcasts(
  options: { maxRank?: number } = {},
): Promise<{ entries: SeedSourceEntry[]; skipped: number }> {
  const maxRank = options.maxRank ?? 1000;
  const items: XyzrankPodcast[] = [];

  for (let offset = 0; offset < maxRank; offset += PAGE_SIZE) {
    const page = await fetchPage(offset);
    items.push(...page.items);
    if (page.items.length < PAGE_SIZE) {
      break;
    }
    // 分页间稍作停顿:10 连发容易触发对方 Cloudflare 的速率启发式(实测吃过 403)
    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  return xyzrankToEntries(items, { maxRank });
}

async function fetchPage(offset: number): Promise<XyzrankPage> {
  const url = `${XYZRANK_API_BASE}?offset=${offset}&limit=${PAGE_SIZE}`;
  let lastError: unknown;

  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const res = await fetch(url, {
        headers: {
          accept: 'application/json',
          'user-agent': USER_AGENT,
        },
        signal: AbortSignal.timeout(PAGE_TIMEOUT_MS),
      });
      if (!res.ok) {
        throw new Error(`xyzrank api ${res.status}`);
      }
      const json = (await res.json()) as XyzrankPage;
      if (!json || !Array.isArray(json.items)) {
        throw new Error('xyzrank api 响应缺少 items');
      }
      return json;
    } catch (error) {
      lastError = error;
    }
  }

  throw new AppError(`xyzrank 榜单拉取失败(offset=${offset}): ${String(lastError)}`);
}
