import { beforeEach, describe, expect, it, vi } from 'vitest';

const rowMock = vi.fn();
const rowsMock = vi.fn();
const chatJsonMock = vi.fn();

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
  withTx: async (fn: (client: { query: typeof queryMock }) => Promise<void>) => {
    await fn({ query: queryMock });
  },
}));

vi.mock('../src/providers/llm.ts', () => ({
  chatJson: (...args: unknown[]) => chatJsonMock(...(args as [])),
}));

const queryMock = vi.fn(async () => ({ rows: [] }));

const { analyzeEpisode } = await import('../src/pipeline/analyze.ts');

const episodeFixture = {
  id: 3,
  title: '某期节目',
  shownotes: null,
  duration_seconds: 3600,
  published_at: new Date('2026-11-04T00:00:00Z'),
  body_text: '完整转写稿'.repeat(10),
  body_status: 'ok',
  podcast_name: '测试播客',
  tier: 'T2', // 门槛 70
};

beforeEach(() => {
  rowMock.mockReset().mockResolvedValue(episodeFixture);
  rowsMock.mockReset().mockResolvedValue([]);
  queryMock.mockClear();
  chatJsonMock.mockReset();
});

describe('analyzeEpisode 落库事务', () => {
  it('事务内第一条语句是 pg_advisory_xact_lock(42, episodeId)，随后翻转→插入→收尾', async () => {
    chatJsonMock.mockImplementation(async (options: { operation: string }) => {
      if (options.operation === 'score') {
        return { data: { score: 80, reason: '信息增量高', category: 'tech-ai', tags: ['AI'] }, model: 'm' };
      }
      return { data: { titleZh: '标题', summaryZh: '摘要', reasonZh: '理由' }, model: 'm' };
    });

    const result = await analyzeEpisode(3);

    expect(result).toEqual({ selected: true, score: 80 });
    // 咨询锁 → 翻转 → 插入 → 收尾，共 4 条
    expect(queryMock).toHaveBeenCalledTimes(4);
    const first = queryMock.mock.calls[0] as unknown[];
    expect(first[0]).toContain('pg_advisory_xact_lock');
    expect(first[1]).toEqual([42, 3]);
    expect((queryMock.mock.calls[1] as unknown[])[0]).toContain('UPDATE analyses SET is_current = false');
    expect((queryMock.mock.calls[2] as unknown[])[0]).toContain('INSERT INTO analyses');
    expect((queryMock.mock.calls[3] as unknown[])[0]).toContain("transcribe_status = 'done'");
  });

  it('未过门槛不调写作 prompt，插入的中文三字段为 null', async () => {
    chatJsonMock.mockResolvedValueOnce({
      data: { score: 40, reason: '闲聊', category: 'general', tags: [] },
      model: 'm',
    });

    const result = await analyzeEpisode(3);

    expect(result).toEqual({ selected: false, score: 40 });
    expect(chatJsonMock).toHaveBeenCalledTimes(1);
    const insert = queryMock.mock.calls[2] as unknown[];
    expect(insert[0]).toContain('INSERT INTO analyses');
    expect(insert[1]).toContain(null);
  });
});
