/** Apple Podcasts 发现（iTunes Search API）：
 *  - 搜索：多国商店并发查询，按 feedUrl 合并去重；
 *  - 热门榜：各国 toppodcasts RSS 取 id 顺序，再一次 lookup 批量换 feedUrl。
 *  免费官方接口（无需 Key），不走 receipts；模块内做 5 分钟缓存以尊重限频（约 20 次/分钟）。 */

import { lookup as dnsLookup } from 'node:dns/promises';
import { Resolver } from 'node:dns/promises';
import type { LookupAddress } from 'node:dns';

import { Agent, ProxyAgent, fetch as undiciFetch } from 'undici';
import type { Dispatcher } from 'undici';
import { z } from 'zod';

import { loadConfig } from '../config.ts';
import { ProviderError } from '../errors.ts';

export interface DiscoveredPodcast {
  collectionId: number;
  name: string;
  author: string | null;
  genre: string | null;
  trackCount: number | null;
  artworkUrl: string | null;
  feedUrl: string | null;
  appleUrl: string | null;
  /** 热门榜名次（仅榜单结果有值） */
  rank: number | null;
  /** 上架的商店国家码（搜索结果可能命中多国） */
  stores: string[];
}

const ITUNES_BASE = 'https://itunes.apple.com';
const USER_AGENT = 'SondeBot/1.0 (+https://github.com/BingqiangZhou/Sonde)';
const REQUEST_TIMEOUT_MS = 10_000;

/** 仅本客户端使用的出站定制（按配置缓存）：
 *  - ITUNES_DNS：自定义 DNS（如 1.1.1.1 取 Apple 全球 CDN），失败回退系统解析；
 *  - ITUNES_PROXY_URL：经 HTTP 代理出站（如 Clash http://host.docker.internal:7897），
 *    代理本身负责解析与路由，DNS 定制被忽略。
 *  两者皆空时直接用系统 fetch。 */
const agentsByConfig = new Map<string, Dispatcher>();

function itunesDispatcher(dnsServer: string, proxyUrl: string): Dispatcher | null {
  if (!dnsServer && !proxyUrl) {
    return null;
  }
  const key = `${dnsServer}|${proxyUrl}`;
  let agent = agentsByConfig.get(key);
  if (!agent) {
    agent = proxyUrl
      ? new ProxyAgent({ uri: proxyUrl })
      : new Agent({
          connect: {
            lookup(hostname, opts, callback) {
              resolverFor(dnsServer)
                .resolve4(hostname)
                .then((addresses) => {
                  const results: LookupAddress[] = addresses.map((address) => ({ address, family: 4 }));
                  callback(null, results);
                })
                .catch(() => {
                  // 自定义 DNS 不可用时回退系统解析，保证可用性优先
                  dnsLookup(hostname, { all: true, family: opts.family })
                    .then((result) => callback(null, result as LookupAddress[]))
                    .catch((err: Error) => callback(err, []));
                });
            },
          },
        });
    agentsByConfig.set(key, agent);
  }
  return agent;
}

function resolverFor(dnsServer: string): Resolver {
  const resolver = new Resolver();
  resolver.setServers([dnsServer]);
  return resolver;
}

// zod 宽松校验：仅约束我们真正消费的字段，其余 passthrough 容忍上游加减字段。
const searchItemSchema = z
  .object({
    collectionId: z.number(),
    trackName: z.string(),
    artistName: z.string().nullish(),
    primaryGenreName: z.string().nullish(),
    trackCount: z.number().nullish(),
    artworkUrl600: z.string().nullish(),
    feedUrl: z.string().nullish(),
    trackViewUrl: z.string().nullish(),
  })
  .passthrough();

const searchResponseSchema = z.object({ results: z.array(searchItemSchema) }).passthrough();

