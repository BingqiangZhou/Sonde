import { beforeEach, describe, expect, it, vi } from 'vitest';

/** 仿 sources-service.test:mock db 层,断言落在 SQL 形状与返回计数上。
 *  规则来源(AIHOT collect.ts adaptIntervals 的播客版,用户拍板统一 max=720):
 *  per_day = 近 7 天 episodes(published_at)计数 / 7
 *  target  = per_day ≤ 0.15 ? 720 : round(clip(1440/(per_day×3), 30, 720))
 *  仅写 is_active 且 interval_minutes ≠ target 的行。 */
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

const { adaptSourceIntervals } = await import('../src/sources/adapt.ts');

describe('adaptSourceIntervals', () => {
  let statement: { text: string; values: unknown[] };

  beforeEach(() => {
    rowsMock.mockReset();
    statement = { text: '', values: [] };
  });

  it('单条 SQL:per_day 取近 7 天 published_at 计数 / 7,目标夹逼 [30, 720],无产出走 720 分支', async () => {
    rowsMock.mockResolvedValue([{ id: 1 }, { id: 2 }, { id: 3 }]);
    const result = await adaptSourceIntervals();

    expect(rowsMock).toHaveBeenCalledTimes(1);
    const frag = rowsMock.mock.calls[0][0] as { text: string; values: unknown[] };
    statement = frag;

    // per_day:LATERAL 按源统计近 7 天发布数
    expect(frag.text).toContain('e.source_id = s.id');
    expect(frag.text).toContain("e.published_at > now() - interval '7 days'");
    expect(frag.text).toContain('COUNT(*)::float / 7.0');
    // 目标公式:夹逼 [30, 720];产出稀疏(≤ 0.15/天)直接 720
    expect(frag.text).toContain('GREATEST(30, LEAST(720,');
    expect(frag.text).toContain('ROUND(1440.0 / (p.per_day * 3))');
    expect(frag.text).toContain('<= 0.15 THEN 720');
    // 只动活跃源、只写有变化的行
    expect(frag.text).toContain('WHERE s.is_active');
    expect(frag.text).toContain('s.interval_minutes <> t.interval_minutes');
    expect(frag.text).toContain('updated_at = now()');

    // RETURNING 计数即 updated
    expect(result).toEqual({ updated: 3 });
    void statement;
  });

  it('无命中行时 updated 为 0', async () => {
    rowsMock.mockResolvedValue([]);
    const result = await adaptSourceIntervals();
    expect(result).toEqual({ updated: 0 });
  });
});
