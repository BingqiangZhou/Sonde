import { beforeEach, describe, expect, it, vi } from 'vitest';

const rowsMock = vi.fn();
const chatJsonMock = vi.fn();
const clientQueryMock = vi.fn();
const releaseMock = vi.fn();

vi.mock('../src/db/db.ts', () => ({
  sql: (strings: readonly string[], ...values: unknown[]) => ({
    text: strings.reduce(
      (acc: string, part: string, i: number) => acc + part + (i < values.length ? `$${i + 1}` : ''),
      '',
    ),
    values,
  }),
  rows: (...args: unknown[]) => rowsMock(...(args as [])),
  getPool: () => ({
    connect: async () => ({ query: clientQueryMock, release: releaseMock }),
  }),
}));

vi.mock('../src/providers/llm.ts', () => ({
  chatJson: (...args: unknown[]) => chatJsonMock(...(args as [])),
}));

const { generateReport } = await import('../src/reports/daily.ts');

const candidate = {
  episode_id: 11,
  podcast_name: '测试播客',
  original_title: 'Ep 42',
  title_zh: '中文标题',
  summary_zh: '中文摘要',
  reason_zh: '值得听',
  category: 'tech-ai',
  score: 85,
  url: null,
  published_at: new Date('2026-11-04T01:00:00Z'),
  duration_seconds: 3600,
};

function setupClient(opts: { exists: boolean }) {
  clientQueryMock.mockImplementation(async (text: string) => {
    if (text.includes('pg_advisory_lock') || text.includes('pg_advisory_unlock')) {
      return { rows: [] };
    }
    if (text.includes('SELECT revision')) {
      return opts.exists ? { rowCount: 1, rows: [{ revision: 2 }] } : { rowCount: 0, rows: [] };
    }
    return { rows: [] };
  });
}

beforeEach(() => {
  rowsMock.mockReset();
  chatJsonMock.mockReset();
  clientQueryMock.mockReset();
  releaseMock.mockClear();
  chatJsonMock.mockResolvedValue({
    data: { title: '今日刊头', leadParagraph: '导语', highlights: ['要点一'] },
    model: 'm',
  });
});

describe('generateReport 并发互斥（会话级咨询锁）', () => {
  it('锁纪律：先 pg_advisory_lock(43, kind:key)，结束后 unlock，连接归还', async () => {
    setupClient({ exists: false });
    rowsMock.mockResolvedValue([candidate]);

    await generateReport('daily', { reportKey: '2026-11-04', force: true });

    const first = clientQueryMock.mock.calls[0] as unknown[];
    expect(first[0]).toContain('pg_advisory_lock');
    expect(first[0]).toContain('hashtext');
    expect(first[1]).toEqual([43, 'daily:2026-11-04']);

    const last = clientQueryMock.mock.calls.at(-1) as unknown[];
    expect(last[0]).toContain('pg_advisory_unlock');
    expect(releaseMock).toHaveBeenCalledTimes(1);
  });

  it('已存在且 force=false：持锁重查后跳过，不调 LLM、不写库', async () => {
    setupClient({ exists: true });
    rowsMock.mockResolvedValue([]);

    const result = await generateReport('daily', { reportKey: '2026-11-04' });

    expect(result).toEqual({ reportKey: '2026-11-04', created: false, skipped: 'already exists' });
    expect(chatJsonMock).not.toHaveBeenCalled();
    expect(rowsMock).not.toHaveBeenCalled();
    expect(releaseMock).toHaveBeenCalledTimes(1);
  });

  it('已存在且 force=true：重新生成（LLM + upsert revision+1）', async () => {
    setupClient({ exists: true });
    rowsMock.mockResolvedValue([candidate]);

    const result = await generateReport('daily', { reportKey: '2026-11-04', force: true });

    expect(result).toEqual({ reportKey: '2026-11-04', created: true });
    expect(chatJsonMock).toHaveBeenCalledTimes(1);
    const upserts = rowsMock.mock.calls.filter(
      (c) => (c[0] as { text: string }).text.includes('INSERT INTO daily_reports'),
    );
    expect(upserts).toHaveLength(1);
  });

  it('窗口内无入选集：跳过且不调 LLM', async () => {
    setupClient({ exists: false });
    rowsMock.mockResolvedValue([]);

    const result = await generateReport('daily', { reportKey: '2026-11-04' });

    expect(result.skipped).toBe('no candidates');
    expect(chatJsonMock).not.toHaveBeenCalled();
  });

  it('非法 reportKey 直接抛错，不取锁', async () => {
    await expect(generateReport('daily', { reportKey: 'not-a-key' })).rejects.toThrow(/invalid/);
    expect(clientQueryMock).not.toHaveBeenCalled();
  });
});
