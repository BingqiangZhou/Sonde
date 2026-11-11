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

const { syncSources, syncXyzrankSources, normalizeSeedEntries } = await import('../src/sources/sync.ts');

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
  it('category 字符串会 trim 后随条目返回', () => {
    const [entry] = normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f', category: ' 科技 ' }]);
    expect(entry).toEqual({ name: 'x', feedUrl: 'https://x.com/f', intervalMinutes: 60, category: '科技' });
  });
  it('category 缺省/空串/纯空白 → 视为缺省(键不出现)', () => {
    const [a, b, c] = normalizeSeedEntries([
      { name: 'x', feedUrl: 'https://x.com/f' },
      { name: 'y', feedUrl: 'https://y.com/f', category: '' },
      { name: 'z', feedUrl: 'https://z.com/f', category: '   ' },
    ]);
    expect(a).not.toHaveProperty('category');
    expect(b).not.toHaveProperty('category');
    expect(c).not.toHaveProperty('category');
  });
  it('category 非字符串抛错(配置错误应当响亮)', () => {
    expect(() => normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f', category: 123 }])).toThrow('category');
  });
  it('category 超 30 字符抛错(超长分类的 chip 会被 api/web 截断,永远匹配不到自己)', () => {
    expect(() => normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f', category: '类'.repeat(31) }])).toThrow(
      'category',
    );
    expect(() => normalizeSeedEntries([{ name: 'x', feedUrl: 'https://x.com/f', category: '类'.repeat(30) }])).not.toThrow();
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
    // jsonb_build_object 的参数必须显式 ::text 转型(variadic "any" 推断不出,联调实测 42P18)
    expect(upserts[0]?.text).toMatch(/jsonb_build_object\('feedUrl', \$[0-9]+::text\)/);
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

  it('upsert 写 category 列:有值透传,缺省绑 null', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return { rows: [{ inserted: true }], rowCount: 1 };
    });

    await syncSources([
      { name: 'A', feedUrl: 'https://a.com/f', intervalMinutes: 60, category: '科技' },
      { name: 'B', feedUrl: 'https://b.com/f', intervalMinutes: 60 },
    ]);

    const upserts = queries.filter((q) => q.text.includes('INSERT INTO sources'));
    expect(upserts).toHaveLength(2);
    expect(upserts[0]?.text).toMatch(/INSERT INTO sources\s*\(name,\s*config,\s*interval_minutes,\s*is_active,\s*category\)/);
    expect(upserts[0]?.text).toContain('category = EXCLUDED.category');
    expect(upserts[0]?.values[3]).toBe('科技');
    expect(upserts[1]?.values[3]).toBeNull();
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

  it('手工 seed 只停用无 origin 的源 —— 空 sources.json 不会误伤 xyzrank 等自动同步的订阅', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      return { rows: [] as { inserted?: boolean }[], rowCount: 0 };
    });

    await syncSources([]);

    const deactivate = queries.filter((q) => q.text.includes('is_active = false'));
    expect(deactivate).toHaveLength(1);
    // 停用范围限定在无 origin 的手工源
    expect(deactivate[0]?.text).toContain(`coalesce(config->>'origin', '') = ''`);
  });
});

describe('syncXyzrankSources(榜单自动同步,origin 隔离)', () => {
  it('空榜单防线:entries 为空直接抛错,绝不清空订阅(上游 API 异常日)', async () => {
    await expect(syncXyzrankSources([])).rejects.toThrow('榜单为空');
    expect(queries).toHaveLength(0); // 连事务都不该开
  });

  it('upsert 带 origin=xyzrank,且 DO UPDATE 只作用于自家源(手工订阅不被覆盖)', async () => {
    clientMock.query.mockImplementation(async (frag: { text: string; values: unknown[] }) => {
      queries.push(frag);
      // 榜首插入新行;已有手工行冲突但 UPDATE 被 WHERE origin 拦下 → 无返回行(keptManual)
      if (queries.filter((q) => q.text.includes('INSERT INTO sources')).length === 1) {
        return { rows: [{ inserted: true }], rowCount: 1 };
      }
      return { rows: [] as { inserted?: boolean }[], rowCount: 0 };
    });

    const result = await syncXyzrankSources([
      { name: '榜首播客', feedUrl: 'https://new.example/rss', intervalMinutes: 10 },
      { name: '手工已订', feedUrl: 'https://manual.example/rss', intervalMinutes: 10 },
    ]);

    const upserts = queries.filter((q) => q.text.includes('INSERT INTO sources'));
    expect(upserts).toHaveLength(2);
    // origin 写进 config,与 feedUrl 一起 ::text 转型
    expect(upserts[0]?.text).toMatch(/jsonb_build_object\('feedUrl', \$[0-9]+::text, 'origin', 'xyzrank'\)/);
    // 手工订阅保护:UPDATE 仅当存量行 origin 是 xyzrank
    expect(upserts[0]?.text).toContain(`WHERE sources.config->>'origin' = 'xyzrank'`);
    expect(upserts[0]?.values.slice(0, 3)).toEqual(['榜首播客', 'https://new.example/rss', 10]);
    expect(result).toMatchObject({ added: 1, keptManual: 1 });
  });

  it('upsert 同样写 category 列,origin 守卫不动', async () => {
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
    expect(upserts[0]?.text).toMatch(/INSERT INTO sources\s*\(name,\s*config,\s*interval_minutes,\s*is_active,\s*category\)/);
    expect(upserts[0]?.text).toContain('category = EXCLUDED.category');
    expect(upserts[0]?.text).toContain(`WHERE sources.config->>'origin' = 'xyzrank'`);
    expect(upserts[0]?.values[3]).toBeNull();
    expect(upserts[1]?.values[3]).toBe('喜剧');
  });

  it('停用只针对 origin=xyzrank 且不在当前榜单的源', async () => {
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
    expect(deactivate[0]?.text).toContain(`config->>'origin' = 'xyzrank'`);
    expect(deactivate[0]?.text).toMatch(/ALL\(\$[0-9]+::text\[\]\)/);
    expect(deactivate[0]?.values).toEqual([['https://a.com/f']]);
    expect(result.deactivated).toBe(1);
  });
});