const chartEntrySchema = z
  .object({
    id: z.object({ attributes: z.object({ 'im:id': z.string() }) }),
    'im:name': z.object({ label: z.string() }).optional(),
    'im:artist': z.object({ label: z.string() }).optional(),
    'im:image': z.array(z.object({ label: z.string() })).optional(),
  })
  .passthrough();

const chartResponseSchema = z
  .object({ feed: z.object({ entry: z.union([z.array(chartEntrySchema), chartEntrySchema]).optional() }) })
  .passthrough();

type SearchItem = z.infer<typeof searchItemSchema>;
type ChartEntry = z.infer<typeof chartEntrySchema>;

// ── 5 分钟内存缓存（对齐 Apple 榜单/搜索的数据更新节奏，并远离限频）──
const CACHE_TTL_MS = 5 * 60 * 1000;
const CACHE_MAX_ENTRIES = 50;
const cache = new Map<string, { at: number; value: unknown }>();

function cacheGet<T>(key: string): T | undefined {
  const hit = cache.get(key);
  if (!hit) {
    return undefined;
  }
  if (Date.now() - hit.at > CACHE_TTL_MS) {
    cache.delete(key);
    return undefined;
  }
  return hit.value as T;
}

function cacheSet(key: string, value: unknown): void {
  cache.set(key, { at: Date.now(), value });
  while (cache.size > CACHE_MAX_ENTRIES) {
    const oldest = cache.keys().next().value;
    if (oldest === undefined) {
      break;
    }
    cache.delete(oldest);
  }
}

/** 测试辅助：清空模块级缓存。 */
export function clearItunesCache(): void {
  cache.clear();
}

async function fetchJson(url: string): Promise<unknown> {
  const init = {
    headers: { 'user-agent': USER_AGENT, accept: 'application/json' },
    redirect: 'follow' as const,
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  };
  let res: Response;
  try {
    // 配置了自定义 DNS / 代理时走 undici fetch + dispatcher（Node 内置 fetch 不接受
    // 外部 undici 的 dispatcher，会抛 UND_ERR_INVALID_ARG）
    const { itunesDns, itunesProxyUrl } = loadConfig();
    const dispatcher = itunesDispatcher(itunesDns, itunesProxyUrl);
    res = dispatcher
      ? ((await undiciFetch(url, { ...init, dispatcher })) as Response)
      : await fetch(url, init);
  } catch (err) {
    throw new ProviderError('itunes', `请求失败：${err instanceof Error ? err.message : String(err)}`);
  }
  if (!res.ok) {
    throw new ProviderError('itunes', `上游返回 HTTP ${res.status}`);
  }
  try {
    return await res.json();
  } catch {
    throw new ProviderError('itunes', '响应不是有效 JSON');
  }
}

function parseOrThrow<T>(schema: z.ZodType<T>, value: unknown, what: string): T {
  const parsed = schema.safeParse(value);
  if (!parsed.success) {
    throw new ProviderError('itunes', `${what}响应结构异常`);
  }
  return parsed.data;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(Math.round(value), min), max);
}

/** 多国商店并发搜索并合并去重（同一播客常在多国上架、feed 相同）。
 *  个别国家失败不拖垮整体；全部失败才抛 ProviderError。 */
