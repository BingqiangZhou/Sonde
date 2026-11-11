import Fastify from 'fastify';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const listEpisodesMock = vi.fn();
const listSourcesWithCountsMock = vi.fn();

vi.mock('@sonde/backend', () => ({
  listEpisodes: (...args: unknown[]) => listEpisodesMock(...(args as [])),
  listSourcesWithCounts: (...args: unknown[]) => listSourcesWithCountsMock(...(args as [])),
}));

const { siteRoutes } = await import('../src/routes/site.ts');

async function build() {
  const app = Fastify();
  await app.register(siteRoutes, { prefix: '/api/site' });
  return app;
}

beforeEach(() => {
  listEpisodesMock.mockReset();
  listSourcesWithCountsMock.mockReset();
});

describe('GET /api/site/meta', () => {
  it('返回站点身份字段', async () => {
    const app = await build();
    const res = await app.inject({ method: 'GET', url: '/api/site/meta' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ name: '声读', nameEn: 'Sonde', tagline: expect.any(String) });
  });
});

describe('GET /api/site/episodes', () => {
  it('page 缺省为 1 → offset 0，透传 items/page/pageSize/hasMore/total', async () => {
    listEpisodesMock.mockResolvedValue({ items: [{ id: 1 }], hasMore: true, pageSize: 50, total: null });

    const app = await build();
    const res = await app.inject({ method: 'GET', url: '/api/site/episodes' });

    expect(res.statusCode).toBe(200);
    expect(listEpisodesMock).toHaveBeenCalledWith(50, 0, {});
    expect(res.json()).toEqual({ items: [{ id: 1 }], page: 1, pageSize: 50, hasMore: true, total: null });
  });

  it('page=3 → offset 100；垃圾值兜底为 1', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50, total: null });

    const app = await build();
    await app.inject({ method: 'GET', url: '/api/site/episodes?page=3' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 100, {});

    await app.inject({ method: 'GET', url: '/api/site/episodes?page=abc' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, {});
  });

  it('?source=7 透传为 sourceId 筛选;垃圾值忽略', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50, total: 0 });

    const app = await build();
    await app.inject({ method: 'GET', url: '/api/site/episodes?source=7' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { sourceId: 7 });

    await app.inject({ method: 'GET', url: '/api/site/episodes?source=abc' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, {});

    await app.inject({ method: 'GET', url: '/api/site/episodes?source=-3' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, {});
  });

  it('?q= 透传为关键词筛选(去空白);空串忽略', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50, total: 0 });

    const app = await build();
    await app.inject({ method: 'GET', url: '/api/site/episodes?q=%E6%B7%B1%E5%BA%A6' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { q: '深度' });

    await app.inject({ method: 'GET', url: '/api/site/episodes?q=%20%20' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, {});

    await app.inject({ method: 'GET', url: '/api/site/episodes?source=2&q=AI' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { sourceId: 2, q: 'AI' });
  });
});

describe('GET /api/site/sources', () => {
  it('透传带条数的源列表(筛选 chips 数据)', async () => {
    listSourcesWithCountsMock.mockResolvedValue([
      { id: 2, name: 'B 台', imageUrl: null, episodeCount: 9 },
    ]);

    const app = await build();
    const res = await app.inject({ method: 'GET', url: '/api/site/sources' });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      items: [{ id: 2, name: 'B 台', imageUrl: null, episodeCount: 9 }],
    });
  });
});
