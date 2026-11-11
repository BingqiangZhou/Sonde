import Fastify from 'fastify';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const listEpisodesMock = vi.fn();

vi.mock('@sonde/backend', () => ({
  listEpisodes: (...args: unknown[]) => listEpisodesMock(...(args as [])),
}));

const { siteRoutes } = await import('../src/routes/site.ts');

async function build() {
  const app = Fastify();
  await app.register(siteRoutes, { prefix: '/api/site' });
  return app;
}

beforeEach(() => {
  listEpisodesMock.mockReset();
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
  it('page 缺省为 1 → offset 0，透传 items/page/pageSize/hasMore', async () => {
    listEpisodesMock.mockResolvedValue({ items: [{ id: 1 }], hasMore: true, pageSize: 50 });

    const app = await build();
    const res = await app.inject({ method: 'GET', url: '/api/site/episodes' });

    expect(res.statusCode).toBe(200);
    expect(listEpisodesMock).toHaveBeenCalledWith(50, 0);
    expect(res.json()).toEqual({ items: [{ id: 1 }], page: 1, pageSize: 50, hasMore: true });
  });

  it('page=3 → offset 100；垃圾值兜底为 1', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50 });

    const app = await build();
    await app.inject({ method: 'GET', url: '/api/site/episodes?page=3' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 100);

    await app.inject({ method: 'GET', url: '/api/site/episodes?page=abc' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0);
  });
});
