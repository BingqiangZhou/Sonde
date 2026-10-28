import { afterEach, describe, expect, it, vi } from 'vitest';

import {
  clearItunesCache,
  fetchItunesTopPodcasts,
  searchItunesPodcasts,
} from '../src/sources/itunes.ts';

function jsonResponse(body: unknown) {
  return {
    ok: true,
    status: 200,
    json: async () => body,
  };
}

function errorResponse(status: number) {
  return {
    ok: false,
    status,
    text: async () => 'upstream error',
  };
}

function searchResult(overrides: Record<string, unknown> = {}) {
  return {
    wrapperType: 'track',
    kind: 'podcast',
    collectionId: 1001,
    trackName: '示例播客',
    artistName: '主播',
    primaryGenreName: 'Business',
    trackCount: 42,
    artworkUrl600: 'https://example.com/art.jpg',
    feedUrl: 'https://feed.example.com/rss.xml',
    trackViewUrl: 'https://podcasts.apple.com/podcast/id1001',
    ...overrides,
  };
}

function chartEntry(id: string, name: string) {
  return {
    id: { attributes: { 'im:id': id } },
    'im:name': { label: name },
    'im:artist': { label: '榜单作者' },
    'im:image': [{ label: 'https://example.com/55.png' }, { label: 'https://example.com/170.png' }],
  };
}

