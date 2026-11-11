import { beforeEach, describe, expect, it, vi } from 'vitest';

/** db mock：断言落在 SQL 形状与分页语义上（与 sources-service.test.ts 同一套路）。 */
const rowsMock = vi.fn();

vi.mock('../src/db/db.ts', () => ({
  sql: (strings: readonly string[], ...values: unknown[]) => ({
    text: strings.reduce(
      (acc: string, part: string, i: number) => acc + part + (i < values.length ? `$${i + 1}` : ''),
      '',
    ),
    values,
  }),
  rows: (...args: unknown[]) => rowsMock(...(args as [])),
}));

const { listEpisodes, listSourcesWithCounts } = await import('../src/episodes/read.ts');

interface Frag {
  text: string;
  values: unknown[];
}

const episodeRow = (id: number) => ({
  id,
  sourceId: 7,
  podcast: '测试播客',
  imageUrl: 'https://cdn.example.com/c.jpg',
  title: `第 ${id} 期`,
  url: 'https://example.com/ep',
  publishedAt: new Date('2026-11-04T08:00:00Z'),
  durationSeconds: 5025,
  shownotes: '本期简介',
});

beforeEach(() => {
  rowsMock.mockReset();
});

describe('listEpisodes', () => {
  it('联表 sources 取播客名与封面，按发布时间倒序，LIMIT+1 判 hasMore', async () => {
    rowsMock.mockResolvedValue([episodeRow(1), episodeRow(2), episodeRow(3)]);

    const result = await listEpisodes(2, 0);

    const frag = rowsMock.mock.calls[0]?.[0] as Frag;
    expect(frag.text).toContain('JOIN sources s ON s.id = e.source_id');
    expect(frag.text).toContain('ORDER BY e.published_at DESC, e.id DESC');
    expect(frag.text).toContain('COALESCE(e.url, e.enclosure_url) AS url');
    // 时间线必须展示停抓源的历史单集
    expect(frag.text).not.toContain('is_active');
    expect(frag.values).toEqual([3, 0]);
    expect(result.items).toHaveLength(2);
    expect(result.hasMore).toBe(true);
    expect(result.pageSize).toBe(2);
  });

  it('返回行数恰好等于 limit 时 hasMore=false', async () => {
    rowsMock.mockResolvedValue([episodeRow(1), episodeRow(2)]);

    const result = await listEpisodes(2, 0);

    expect(result.items).toHaveLength(2);
    expect(result.hasMore).toBe(false);
  });

  it('limit 夹在 1..100，offset 下限为 0', async () => {
    rowsMock.mockResolvedValue([]);

    await listEpisodes(5000, -10);

    const frag = rowsMock.mock.calls[0]?.[0] as Frag;
    expect(frag.values).toEqual([101, 0]);
  });

  it('无筛选时不跑 COUNT(保持免每页 count 的设计),total 为 null', async () => {
    rowsMock.mockResolvedValue([episodeRow(1)]);

    const result = await listEpisodes(50, 0);

    expect(rowsMock).toHaveBeenCalledTimes(1);
    expect(result.total).toBeNull();
  });

  it('sourceId 筛选:WHERE 带 s.id = $1,分页参数顺延,并跑同条件 COUNT', async () => {
    rowsMock.mockResolvedValueOnce([episodeRow(1)]).mockResolvedValueOnce([{ total: 7 }]);

    const result = await listEpisodes(50, 0, { sourceId: 7 });

    const list = rowsMock.mock.calls[0]?.[0] as Frag;
    expect(list.text).toContain('s.id = $1');
    expect(list.text).toContain('e.published_at IS NOT NULL');
    expect(list.values).toEqual([7, 51, 0]);
    const count = rowsMock.mock.calls[1]?.[0] as Frag;
    expect(count.text).toContain('COUNT(*)');
    expect(count.text).toContain('s.id = $1');
    expect(count.values).toEqual([7]);
    expect(result.total).toBe(7);
  });

  it('q 筛选:标题与简介 ILIKE 同一参数,百分号包裹;垃圾 sourceId 忽略', async () => {
    rowsMock.mockResolvedValueOnce([episodeRow(1)]).mockResolvedValueOnce([{ total: 1 }]);

    await listEpisodes(50, 0, { q: ' 深度学习 ', sourceId: -3 });

    const list = rowsMock.mock.calls[0]?.[0] as Frag;
    expect(list.text).toContain('(e.title ILIKE $1 OR e.shownotes ILIKE $1)');
    expect(list.text).not.toContain('s.id = $');
    expect(list.values).toEqual(['%深度学习%', 51, 0]);
  });

  it('sourceId + q 叠加:参数依次为 sourceId、q%、limit+1、offset', async () => {
    rowsMock.mockResolvedValueOnce([]).mockResolvedValueOnce([{ total: 0 }]);

    await listEpisodes(50, 0, { sourceId: 2, q: 'AI' });

    const list = rowsMock.mock.calls[0]?.[0] as Frag;
    expect(list.text).toContain('s.id = $1');
    expect(list.text).toContain('(e.title ILIKE $2 OR e.shownotes ILIKE $2)');
    expect(list.values).toEqual([2, '%AI%', 51, 0]);
  });

  it('q 全空白/超长:空白忽略、长度夹到 100', async () => {
    rowsMock.mockResolvedValue([episodeRow(1)]);

    await listEpisodes(50, 0, { q: '   ' });
    expect(rowsMock).toHaveBeenCalledTimes(1); // 无有效筛选 → 不 COUNT

    rowsMock.mockResolvedValueOnce([episodeRow(1)]).mockResolvedValueOnce([{ total: 1 }]);
    await listEpisodes(50, 0, { q: 'x'.repeat(300) });
    const list = rowsMock.mock.calls[1]?.[0] as Frag;
    expect(list.values[0]).toHaveLength(102); // 100 字符 + 两个 %
  });
});

describe('listSourcesWithCounts', () => {
  it('按单集数倒序列出有历史的源(含停更源),COUNT 在 SQL 里 ::int 转型', async () => {
    rowsMock.mockResolvedValue([
      { id: 2, name: 'B 台', imageUrl: null, episodeCount: 9 },
      { id: 1, name: 'A 台', imageUrl: 'https://cdn.example.com/a.jpg', episodeCount: 3 },
    ]);

    const result = await listSourcesWithCounts();

    const frag = rowsMock.mock.calls[0]?.[0] as Frag;
    // BIGINT 的 id 必须 ::int,否则 pg 回字符串、前端严格比较失效
    expect(frag.text).toContain('s.id::int AS id');
    expect(frag.text).toContain('HAVING COUNT(e.id) > 0');
    expect(frag.text).toContain('ORDER BY COUNT(e.id) DESC, s.name ASC');
    // 停更源的历史也计入(不按 is_active 过滤)
    expect(frag.text).not.toContain('is_active');
    expect(result).toEqual([
      { id: 2, name: 'B 台', imageUrl: null, episodeCount: 9 },
      { id: 1, name: 'A 台', imageUrl: 'https://cdn.example.com/a.jpg', episodeCount: 3 },
    ]);
  });
});
