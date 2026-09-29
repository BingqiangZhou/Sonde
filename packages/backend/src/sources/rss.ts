/** 播客 RSS 采集：条件 GET + rss-parser 解析 → 标准化单集输入。
 *  解析逻辑全部为纯函数（episodeInputsFromFeed），便于单测。 */

import Parser from 'rss-parser';

export interface RssEpisodeInput {
  guid: string;
  title: string;
  url: string | null;
  author: string | null;
  publishedAt: Date | null;
  shownotes: string | null;
  durationSeconds: number | null;
  enclosureUrl: string | null;
  enclosureBytes: number | null;
}

export interface ParsedFeedItem {
  guid?: string;
  id?: string;
  title?: string;
  link?: string;
  creator?: string;
  author?: string;
  isoDate?: string;
  pubDate?: string;
  contentSnippet?: string;
  content?: string;
  enclosure?: { url?: string; length?: string; type?: string };
  itunesDuration?: string;
}

export interface FeedFetchResult {
  feedTitle: string | null;
  episodes: RssEpisodeInput[];
  etag: string | null;
  lastModified: string | null;
}

const USER_AGENT = 'SondeBot/1.0 (+https://github.com/BingqiangZhou/Sonde)';

const parser = new Parser({
  timeout: 30_000,
  headers: { 'user-agent': USER_AGENT },
  customFields: {
    feed: ['title'],
    item: [
      ['itunes:duration', 'itunesDuration'],
      ['itunes:author', 'itunesAuthor'],
    ],
  },
});

export class FeedNotModifiedError extends Error {
  constructor() {
    super('feed not modified');
    this.name = 'FeedNotModifiedError';
  }
}

/** 抓取并解析一个播客 feed（支持 ETag / Last-Modified 条件请求与首导截断）。 */
export async function fetchPodcastFeed(
  feedUrl: string,
  options: {
    etag?: string | null;
    lastModified?: string | null;
    /** 首次导入时为 true：按 firstImportDays/Limit 截断，避免转写整个存档 */
    firstImport?: boolean;
  } = {},
): Promise<FeedFetchResult> {
  const res = await fetch(feedUrl, {
    headers: {
      'user-agent': USER_AGENT,
      accept: 'application/rss+xml, application/xml, text/xml, */*',
      ...(options.etag ? { 'if-none-match': options.etag } : {}),
      ...(options.lastModified ? { 'if-modified-since': options.lastModified } : {}),
    },
    redirect: 'follow',
    signal: AbortSignal.timeout(60_000),
  });

  if (res.status === 304) {
    throw new FeedNotModifiedError();
  }
  if (!res.ok) {
    throw new Error(`feed fetch failed: ${res.status}`);
  }
  const xml = await res.text();
  const parsed = (await parser.parseString(xml)) as unknown as {
    title?: string;
    items?: ParsedFeedItem[];
  };

  return {
    feedTitle: parsed.title ?? null,
    episodes: episodeInputsFromFeed(parsed.items ?? [], {
      limit: 60,
      firstImport: options.firstImport,
    }),
    etag: res.headers.get('etag'),
    lastModified: res.headers.get('last-modified'),
  };
}

export interface BackfillOptions {
  /** 首次导入：最多取多少条（防止转写整个历史存档） */
  firstImportLimit: number;
  /** 首次导入：只取最近 N 天内发布的单集 */
  firstImportDays: number;
  /** 非首次：单次最多处理条数 */
  limit: number;
}

const DEFAULT_BACKFILL: BackfillOptions = {
  firstImportLimit: 10,
  firstImportDays: 14,
  limit: 60,
};

/** 解析后的 feed items → 标准化单集输入（纯函数）。
 *  - 无音频 enclosure 的条目跳过（无法转写）
 *  - guid 缺失时以 enclosure URL 兜底
 *  - 首次导入按 firstImportDays/Limit 截断 */
export function episodeInputsFromFeed(
  items: ParsedFeedItem[],
  options: Partial<BackfillOptions> & { firstImport?: boolean } = {},
): RssEpisodeInput[] {
  const opts = { ...DEFAULT_BACKFILL, ...options };
  const cutoff = opts.firstImport
    ? Date.now() - opts.firstImportDays * 24 * 60 * 60 * 1000
    : null;

  const result: RssEpisodeInput[] = [];
  for (const item of items) {
    if (result.length >= (opts.firstImport ? opts.firstImportLimit : opts.limit)) {
      break;
    }
    const enclosureUrl = item.enclosure?.url ?? null;
    if (!enclosureUrl) {
      continue;
    }
    const publishedAt = parseDate(item.isoDate ?? item.pubDate ?? null);
    if (opts.firstImport && cutoff && (publishedAt === null || publishedAt.getTime() < cutoff)) {
      continue;
    }
    const title = (item.title ?? '').trim();
    if (!title) {
      continue;
    }
    result.push({
      guid: (item.guid ?? item.id ?? enclosureUrl).trim(),
      title,
      url: item.link ?? null,
      author: item.creator ?? item.author ?? null,
      publishedAt,
      shownotes: cleanShownotes(item),
      durationSeconds: parseItunesDuration(item.itunesDuration ?? null),
      enclosureUrl,
      enclosureBytes: parsePositiveInt(item.enclosure?.length ?? null),
    });
  }
  return result;
}

/** "1:23:45" / "83:45" / "5025" → 秒 */
export function parseItunesDuration(value: string | null): number | null {
  if (!value) {
    return null;
  }
  const trimmed = value.trim();
  if (/^\d+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  const parts = trimmed.split(':').map((p) => Number.parseInt(p, 10));
  if (parts.some((p) => Number.isNaN(p))) {
    return null;
  }
  let seconds = 0;
  for (const part of parts) {
    seconds = seconds * 60 + part;
  }
  return seconds;
}

function parseDate(value: string | null): Date | null {
  if (!value) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function parsePositiveInt(value: string | null): number | null {
  if (!value) {
    return null;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function cleanShownotes(item: ParsedFeedItem): string | null {
  const text = (item.contentSnippet ?? item.content ?? '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text ? text.slice(0, 4000) : null;
}
