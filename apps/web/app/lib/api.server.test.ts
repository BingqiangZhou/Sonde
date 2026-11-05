import { afterEach, describe, expect, it, vi } from 'vitest';

const { apiGet } = await import('./api.server.ts');

function statusResponse(status: number) {
  return { ok: status >= 200 && status < 300, status, json: async () => ({ value: 1 }) };
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
