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

const { syncXyzrankSources } = await import('../src/sources/sync.ts');

beforeEach(() => {
  queries.length = 0;
  clientMock.query.mockReset().mockImplementation(async (frag: { text: string; values: unknown[] }) => {
    queries.push(frag);
    return { rows: [] as { inserted?: boolean }[], rowCount: 0 };
  });
  withTxMock.mockClear().mockImplementation((fn: (client: unknown) => Promise<unknown>) => fn(clientMock));
});

describe('syncXyzrankSources(榜单同步)', () => {
  it('空榜单防线:entries 为空直接抛错,绝不清空订阅(上游 API 异常日)', async () => {
    await expect(syncXyzrankSources([])).rejects.toThrow('榜单为空');
    expect(queries).toHaveLength(0); // 连事务都不该开
  });

  it('upsert 写 origin=xyzrank,冲突行一律更新并重新激活', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return frag.text.includes('INSERT INTO sources')
        ? { rows: [{ inserted: true }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    });

    const result = await syncXyzrankSources([
      { name: '榜首播客', feedUrl: 'https://new.example/rss', intervalMinutes: 10 },
      { name: '回榜播客', feedUrl: 'https://back.example/rss', intervalMinutes: 10 },
    ]);

    const upserts = queries.filter((q) => q.text.includes('INSERT INTO sources'));
    expect(upserts).toHaveLength(2);
    // origin 写进 config,与 feedUrl 一起 ::text 转型
    expect(upserts[0]?.text).toMatch(/jsonb_build_object\('feedUrl', \$[0-9]+::text, 'origin', 'xyzrank'\)/);
    expect(upserts[0]?.text).toContain('DO UPDATE SET');
    expect(upserts[0]?.text).toContain('is_active = true');
    // origin 守卫已删(手工订阅不复存在,冲突行不再被拦):防守卫被悄悄加回
    expect(upserts[0]?.text).not.toContain(`WHERE sources.config->>'origin'`);
    expect(upserts[0]?.values.slice(0, 3)).toEqual(['榜首播客', 'https://new.example/rss', 10]);
    // 冲突行也必然返回一行;结果结构不再有 keptManual 字段
    expect(result).toEqual({ added: 2, updated: 0, deactivated: 0 });
  });

  it('upsert 同样写 category 列:有值透传,缺省绑 null', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return { rows: [{ inserted: true }], rowCount: 1 };
    });

    await syncXyzrankSources([
      { name: '榜首', feedUrl: 'https://a.com/rss', intervalMinutes: 10, category: null },
      { name: '次席', feedUrl: 'https://b.com/rss', intervalMinutes: 10, category: '喜剧' },
    ]);

    const upserts = queries.filter((q) => q.text.includes('INSERT INTO sources'));
    expect(upserts).toHaveLength(2);
    expect(upserts[0]?.text).toMatch(
      /INSERT INTO sources\s*\(name,\s*config,\s*interval_minutes,\s*is_active,\s*category\)/,
    );
    expect(upserts[0]?.text).toContain('category = EXCLUDED.category');
    expect(upserts[0]?.text).not.toContain(`WHERE sources.config->>'origin'`);
    expect(upserts[0]?.values[3]).toBeNull();
    expect(upserts[1]?.values[3]).toBe('喜剧');
  });

  it('停用针对所有不在当前榜单的激活源(掉榜保留历史,不删行)', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      if (frag.text.includes('UPDATE sources')) {
        return { rows: [{ id: 9 }] as unknown as { inserted?: boolean }[], rowCount: 1 };
      }
      return { rows: [] as { inserted?: boolean }[], rowCount: 0 };
    });

    const result = await syncXyzrankSources([{ name: 'A', feedUrl: 'https://a.com/f', intervalMinutes: 10 }]);

    const deactivate = queries.filter((q) => q.text.includes('UPDATE sources') && q.text.includes('is_active = false'));
    expect(deactivate).toHaveLength(1);
    expect(deactivate[0]?.text).toContain('WHERE is_active');
    // origin 过滤已删:停用只看是否在当前榜单,不看来源
    expect(deactivate[0]?.text).not.toContain('origin');
    // 数组参数必须显式 ::text[] 转型,否则 Postgres 报 42P18(联调实测)
    expect(deactivate[0]?.text).toMatch(/ALL\(\$[0-9]+::text\[\]\)/);
    expect(deactivate[0]?.values).toEqual([['https://a.com/f']]);
    expect(queries.some((q) => q.text.includes('DELETE'))).toBe(false);
    expect(result.deactivated).toBe(1);
  });
});
