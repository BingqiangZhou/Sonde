import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { RssEpisodeInput } from '../src/sources/rss.ts';

/** db/boss/rss 全部 mock：断言落在真实行为（SQL 形状、派发参数）上，不测 mock 本身。 */
const rowMock = vi.fn();
const rowsMock = vi.fn();
const sendJobMock = vi.fn();
const fetchPodcastFeedMock = vi.fn();

vi.mock('../src/db/db.ts', () => ({
  sql: (strings: readonly string[], ...values: unknown[]) => ({
    text: strings.reduce(
      (acc: string, part: string, i: number) => acc + part + (i < values.length ? `$${i + 1}` : ''),
      '',
    ),
    values,
  }),
  row: (...args: unknown[]) => rowMock(...(args as [])),
  rows: (...args: unknown[]) => rowsMock(...(args as [])),
}));

class MockFeedNotModifiedError extends Error {
  constructor() {
    super('feed not modified');
    this.name = 'FeedNotModifiedError';
  }
}

vi.mock('../src/sources/rss.ts', () => ({
  FeedNotModifiedError: MockFeedNotModifiedError,
  fetchPodcastFeed: (...args: unknown[]) => fetchPodcastFeedMock(...(args as [])),
}));

vi.mock('../src/queue/boss.ts', () => ({
  sendJob: (...args: unknown[]) => sendJobMock(...(args as [])),
}));

const { dispatchSourceFetch, fetchSource, scanDueSources } = await import(
  '../src/sources/service.ts'
);

interface Frag {
  text: string;
  values: unknown[];
}

/** 捕获到的 UPDATE sources 语句（经 rows() 走的持久化写入）。 */
let updates: Frag[] = [];

const sourceFixture = {
  id: 7,
  name: '测试播客',
  config: { feedUrl: 'https://example.com/feed.xml' },
  cursor: { lastFetchedAt: '2026-11-01T00:00:00Z', etag: 'W/"abc"', lastModified: 'Mon, 01 Jan 2026 00:00:00 GMT' },
  health: { lastStatus: 'ok', lastError: null, consecutiveFailures: 0 },
  interval_minutes: 60,
};

function episode(guid: string): RssEpisodeInput {
  return {
    guid,
    title: `第 ${guid} 期`,
    url: 'https://example.com/ep',
    author: null,
    publishedAt: new Date('2026-11-04T00:00:00Z'),
    shownotes: null,
    durationSeconds: 1800,
    enclosureUrl: 'https://example.com/ep.mp3',
    enclosureBytes: 1000,
  };
}

beforeEach(() => {
  updates = [];
  rowMock.mockReset();
  rowsMock.mockReset();
  sendJobMock.mockReset();
  fetchPodcastFeedMock.mockReset();
  sendJobMock.mockResolvedValue('job-1');
});

