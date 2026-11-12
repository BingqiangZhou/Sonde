import { afterEach, describe, expect, it, vi } from 'vitest';

const { apiGet, apiGetWithHeaders } = await import('./api.server.ts');

function statusResponse(status: number) {
  // headers 与真实 Response 对齐:读取路径现在会取 etag(apiGet 委托 apiGetWithHeaders)
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => ({ value: 1 }),
    headers: { get: () => null },
  };
}

function responseWithEtag(status: number, body: unknown, etag: string | null) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    headers: { get: (name: string) => (name.toLowerCase() === 'etag' ? etag : null) },
  };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('apiGet 错误分层', () => {
  it('200 → 返回解析后的 JSON', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => statusResponse(200)));
    await expect(apiGet('/site/meta')).resolves.toEqual({ value: 1 });
  });

  it('404/401/403 → null（“还没有”/未登录空态，各 loader 零改动）', async () => {
    for (const status of [404, 401, 403]) {
      vi.stubGlobal('fetch', vi.fn(async () => statusResponse(status)));
      await expect(apiGet(`/x/${status}`)).resolves.toBeNull();
    }
  });

  it('5xx → 抛 Response（携带 .status）——框架原生通道，ErrorBoundary 可判型', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => statusResponse(502)));
    const error = await apiGet('/site/reports/daily/latest').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(Response);
    expect((error as Response).status).toBe(502);
  });

  it('网络/超时 → 抛 Response(503)', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new TypeError('fetch failed');
    }));
    const error = await apiGet('/site/meta').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(Response);
    expect((error as Response).status).toBe(503);
  });
});

describe('apiGetWithHeaders 错误分层 + ETag 透传', () => {
  it('200 → 返回 { data, etag }(api 的弱 ETag 原样带回,供资源路由转发)', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => responseWithEtag(200, { items: [1] }, 'W/"abc123def4567890"')),
    );
    await expect(apiGetWithHeaders('/site/episodes')).resolves.toEqual({
      data: { items: [1] },
      etag: 'W/"abc123def4567890"',
    });
  });

  it('200 无 ETag → etag 为 null;404 → null;5xx → 抛 Response(与 apiGet 同层)', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => responseWithEtag(200, { ok: 1 }, null)));
    await expect(apiGetWithHeaders('/site/meta')).resolves.toEqual({ data: { ok: 1 }, etag: null });

    vi.stubGlobal('fetch', vi.fn(async () => responseWithEtag(404, {}, null)));
    await expect(apiGetWithHeaders('/site/episodes')).resolves.toBeNull();

    vi.stubGlobal('fetch', vi.fn(async () => responseWithEtag(502, {}, 'W/"x"')));
    const error = await apiGetWithHeaders('/site/episodes').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(Response);
    expect((error as Response).status).toBe(502);
  });
});
