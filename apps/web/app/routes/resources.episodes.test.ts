import { afterEach, describe, expect, it, vi } from 'vitest';

const { loader } = await import('./resources.episodes.ts');

function jsonResponse(status: number, body: unknown, etag: string | null = null) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    headers: { get: (name: string) => (name.toLowerCase() === 'etag' ? etag : null) },
  };
}

function call(url: string, init?: RequestInit) {
  return { request: new Request(url, init) };
}

const CC_60 = 'public, max-age=60, s-maxage=60, must-revalidate';

afterEach(() => {
  vi.unstubAllGlobals();
});

/** 无限滚动的追加批接口:瘦载荷(items/page/hasMore)以 Response 交付(头随体走),
 *  绝不向 fetcher 抛错(fetcher.load 的 loader 错误会冒泡到最近 ErrorBoundary,顶掉整页)。
 *  成功批透传 api 的 ETag + 60s 缓存;If-None-Match 命中回 304;错误/到头批 no-store。 */
describe('GET /resources/episodes loader', () => {
  it('成功批:200 + 透传 api ETag 与 60s 缓存,query(含 category)原样转交 api', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) =>
      jsonResponse(200, { items: [{ id: 1 }], page: 2, pageSize: 50, hasMore: true, total: null }, 'W/"abc123def4567890"'),
    );
    vi.stubGlobal('fetch', fetchMock);

    const res = await loader(call('https://x/resources/episodes?page=2&source=3&category=%E7%A7%91%E6%8A%80&q=%E6%B7%B1%E5%BA%A6'));

    expect(res).toBeInstanceOf(Response);
    expect(res.status).toBe(200);
    expect(res.headers.get('etag')).toBe('W/"abc123def4567890"');
    expect(res.headers.get('cache-control')).toBe(CC_60);
    await expect(res.json()).resolves.toEqual({ items: [{ id: 1 }], page: 2, hasMore: true });
    const calledUrl = String(fetchMock.mock.calls[0]?.[0] ?? '');
    expect(calledUrl).toContain('/api/site/episodes?page=2&source=3&category=%E7%A7%91%E6%8A%80&q=');
  });

  it('If-None-Match 命中透传的 ETag → 304 空体(浏览器本地缓存接管,省传输)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => jsonResponse(200, { items: [], page: 2, pageSize: 50, hasMore: false, total: 0 }, 'W/"abc123def4567890"')),
    );

    const res = await loader(
      call('https://x/resources/episodes?page=2', { headers: { 'if-none-match': 'W/"abc123def4567890"' } }),
    );

    expect(res).toBeInstanceOf(Response);
    expect(res.status).toBe(304);
    expect(res.headers.get('etag')).toBe('W/"abc123def4567890"');
    expect(res.headers.get('cache-control')).toBe(CC_60);
  });

  it('api 不可达(apiGet 抛 Response)→ 200 error 批 + no-store(错误态不吃缓存)', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse(503, {})));
    const res = await loader(call('https://x/resources/episodes?page=3'));
    expect(res.status).toBe(200);
    expect(res.headers.get('cache-control')).toBe('no-store');
    await expect(res.json()).resolves.toEqual({ items: [], page: 3, hasMore: false, error: true });
  });

  it('api 404(→ null)→ 静默到头批,不标 error', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse(404, {})));
    const res = await loader(call('https://x/resources/episodes?page=9'));
    expect(res.status).toBe(200);
    await expect(res.json()).resolves.toEqual({ items: [], page: 9, hasMore: false });
  });
});
