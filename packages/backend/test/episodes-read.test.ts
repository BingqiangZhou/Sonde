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

const { listEpisodes } = await import('../src/episodes/read.ts');

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
});
