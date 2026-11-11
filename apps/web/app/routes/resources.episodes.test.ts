import { afterEach, describe, expect, it, vi } from 'vitest';

const { loader, headers } = await import('./resources.episodes.ts');

function jsonResponse(status: number, body: unknown) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}

function call(url: string) {
  return { request: new Request(url) };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

/** 无限滚动的追加批接口:瘦载荷(items/page/hasMore),绝不向 fetcher 抛错
 *  (fetcher.load 的 loader 错误会冒泡到最近 ErrorBoundary,顶掉整页)。 */
describe('GET /resources/episodes loader', () => {
  it('透传 api 的 items/page/hasMore(丢 pageSize/total),query(含 category)原样转交 api', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) =>
      jsonResponse(200, { items: [{ id: 1 }], page: 2, pageSize: 50, hasMore: true, total: null }),
    );
    vi.stubGlobal('fetch', fetchMock);
    const data = await loader(
      call('https://x/resources/episodes?page=2&source=3&category=%E7%A7%91%E6%8A%80&q=%E6%B7%B1%E5%BA%A6'),
    );
    expect(data).toEqual({ items: [{ id: 1 }], page: 2, hasMore: true });
    const calledUrl = String(fetchMock.mock.calls[0]?.[0] ?? '');
    expect(calledUrl).toContain('/api/site/episodes?page=2&source=3&category=%E7%A7%91%E6%8A%80&q=');
  });

  it('api 不可达(apiGet 抛 Response)→ 200 error 批,不抛出', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse(503, {})));
    await expect(loader(call('https://x/resources/episodes?page=3'))).resolves.toEqual({
      items: [],
      page: 3,
      hasMore: false,
      error: true,
    });
  });

  it('api 404(apiGet → null)→ 静默到头,不标 error', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse(404, {})));
    await expect(loader(call('https://x/resources/episodes?page=9'))).resolves.toEqual({
      items: [],
      page: 9,
      hasMore: false,
    });
  });

  it('响应头 no-store:偏移分页不能吃浏览器缓存', () => {
    expect(headers()['Cache-Control']).toBe('no-store');
  });
});
