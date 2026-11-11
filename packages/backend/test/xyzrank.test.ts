import { beforeEach, describe, expect, it, vi } from 'vitest';

/** fetch 全 mock:xyzrankToEntries 是纯函数,fetchXyzrankTopPodcasts 只做翻页与重试。 */

const { fetchXyzrankTopPodcasts, xyzrankToEntries, rollupGenre, GENRE_ROLLUP, CATEGORY_VOCABULARY, XYZRANK_SYNC_INTERVAL_MINUTES } = await import(
  '../src/sources/xyzrank.ts'
);

const pod = (rank: number, name: string, rss?: string, genre?: string) => ({
  id: `id-${rank}`,
  rank,
  name,
  ...(genre !== undefined ? { primaryGenreName: genre } : {}),
  links: [
    { name: 'xyz', url: `https://www.xiaoyuzhoufm.com/podcast/${rank}` },
    ...(rss !== undefined ? [{ name: 'rss', url: rss }] : []),
  ],
});

describe('rollupGenre', () => {
  it('一级分类原样保留(恒等)', () => {
    expect(rollupGenre('科技')).toBe('科技');
    expect(rollupGenre('休闲')).toBe('休闲');
    expect(rollupGenre('犯罪纪实')).toBe('犯罪纪实');
  });

  it('二级分类归并到一级', () => {
    expect(rollupGenre('幽默对谈')).toBe('喜剧');
    expect(rollupGenre('影评')).toBe('影视');
    expect(rollupGenre('个人日记')).toBe('社会与文化');
    expect(rollupGenre('投资')).toBe('商务');
    expect(rollupGenre('历史')).toBe('人文');
  });

  it('两个改名映射:健康与健身→健康、电视与电影→影视', () => {
    expect(rollupGenre('健康与健身')).toBe('健康');
    expect(rollupGenre('电视与电影')).toBe('影视');
  });

  it('先 trim 再查表;空白/缺失 → null', () => {
    expect(rollupGenre(' 商务 ')).toBe('商务');
    expect(rollupGenre('')).toBeNull();
    expect(rollupGenre('   ')).toBeNull();
    expect(rollupGenre(undefined)).toBeNull();
  });

  it('未收录的值 → null(前端归入「其他」)', () => {
    expect(rollupGenre('神秘新类')).toBeNull();
  });

  it('字典穷尽性:每个映射目标都在一级词表内,词表共 17 个', () => {
    expect(CATEGORY_VOCABULARY.size).toBe(17);
    for (const target of Object.values(GENRE_ROLLUP)) {
      expect(CATEGORY_VOCABULARY.has(target)).toBe(true);
    }
  });
});

describe('xyzrankToEntries', () => {
  it('取 links 里 name=rss 的地址映射为订阅条目,默认间隔 10 分钟', () => {
    const { entries, skipped } = xyzrankToEntries([pod(1, '岩中花述', 'https://feed.xyzfm.space/abc')]);

    expect(entries).toEqual([
      {
        name: '岩中花述',
        feedUrl: 'https://feed.xyzfm.space/abc',
        intervalMinutes: XYZRANK_SYNC_INTERVAL_MINUTES,
        category: null,
      },
    ]);
    expect(XYZRANK_SYNC_INTERVAL_MINUTES).toBe(10);
    expect(skipped).toBe(0);
  });

  it('primaryGenreName 经 rollupGenre 归并进 category,缺失时为 null', () => {
    const { entries } = xyzrankToEntries([
      pod(1, '一级', 'https://a.com/rss', '科技'),
      pod(2, '二级', 'https://b.com/rss', '幽默对谈'),
      pod(3, '无genre', 'https://c.com/rss'),
    ]);

    expect(entries.map((e) => e.category)).toEqual(['科技', '喜剧', null]);
  });

  it('无 rss 链接或名字为空的跳过并计数', () => {
    const { entries, skipped } = xyzrankToEntries([
      pod(1, '有源', 'https://a.com/rss'),
      pod(2, '没源'),
      pod(3, '', 'https://b.com/rss'),
    ]);

    expect(entries).toHaveLength(1);
    expect(skipped).toBe(2);
  });

  it('rank 超过 maxRank 的截断(榜单按 rank 升序传入)', () => {
    const items = [pod(1, 'A', 'https://a.com/rss'), pod(999, 'B', 'https://b.com/rss'), pod(1001, 'C', 'https://c.com/rss')];
    const { entries } = xyzrankToEntries(items, { maxRank: 1000 });

    expect(entries.map((e) => e.name)).toEqual(['A', 'B']);
  });

  it('同 feedUrl 去重(忽略大小写,保留首个即更高名次)', () => {
    const { entries, skipped } = xyzrankToEntries([
      pod(1, 'A', 'https://Feed.example/RSS'),
      pod(2, 'A 分台', 'https://feed.example/rss'),
    ]);

    expect(entries).toHaveLength(1);
    expect(entries[0]?.name).toBe('A');
    expect(skipped).toBe(1);
  });

  it('intervalMinutes 可覆盖(透传到每条)', () => {
    const { entries } = xyzrankToEntries([pod(1, 'A', 'https://a.com/rss')], { intervalMinutes: 30 });
    expect(entries[0]?.intervalMinutes).toBe(30);
  });
});

describe('fetchXyzrankTopPodcasts', () => {
  const page = (startRank: number, count: number) => ({
    items: Array.from({ length: count }, (_, i) => pod(startRank + i, `播客${startRank + i}`, `https://f.example/${startRank + i}`)),
    total: 8182,
  });

  beforeEach(() => {
    vi.unstubAllGlobals();
  });

  it('按 100/页翻页拉满 maxRank 后停止,不再多发请求', async () => {
    const calls: string[] = [];
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string | URL) => {
        calls.push(String(url));
        const offset = Number(new URL(String(url)).searchParams.get('offset'));
        return new Response(JSON.stringify(page(offset + 1, 100)), { status: 200 });
      }),
    );

    const { entries } = await fetchXyzrankTopPodcasts({ maxRank: 250 });

    expect(calls).toHaveLength(3); // 0,100,200 —— 第 3 页凑满 250 即止
    expect(entries).toHaveLength(250);
    expect(entries.at(-1)?.name).toBe('播客250');
  });

  it('单页失败自动重试一次,两次全败抛 AppError', async () => {
    let callCount = 0;
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        callCount++;
        if (callCount === 1) {
          return new Response('boom', { status: 500 });
        }
        return new Response(JSON.stringify(page(1, 100)), { status: 200 });
      }),
    );

    const { entries } = await fetchXyzrankTopPodcasts({ maxRank: 1 });
    expect(callCount).toBe(2); // 第一次失败,重试成功
    expect(entries.length).toBeGreaterThanOrEqual(1);

    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response('down', { status: 503 })),
    );
    await expect(fetchXyzrankTopPodcasts({ maxRank: 1 })).rejects.toThrow(/xyzrank/);
  });
});
