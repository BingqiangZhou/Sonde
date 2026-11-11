import { beforeEach, describe, expect, it, vi } from 'vitest';

/** db mock：捕获 withTx 内的 client 查询，断言落在 SQL 语义上。 */
const { clientMock, queries, withTxMock } = vi.hoisted(() => {
  const queries: { text: string; values: unknown[] }[] = [];
  const clientMock = {
    query: vi.fn(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return { rows: [] as { inserted?: boolean }[], rowCount: 0 };
    }),
  };
  return {
    clientMock,
    queries,
    withTxMock: vi.fn((fn: (client: unknown) => Promise<unknown>) => fn(clientMock)),
  };
});

vi.mock('../src/db/db.ts', () => ({
  sql: (strings: readonly string[], ...values: unknown[]) => ({
    text: strings.reduce(
      (acc: string, part: string, i: number) => acc + part + (i < values.length ? `$${i + 1}` : ''),
      '',
    ),
    values,
  }),
  withTx: (fn: (client: unknown) => Promise<unknown>) => withTxMock(fn),
}));

const { syncSources, normalizeSeedEntries } = await import('../src/sources/sync.ts');

beforeEach(() => {
  queries.length = 0;
  clientMock.query.mockReset().mockImplementation(async (frag: { text: string; values: unknown[] }) => {
    queries.push(frag);
    return { rows: [] as { inserted?: boolean }[], rowCount: 0 };
  });
  withTxMock.mockClear().mockImplementation((fn: (client: unknown) => Promise<unknown>) => fn(clientMock));
});

describe('normalizeSeedEntries', () => {
  it('非数组直接抛错', () => {
    expect(() => normalizeSeedEntries({})).toThrow('数组');
  });
  it('缺 name 或 feedUrl 抛错', () => {
    expect(() => normalizeSeedEntries([{ feedUrl: 'https://x.com/feed' }])).toThrow('name');
    expect(() => normalizeSeedEntries([{ name: 'x' }])).toThrow('feedUrl');
  });
  it('intervalMinutes 必须是正整数，缺省 60', () => {
    expect(() => normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f', intervalMinutes: 0 }])).toThrow(
      'intervalMinutes',
    );
    expect(() => normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f', intervalMinutes: 30.5 }])).toThrow(
      'intervalMinutes',
    );
    const [entry] = normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f' }]);
    expect(entry).toEqual({ name: 'x', feedUrl: 'https://x.com/f', intervalMinutes: 60 });
  });
});

describe('syncSources', () => {
  it('每条目一条 upsert，ON CONFLICT 目标匹配 lower(feedUrl) 部分唯一索引并重新激活', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return { rows: [{ inserted: true }], rowCount: 1 };
    });

    const result = await syncSources([
      { name: '播客 A', feedUrl: 'https://a.com/feed.xml', intervalMinutes: 30 },
      { name: '播客 B', feedUrl: 'https://b.com/feed.xml', intervalMinutes: 60 },
    ]);

    const upserts = queries.filter((q) => q.text.includes('INSERT INTO sources'));
    expect(upserts).toHaveLength(2);
    expect(upserts[0]?.text).toContain(`ON CONFLICT (lower(config->>'feedUrl')) WHERE config->>'feedUrl' IS NOT NULL`);
    expect(upserts[0]?.text).toContain('DO UPDATE SET');
    expect(upserts[0]?.text).toContain('is_active = true');
    expect(upserts[0]?.values.slice(0, 3)).toEqual(['播客 A', 'https://a.com/feed.xml', 30]);
    expect(result).toMatchObject({ added: 2, updated: 0 });
  });

  it('added/updated 计数来自 xmax=0，整个同步在事务内', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return frag.text.includes('INSERT INTO sources')
        ? { rows: [{ inserted: queries.filter((q) => q.text.includes('INSERT')).length === 1 }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    });

    const result = await syncSources([
      { name: 'A', feedUrl: 'https://a.com/f', intervalMinutes: 60 },
      { name: 'B', feedUrl: 'https://b.com/f', intervalMinutes: 60 },
    ]);

    expect(withTxMock).toHaveBeenCalledTimes(1);
    expect(result).toMatchObject({ added: 1, updated: 1 });
  });

  it('列表外的激活源被停用（不删行，保留历史单集）', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return frag.text.includes('UPDATE sources')
        ? { rows: [{ id: 3 }, { id: 4 }] as unknown as { inserted?: boolean }[], rowCount: 2 }
        : { rows: [] as { inserted?: boolean }[], rowCount: 0 };
    });

    const result = await syncSources([{ name: 'A', feedUrl: 'https://a.com/f', intervalMinutes: 60 }]);

    const deactivate = queries.filter((q) => q.text.includes('UPDATE sources') && q.text.includes('is_active = false'));
    expect(deactivate).toHaveLength(1);
    // 数组参数必须显式 ::text[] 转型,否则 Postgres 报 42P18(联调实测)
    expect(deactivate[0]?.text).toContain(`<> ALL(`);
    expect(deactivate[0]?.text).toMatch(/ALL\(\$[0-9]+::text\[\]\)/);
    expect(deactivate[0]?.text).toContain(`config->>'feedUrl' IS NOT NULL`);
    expect(deactivate[0]?.values).toEqual([['https://a.com/f']]);
    expect(queries.some((q) => q.text.includes('DELETE'))).toBe(false);
    expect(result.deactivated).toBe(2);
  });
});