export async function searchItunesPodcasts(options: {
  term: string;
  countries: string[];
  limit?: number;
}): Promise<DiscoveredPodcast[]> {
  const term = options.term.trim();
  if (!term) {
    return [];
  }
  const countries = [...new Set(options.countries.map((c) => c.trim().toUpperCase()))].filter(Boolean);
  if (countries.length === 0) {
    return [];
  }
  const limit = clamp(options.limit ?? 20, 1, 50);
  const cacheKey = `search|${countries.join(',')}|${limit}|${term.toLowerCase()}`;
  const cached = cacheGet<DiscoveredPodcast[]>(cacheKey);
  if (cached) {
    return cached;
  }

  const settled = await Promise.allSettled(
    countries.map(async (country) => {
      const url =
        `${ITUNES_BASE}/search?term=${encodeURIComponent(term)}` +
        `&media=podcast&country=${encodeURIComponent(country)}&lang=zh_cn&limit=${limit}`;
      const data = parseOrThrow(searchResponseSchema, await fetchJson(url), '搜索');
      return data.results.map((item) => ({ country, item }));
    }),
  );

  const byKey = new Map<string, DiscoveredPodcast>();
  let failures = 0;
  let firstError: unknown = null;
  for (const outcome of settled) {
    if (outcome.status === 'rejected') {
      failures += 1;
      firstError ??= outcome.reason;
      continue;
    }
    for (const { country, item } of outcome.value) {
      const key = item.feedUrl?.toLowerCase() ?? `id:${item.collectionId}`;
      const existing = byKey.get(key);
      if (existing) {
        if (!existing.stores.includes(country)) {
          existing.stores.push(country);
        }
        continue;
      }
      byKey.set(key, {
        collectionId: item.collectionId,
        name: item.trackName,
        author: item.artistName ?? null,
        genre: item.primaryGenreName ?? null,
        trackCount: item.trackCount ?? null,
        artworkUrl: item.artworkUrl600 ?? null,
        feedUrl: item.feedUrl ?? null,
        appleUrl: item.trackViewUrl ?? null,
        rank: null,
        stores: [country],
      });
    }
  }

  if (failures === countries.length) {
    if (firstError instanceof Error) {
      throw firstError;
    }
    throw new ProviderError('itunes', '全部商店搜索失败');
  }

  const results = [...byKey.values()];
  cacheSet(cacheKey, results);
  return results;
}

/** 某国热门播客榜：榜单 RSS 提供名次与 id，lookup 一次批量补全 feedUrl 等字段。 */
export async function fetchItunesTopPodcasts(options: {
  country: string;
  limit?: number;
}): Promise<DiscoveredPodcast[]> {
  const country = options.country.trim().toUpperCase();
  const limit = clamp(options.limit ?? 50, 1, 50);
  const cacheKey = `top|${country}|${limit}`;
  const cached = cacheGet<DiscoveredPodcast[]>(cacheKey);
  if (cached) {
    return cached;
  }

  const chart = parseOrThrow(
    chartResponseSchema,
    await fetchJson(`${ITUNES_BASE}/${country}/rss/toppodcasts/limit=${limit}/json`),
    '榜单',
  );
  // Atom 转 JSON 的怪癖：只有一条时 entry 是对象而非数组
  const rawEntries = chart.feed.entry;
  const entries: ChartEntry[] = Array.isArray(rawEntries) ? rawEntries : rawEntries ? [rawEntries] : [];
  if (entries.length === 0) {
    return [];
  }

  const ids = entries.map((entry) => entry.id.attributes['im:id']);
  const lookup = parseOrThrow(
    searchResponseSchema,
    await fetchJson(`${ITUNES_BASE}/lookup?id=${ids.join(',')}`),
    '榜单详情',
  );
  const byId = new Map<number, SearchItem>(lookup.results.map((item) => [item.collectionId, item]));

  const results = entries.map((entry, index) => {
    const id = Number.parseInt(entry.id.attributes['im:id'], 10);
    const detail = byId.get(id);
    const images = entry['im:image'] ?? [];
    return {
      collectionId: id,
      name: detail?.trackName ?? entry['im:name']?.label ?? `#${id}`,
      author: detail?.artistName ?? entry['im:artist']?.label ?? null,
      genre: detail?.primaryGenreName ?? null,
      trackCount: detail?.trackCount ?? null,
      artworkUrl: detail?.artworkUrl600 ?? images[images.length - 1]?.label ?? null,
      feedUrl: detail?.feedUrl ?? null,
      appleUrl: detail?.trackViewUrl ?? null,
      rank: index + 1,
      stores: [country],
    };
  });
  cacheSet(cacheKey, results);
  return results;
}