describe('fetchSource 持久化（单条 UPDATE，304 保留 etag）', () => {
  function installRouter(opts: { source?: unknown } = {}) {
    rowMock.mockImplementation(async (frag: Frag) => {
      if (frag.text.includes('FROM sources WHERE id')) {
        return opts.source ?? sourceFixture;
      }
      if (frag.text.includes('INSERT INTO episodes')) {
        return { id: 11, inserted: true };
      }
      return null;
    });
    rowsMock.mockImplementation(async (frag: Frag) => {
      if (frag.text.includes('SELECT id FROM sources')) {
        return [];
      }
      if (frag.text.includes('UPDATE sources')) {
        updates.push(frag);
        return [];
      }
      return [];
    });
  }

  it('304 时只推进 lastFetchedAt 与 staleCount，保留已存 etag/lastModified（恰一条 UPDATE）', async () => {
    installRouter();
    fetchPodcastFeedMock.mockRejectedValue(new MockFeedNotModifiedError());

    const result = await fetchSource(7);

    expect(result).toEqual({ fetched: 0, inserted: 0 });
    expect(updates).toHaveLength(1);
    const update = updates[0] as Frag;
    // cursor patch 只含空转计数：合并 lastFetchedAt 后，etag/lastModified 原样保留
    expect(JSON.parse(update.values[0] as string)).toEqual({ staleCount: 1 });
    // 不得再出现把 etag 写为 null 的 jsonb_set
    expect(update.text).not.toContain('{etag}');
    // health 同语句写入 ok
    expect(update.values).toContain('ok');
    expect(update.text).toContain('consecutiveFailures');
  });

  it('304 的空转计数基于已有 staleCount 递增', async () => {
    installRouter({
      source: { ...sourceFixture, cursor: { ...sourceFixture.cursor, staleCount: 5 } },
    });
    fetchPodcastFeedMock.mockRejectedValue(new MockFeedNotModifiedError());

    await fetchSource(7);

    expect(JSON.parse((updates[0] as Frag).values[0] as string)).toEqual({ staleCount: 6 });
  });

  it('成功时把 etag/lastModified 并入 cursor patch，有新单集则 staleCount 归零', async () => {
    installRouter({
      source: { ...sourceFixture, cursor: { ...sourceFixture.cursor, staleCount: 5 } },
    });
    fetchPodcastFeedMock.mockResolvedValue({
      feedTitle: '测试播客',
      episodes: [episode('g1')],
      etag: 'W/"new"',
      lastModified: 'Tue, 04 Nov 2026 00:00:00 GMT',
    });

    await fetchSource(7);

    expect(updates).toHaveLength(1);
    const patch = JSON.parse((updates[0] as Frag).values[1] as string) as Record<string, unknown>;
    expect(patch).toEqual({ etag: 'W/"new"', lastModified: 'Tue, 04 Nov 2026 00:00:00 GMT', staleCount: 0 });
  });

  it('服务端不再返回条件头时，patch 存 JSON null；200 无新单集时 staleCount 递增', async () => {
    installRouter();
    fetchPodcastFeedMock.mockResolvedValue({
      feedTitle: null,
      episodes: [],
      etag: null,
      lastModified: null,
    });

    await fetchSource(7);

    expect(updates).toHaveLength(1);
    const patch = JSON.parse((updates[0] as Frag).values[1] as string) as Record<string, unknown>;
    expect(patch).toEqual({ etag: null, lastModified: null, staleCount: 1 });
  });

  it('失败时只写 health（patch 为 null，lastFetchedAt 不动以保持到期重试）并重抛', async () => {
    installRouter();
    fetchPodcastFeedMock.mockRejectedValue(new Error('feed fetch failed: 500'));

    await expect(fetchSource(7)).rejects.toThrow('feed fetch failed: 500');

    expect(updates).toHaveLength(1);
    const update = updates[0] as Frag;
    expect(update.values[0]).toBeNull();
    expect(update.values[1]).toBeNull();
    expect(update.values).toContain('error');
    expect(update.values).toContain(1); // consecutiveFailures 0 + 1
  });

  it('失败计数基于已有 consecutiveFailures 递增', async () => {
    installRouter({
      source: { ...sourceFixture, health: { lastStatus: 'error', lastError: 'x', consecutiveFailures: 2 } },
    });
    fetchPodcastFeedMock.mockRejectedValue(new Error('boom'));

    await expect(fetchSource(7)).rejects.toThrow('boom');
    expect((updates[0] as Frag).values).toContain(3);
  });

  it('新插入的单集不再派发任何后续任务（AI 管道已移除）', async () => {
    installRouter();
    rowMock.mockImplementation(async (frag: Frag) => {
      if (frag.text.includes('FROM sources WHERE id')) return sourceFixture;
      if (frag.text.includes('INSERT INTO episodes')) return { id: 11 };
      return null;
    });
    fetchPodcastFeedMock.mockResolvedValue({
      feedTitle: null,
      episodes: [episode('g1'), episode('g2')],
      etag: null,
      lastModified: null,
    });

    const result = await fetchSource(7);

    expect(result).toEqual({ fetched: 2, inserted: 2 });
    expect(sendJobMock).not.toHaveBeenCalled();
  });

  it('成功抓取把 feed 封面写入 image_url（COALESCE：feed 无图保留旧值）', async () => {
    installRouter();
    fetchPodcastFeedMock.mockResolvedValue({
      feedTitle: null,
      feedImageUrl: 'https://cdn.example.com/cover.jpg',
      episodes: [],
      etag: 'W/"new"',
      lastModified: null,
    });

    await fetchSource(7);

    expect(updates).toHaveLength(1);
    const update = updates[0] as Frag;
    expect(update.text).toContain('image_url = COALESCE(');
    expect(update.values).toContain('https://cdn.example.com/cover.jpg');
  });

  it('304 的 UPDATE 不清空封面（image 参数为 null，COALESCE 保留旧值）', async () => {
    installRouter();
    fetchPodcastFeedMock.mockRejectedValue(new MockFeedNotModifiedError());

    await fetchSource(7);

    expect(updates).toHaveLength(1);
    const update = updates[0] as Frag;
    // COALESCE 的 image 参数位于 health 五参之后、sid 之前：必须是 null（保留旧封面）
    expect(update.text).toContain('image_url = COALESCE(');
    expect(update.values[update.values.length - 2]).toBeNull();
    expect(update.values).not.toContain('https://cdn.example.com/cover.jpg');
  });
});

