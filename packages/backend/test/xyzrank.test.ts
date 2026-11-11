import { beforeEach, describe, expect, it, vi } from 'vitest';

/** fetch 全 mock:xyzrankToEntries 是纯函数,fetchXyzrankTopPodcasts 只做翻页与重试。 */

const { fetchXyzrankTopPodcasts, xyzrankToEntries, XYZRANK_SYNC_INTERVAL_MINUTES } = await import(
  '../src/sources/xyzrank.ts'
);

const pod = (rank: number, name: string, rss?: string) => ({
  id: `id-${rank}`,
  rank,
  name,
  links: [
    { name: 'xyz', url: `https://www.xiaoyuzhoufm.com/podcast/${rank}` },
    ...(rss !== undefined ? [{ name: 'rss', url: rss }] : []),
  ],
});

describe('xyzrankToEntries', () => {
  it('取 links 里 name=rss 的地址映射为订阅条目,默认间隔 10 分钟', () => {
    const { entries, skipped } = xyzrankToEntries([pod(1, '岩中花述', 'https://feed.xyzfm.space/abc')]);

    expect(entries).toEqual([
      { name: '岩中花述', feedUrl: 'https://feed.xyzfm.space/abc', intervalMinutes: XYZRANK_SYNC_INTERVAL_MINUTES },
    ]);
    expect(XYZRANK_SYNC_INTERVAL_MINUTES).toBe(10);
    expect(skipped).toBe(0);
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