/** 按请求 URL 分发的 fetch mock。 */
function routeFetch(routes: Array<{ match: (url: string) => boolean; respond: (url: string) => unknown }>) {
  return vi.fn(async (input: string | URL | Request) => {
    const url = String(input);
    for (const route of routes) {
      if (route.match(url)) {
        return route.respond(url);
      }
    }
    throw new Error(`unexpected fetch: ${url}`);
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  clearItunesCache();
});

describe('searchItunesPodcasts', () => {
  it('normalizes a single-store search result', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.startsWith('https://itunes.apple.com/search'),
        respond: () => jsonResponse({ resultCount: 1, results: [searchResult()] }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    const results = await searchItunesPodcasts({ term: '示例', countries: ['CN'], limit: 20 });

    expect(results).toHaveLength(1);
    expect(results[0]).toMatchObject({
      collectionId: 1001,
      name: '示例播客',
      author: '主播',
      genre: 'Business',
      trackCount: 42,
      artworkUrl: 'https://example.com/art.jpg',
      feedUrl: 'https://feed.example.com/rss.xml',
      appleUrl: 'https://podcasts.apple.com/podcast/id1001',
      rank: null,
      stores: ['CN'],
    });
    const url = fetchMock.mock.calls[0]?.[0] as string;
    expect(url).toContain('term=%E7%A4%BA%E4%BE%8B');
    expect(url).toContain('country=CN');
    expect(url).toContain('media=podcast');
    expect(url).toContain('limit=20');
  });

  it('merges and dedupes multi-store searches by feedUrl', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.includes('country=CN'),
        respond: () =>
          jsonResponse({
            results: [
              searchResult({ collectionId: 1001, trackName: '同一播客' }),
              searchResult({ collectionId: 1002, trackName: '仅 CN', feedUrl: 'https://cn.example.com/rss.xml' }),
            ],
          }),
      },
      {
        match: (url) => url.includes('country=US'),
        respond: () =>
          jsonResponse({
            results: [
              // 同一 feed、不同商店不同 collectionId → 合并
              searchResult({
                collectionId: 9001,
                trackName: '同一播客（US 名）',
                feedUrl: 'https://FEED.example.com/rss.xml',
              }),
            ],
          }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    const results = await searchItunesPodcasts({ term: '播客', countries: ['cn', 'us'] });

    expect(results).toHaveLength(2);
    const merged = results.find((r) => r.collectionId === 1001);
    expect(merged?.stores).toEqual(['CN', 'US']);
    expect(merged?.name).toBe('同一播客'); // 先见者（按国家顺序）为准
    expect(results.find((r) => r.collectionId === 1002)?.stores).toEqual(['CN']);
  });

  it('keeps items without feedUrl but dedupes them by collectionId', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.includes('country=CN'),
        respond: () => jsonResponse({ results: [searchResult({ feedUrl: undefined })] }),
      },
      {
        match: (url) => url.includes('country=US'),
        respond: () => jsonResponse({ results: [searchResult({ feedUrl: undefined })] }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    const results = await searchItunesPodcasts({ term: '独占', countries: ['CN', 'US'] });

    expect(results).toHaveLength(1);
    expect(results[0]?.feedUrl).toBeNull();
    expect(results[0]?.stores).toEqual(['CN', 'US']);
  });

  it('returns partial results when one store fails', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.includes('country=CN'),
        respond: () => errorResponse(403),
      },
      {
        match: (url) => url.includes('country=US'),
        respond: () => jsonResponse({ results: [searchResult()] }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    const results = await searchItunesPodcasts({ term: '容错', countries: ['CN', 'US'] });

    expect(results).toHaveLength(1);
    expect(results[0]?.stores).toEqual(['US']);
  });

  it('throws ProviderError when every store fails', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.startsWith('https://itunes.apple.com/search'),
        respond: () => errorResponse(403),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    await expect(searchItunesPodcasts({ term: '全挂', countries: ['CN', 'US'] })).rejects.toThrow(
      /itunes: 上游返回 HTTP 403/,
    );
  });

  it('throws ProviderError on malformed JSON body', async () => {
    const fetchMock = vi.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => {
        throw new Error('not json');
      },
    }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(searchItunesPodcasts({ term: '坏响应', countries: ['CN'] })).rejects.toThrow(/itunes/);
  });

  it('throws ProviderError when the response structure is unexpected', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.startsWith('https://itunes.apple.com/search'),
        respond: () => jsonResponse({ unexpected: true }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    await expect(searchItunesPodcasts({ term: '结构', countries: ['CN'] })).rejects.toThrow(/结构异常/);
  });

  it('caches identical queries for five minutes', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.startsWith('https://itunes.apple.com/search'),
        respond: () => jsonResponse({ results: [searchResult()] }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    await searchItunesPodcasts({ term: '缓存', countries: ['CN'] });
    await searchItunesPodcasts({ term: '缓存', countries: ['CN'] });

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});

describe('fetchItunesTopPodcasts', () => {
  function chartRoutes(entries: unknown[], lookupResults: unknown[]) {
    return [
      {
        match: (url: string) => url.includes('/rss/toppodcasts/'),
        respond: () => jsonResponse({ feed: { entry: entries } }),
      },
      {
        match: (url: string) => url.startsWith('https://itunes.apple.com/lookup'),
        respond: () => jsonResponse({ resultCount: lookupResults.length, results: lookupResults }),
      },
    ];
  }

  it('merges chart rank order with lookup details', async () => {
    const fetchMock = routeFetch(
      chartRoutes(
        [chartEntry('111', '甲'), chartEntry('222', '乙')],
        [
          searchResult({ collectionId: 222, trackName: '乙（详情）', feedUrl: 'https://b.example.com/rss.xml' }),
          searchResult({ collectionId: 111, trackName: '甲（详情）', feedUrl: 'https://a.example.com/rss.xml' }),
        ],
      ),
    );
    vi.stubGlobal('fetch', fetchMock);

    const results = await fetchItunesTopPodcasts({ country: 'cn' });

    expect(fetchMock.mock.calls[0]?.[0]).toContain('/CN/rss/toppodcasts/limit=50/json');
    expect(fetchMock.mock.calls[1]?.[0]).toContain('lookup?id=111,222');
    expect(results).toHaveLength(2);
    expect(results[0]).toMatchObject({ collectionId: 111, name: '甲（详情）', rank: 1, feedUrl: 'https://a.example.com/rss.xml' });
    expect(results[1]).toMatchObject({ collectionId: 222, name: '乙（详情）', rank: 2, stores: ['CN'] });
  });

  it('falls back to chart entry metadata when lookup misses an id', async () => {
    const fetchMock = routeFetch(
      chartRoutes([chartEntry('111', '只剩榜单')], [searchResult({ collectionId: 999 })]),
    );
    vi.stubGlobal('fetch', fetchMock);

    const results = await fetchItunesTopPodcasts({ country: 'CN' });

    expect(results).toHaveLength(1);
    expect(results[0]).toMatchObject({
      collectionId: 111,
      name: '只剩榜单',
      author: '榜单作者',
      artworkUrl: 'https://example.com/170.png', // im:image 取最大那张
      feedUrl: null,
    });
  });

  it('wraps a single (non-array) chart entry', async () => {
    const fetchMock = routeFetch([
      {
        // Atom JSON 的怪癖：榜单只有一条时 entry 是对象而非数组
        match: (url) => url.includes('/rss/toppodcasts/'),
        respond: () => jsonResponse({ feed: { entry: chartEntry('111', '唯一') } }),
      },
      {
        match: (url) => url.startsWith('https://itunes.apple.com/lookup'),
        respond: () => jsonResponse({ results: [searchResult({ collectionId: 111 })] }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    const results = await fetchItunesTopPodcasts({ country: 'CN', limit: 1 });

    expect(results).toHaveLength(1);
    expect(results[0]?.name).toBe('示例播客'); // lookup 详情优先于榜单条目名
  });

  it('returns empty for an empty chart', async () => {
    const fetchMock = routeFetch([
      {
        match: (url) => url.includes('/rss/toppodcasts/'),
        respond: () => jsonResponse({ feed: {} }),
      },
    ]);
    vi.stubGlobal('fetch', fetchMock);

    const results = await fetchItunesTopPodcasts({ country: 'CN' });

    expect(results).toEqual([]);
  });

  it('caches the chart per country and limit', async () => {
    const fetchMock = routeFetch(
      chartRoutes([chartEntry('111', '甲')], [searchResult({ collectionId: 111 })]),
    );
    vi.stubGlobal('fetch', fetchMock);

    await fetchItunesTopPodcasts({ country: 'CN' });
    await fetchItunesTopPodcasts({ country: 'CN' });
    await fetchItunesTopPodcasts({ country: 'CN', limit: 10 });

    expect(fetchMock).toHaveBeenCalledTimes(4); // (榜单+lookup) × 2 种缓存键
  });
});