describe('scanDueSources 派发器（不内联抓取）', () => {
  it('到期源逐个派发 sources.fetch，singletonKey src:<id>；去重（null jobId）不计数', async () => {
    rowMock.mockReset();
    rowsMock.mockImplementation(async (frag: Frag) => {
      if (frag.text.includes('SELECT id FROM sources')) {
        return [{ id: 1 }, { id: 2 }, { id: 3 }];
      }
      return [];
    });
    sendJobMock.mockImplementation(async (_name: string, data: { sourceId: number }) =>
      data.sourceId === 2 ? null : 'job-9',
    );

    const sent = await scanDueSources();

    expect(sent).toBe(2);
    expect(sendJobMock).toHaveBeenCalledTimes(3);
    expect(sendJobMock).toHaveBeenNthCalledWith(1, 'sources.fetch', { sourceId: 1 }, { singletonKey: 'src:1' });
    expect(sendJobMock).toHaveBeenNthCalledWith(2, 'sources.fetch', { sourceId: 2 }, { singletonKey: 'src:2' });
    expect(sendJobMock).toHaveBeenNthCalledWith(3, 'sources.fetch', { sourceId: 3 }, { singletonKey: 'src:3' });
    // 派发器绝不下场抓取
    expect(fetchPodcastFeedMock).not.toHaveBeenCalled();
  });

  it('dispatchSourceFetch 返回是否真正入队', async () => {
    sendJobMock.mockResolvedValueOnce('job-1');
    await expect(dispatchSourceFetch(42)).resolves.toBe(true);
    sendJobMock.mockResolvedValueOnce(null);
    await expect(dispatchSourceFetch(42)).resolves.toBe(false);
    expect(sendJobMock).toHaveBeenLastCalledWith('sources.fetch', { sourceId: 42 }, { singletonKey: 'src:42' });
  });

  it('到期条件是自适应的:空翻倍(超 3 轮起算)+ 失败翻倍,取更长者并封顶 1440 分钟', async () => {
    rowsMock.mockImplementation(async (frag: Frag) => {
      if (frag.text.includes('SELECT id FROM sources')) {
        captured = frag;
        return [];
      }
      return [];
    });
    let captured: Frag | null = null;

    await scanDueSources();

    const text = (captured as Frag | null)?.text ?? '';
    // 空转退避:staleCount 超 3 轮后 2^n 翻倍,指数封 8
    expect(text).toContain(`(cursor->>'staleCount')::int`);
    expect(text).toMatch(/2 \^ LEAST\(GREATEST\(COALESCE\(\(cursor->>'staleCount'\)::int, 0\) - 3, 0\), 8\)/);
    // 失败退避:consecutiveFailures 2^n,指数封 5
    expect(text).toMatch(/2 \^ LEAST\(COALESCE\(\(health->>'consecutiveFailures'\)::int, 0\), 5\)/);
    // 两条退避取更长者,均封顶 1440 分钟(24 小时 = 2× adapt 的 max=720,aihot 同款余量)
    expect(text).toContain('GREATEST(');
    expect((text.match(/LEAST\(1440,/g) ?? []).length).toBe(2);
    // 从未抓过的源仍最优先,每分钟派发上限 200 不变
    expect(text).toContain('NULLS FIRST');
    expect(text).toContain('LIMIT 200');
  });
});
