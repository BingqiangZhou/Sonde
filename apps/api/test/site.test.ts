import Fastify from 'fastify';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const listEpisodesMock = vi.fn();
const listSourcesWithCountsMock = vi.fn();
const listCategoriesWithCountsMock = vi.fn();

vi.mock('@sonde/backend', () => ({
  listEpisodes: (...args: unknown[]) => listEpisodesMock(...(args as [])),
  listSourcesWithCounts: (...args: unknown[]) => listSourcesWithCountsMock(...(args as [])),
  listCategoriesWithCounts: (...args: unknown[]) => listCategoriesWithCountsMock(...(args as [])),
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

  it('?category= 透传为分类筛选(去空白);「其他」照常透传;空白/超长处理', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50, total: 0 });

    const app = await build();
    // 科技(URL 编码)
    await app.inject({ method: 'GET', url: '/api/site/episodes?category=%E7%A7%91%E6%8A%80' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { category: '科技' });

    // 「其他」照常透传(NULL 分类的哨兵在 SQL 层处理)
    await app.inject({ method: 'GET', url: '/api/site/episodes?category=%E5%85%B6%E4%BB%96' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { category: '其他' });

    // 纯空白忽略
    await app.inject({ method: 'GET', url: '/api/site/episodes?category=%20%20' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, {});

    // 超长截断到 30
    await app.inject({ method: 'GET', url: `/api/site/episodes?category=${'x'.repeat(50)}` });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { category: 'x'.repeat(30) });

    // 与 source/q 叠加
    await app.inject({ method: 'GET', url: '/api/site/episodes?source=2&q=AI&category=%E7%A7%91%E6%8A%80' });
    expect(listEpisodesMock).toHaveBeenLastCalledWith(50, 0, { sourceId: 2, q: 'AI', category: '科技' });
  });
});

describe('GET /api/site/categories', () => {
  it('透传分类列表(「其他」恒排末尾由 backend 保证)', async () => {
    listCategoriesWithCountsMock.mockResolvedValue([
      { name: '休闲', episodeCount: 120, sourceCount: 30 },
      { name: '其他', episodeCount: 500, sourceCount: 98 },
    ]);

    const app = await build();
    const res = await app.inject({ method: 'GET', url: '/api/site/categories' });

    expect(res.statusCode).toBe(200);
    expect(listCategoriesWithCountsMock).toHaveBeenCalledTimes(1);
    expect(res.json()).toEqual({
      items: [
        { name: '休闲', episodeCount: 120, sourceCount: 30 },
        { name: '其他', episodeCount: 500, sourceCount: 98 },
      ],
    });
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

describe('读取层缓存(aihot 同款:60s 动态 / 300s 稳定 + 弱 ETag 304)', () => {
  it('episodes:cache-control 60s + 弱 ETag;If-None-Match 命中回 304 空体且保留头', async () => {
    listEpisodesMock.mockResolvedValue({ items: [{ id: 1 }], hasMore: false, pageSize: 50, total: 1 });

    const app = await build();
    const res = await app.inject({ method: 'GET', url: '/api/site/episodes' });

    expect(res.statusCode).toBe(200);
    expect(res.headers['cache-control']).toBe('public, max-age=60, s-maxage=60, must-revalidate');
    const etag = res.headers.etag as string;
    expect(etag).toMatch(/^W\/"[0-9a-f]{16}"$/);

    // 同 ETag 重发 → 304,空体,ETag/Cache-Control 仍在
    const revalidate = await app.inject({ method: 'GET', url: '/api/site/episodes', headers: { 'if-none-match': etag } });
    expect(revalidate.statusCode).toBe(304);
    expect(revalidate.body).toBe('');
    expect(revalidate.headers.etag).toBe(etag);
    expect(revalidate.headers['cache-control']).toBe('public, max-age=60, s-maxage=60, must-revalidate');
    // body-hash ETag 需先构体才能算指纹:304 省的是传输,不是查询
    expect(listEpisodesMock).toHaveBeenCalledTimes(2);
  });

  it('episodes:不同 query 产出不同 ETag(分页/筛选各是各的缓存键)', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50, total: 0 });

    const app = await build();
    const page1 = await app.inject({ method: 'GET', url: '/api/site/episodes' });
    const page2 = await app.inject({ method: 'GET', url: '/api/site/episodes?page=2' });

    expect(page1.headers.etag).not.toBe(page2.headers.etag);
  });

  it('If-None-Match 为 RFC 列表(逗号分隔,含空白)或 * 时同样命中 304;列表不含则 200', async () => {
    listEpisodesMock.mockResolvedValue({ items: [], hasMore: false, pageSize: 50, total: 0 });

    const app = await build();
    const etag = (await app.inject({ method: 'GET', url: '/api/site/episodes' })).headers.etag as string;

    // 列表形式,目标校验器在末位且带空白
    const asList = await app.inject({
      method: 'GET',
      url: '/api/site/episodes',
      headers: { 'if-none-match': `W/"0000000000000000" ,  ${etag}` },
    });
    expect(asList.statusCode).toBe(304);

    // * 形式:资源存在即未变
    const star = await app.inject({ method: 'GET', url: '/api/site/episodes', headers: { 'if-none-match': '*' } });
    expect(star.statusCode).toBe(304);

    // 列表不含本 ETag → 200
    const miss = await app.inject({
      method: 'GET',
      url: '/api/site/episodes',
      headers: { 'if-none-match': 'W/"deadbeefdeadbeef", W/"cafecafecafecafe"' },
    });
    expect(miss.statusCode).toBe(200);
  });

  it('meta/sources/categories:稳定内容走 300s', async () => {
    listSourcesWithCountsMock.mockResolvedValue([]);
    listCategoriesWithCountsMock.mockResolvedValue([]);

    const app = await build();
    for (const path of ['/api/site/meta', '/api/site/sources', '/api/site/categories']) {
      const res = await app.inject({ method: 'GET', url: path });
      expect(res.headers['cache-control']).toBe('public, max-age=300, s-maxage=300, must-revalidate');
      expect(res.headers.etag).toMatch(/^W\/"[0-9a-f]{16}"$/);
    }
  });
});
