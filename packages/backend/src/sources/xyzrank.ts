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
  links?: XyzrankPodcastLink[];
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
    entries.push({ name, feedUrl, intervalMinutes });
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
