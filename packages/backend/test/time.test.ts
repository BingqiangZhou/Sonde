import { describe, expect, it } from 'vitest';

import {
  dayWindowUtc,
  isMondayKey,
  lastMonthKeyInTz,
  lastWeekMondayKeyInTz,
  monthWindowUtc,
  todayKeyInTz,
  weekWindowUtc,
  yesterdayKeyInTz,
} from '../src/util/time.ts';

describe('dayWindowUtc (Asia/Shanghai, 固定 +08:00)', () => {
  it('computes the UTC window for a local day', () => {
    const { start, end } = dayWindowUtc('2026-09-28', 'Asia/Shanghai');
    expect(start.toISOString()).toBe('2026-09-27T16:00:00.000Z');
    expect(end.toISOString()).toBe('2026-09-28T16:00:00.000Z');
  });

  it('handles month boundaries', () => {
    const { start } = dayWindowUtc('2026-01-01', 'Asia/Shanghai');
    expect(start.toISOString()).toBe('2025-12-31T16:00:00.000Z');
  });

  it('rejects invalid keys', () => {
    expect(() => dayWindowUtc('2026-9-28', 'Asia/Shanghai')).toThrow();
    expect(() => dayWindowUtc('not-a-date', 'Asia/Shanghai')).toThrow();
    expect(() => dayWindowUtc('2026-13-01', 'Asia/Shanghai')).toThrow();
  });
});

describe('dayWindowUtc (DST timezone)', () => {
  it('handles America/New_York summer (UTC-4)', () => {
    const { start, end } = dayWindowUtc('2026-07-15', 'America/New_York');
    expect(start.toISOString()).toBe('2026-07-15T04:00:00.000Z');
    expect(end.toISOString()).toBe('2026-07-16T04:00:00.000Z');
  });

  it('handles America/New_York winter (UTC-5)', () => {
    const { start } = dayWindowUtc('2026-01-15', 'America/New_York');
    expect(start.toISOString()).toBe('2026-01-15T05:00:00.000Z');
  });

  it('handles the DST transition day (2026-03-08, spring forward)', () => {
    // 当天本地只有 23 小时
    const { start, end } = dayWindowUtc('2026-03-08', 'America/New_York');
    expect(end.getTime() - start.getTime()).toBe(23 * 60 * 60 * 1000);
    expect(start.toISOString()).toBe('2026-03-08T05:00:00.000Z');
  });
});

describe('calendar keys', () => {
  it('todayKeyInTz maps an instant to the local calendar day', () => {
    // UTC 2026-09-28T20:00 = 北京 2026-09-29T04:00
    expect(todayKeyInTz(new Date('2026-09-28T20:00:00Z'), 'Asia/Shanghai')).toBe('2026-09-29');
    // 同一时刻在纽约仍是 09-28
    expect(todayKeyInTz(new Date('2026-09-28T20:00:00Z'), 'America/New_York')).toBe('2026-09-28');
  });

  it('yesterdayKeyInTz returns the previous local day', () => {
    expect(yesterdayKeyInTz(new Date('2026-09-28T20:00:00Z'), 'Asia/Shanghai')).toBe('2026-09-28');
  });
});

describe('week windows (周报)', () => {
  it('computes a 7-day UTC window starting Monday local midnight', () => {
    // 2026-09-21 是周一
    const { start, end } = weekWindowUtc('2026-09-21', 'Asia/Shanghai');
    expect(start.toISOString()).toBe('2026-09-20T16:00:00.000Z');
    expect(end.toISOString()).toBe('2026-09-27T16:00:00.000Z');
    expect(end.getTime() - start.getTime()).toBe(7 * 24 * 60 * 60 * 1000);
  });

  it('handles weeks crossing a month boundary', () => {
    // 2026-08-31 是周一，窗口跨入 9 月
    const { start, end } = weekWindowUtc('2026-08-31', 'Asia/Shanghai');
    expect(start.toISOString()).toBe('2026-08-30T16:00:00.000Z');
    expect(end.toISOString()).toBe('2026-09-06T16:00:00.000Z');
  });

  it('handles DST weeks (America/New_York, 2026-11-01 周含秋令时)', () => {
    const { start, end } = weekWindowUtc('2026-10-26', 'America/New_York');
    // 该周包含 11-01 回拨，共 169 小时
    expect(end.getTime() - start.getTime()).toBe(169 * 60 * 60 * 1000);
  });

  it('rejects non-Monday keys', () => {
    expect(() => weekWindowUtc('2026-09-22', 'Asia/Shanghai')).toThrow(/Monday/);
    expect(() => weekWindowUtc('not-a-date', 'Asia/Shanghai')).toThrow();
  });

  it('isMondayKey detects weekdays correctly', () => {
    expect(isMondayKey('2026-09-21')).toBe(true);
    expect(isMondayKey('2026-09-27')).toBe(false); // 周日
  });

  it('lastWeekMondayKeyInTz returns the previous week’s Monday', () => {
    // 北京 2026-09-29（周二）→ 上周一 = 2026-09-21
    expect(lastWeekMondayKeyInTz(new Date('2026-09-28T20:00:00Z'), 'Asia/Shanghai')).toBe('2026-09-21');
    // 北京 2026-09-28（周一）当天 → 上周一 = 2026-09-21
    expect(lastWeekMondayKeyInTz(new Date('2026-09-27T20:00:00Z'), 'Asia/Shanghai')).toBe('2026-09-21');
    // 周日：北京 2026-09-27 → 上周一 = 2026-09-14
    expect(lastWeekMondayKeyInTz(new Date('2026-09-26T20:00:00Z'), 'Asia/Shanghai')).toBe('2026-09-14');
  });
});

describe('month windows (月报)', () => {
  it('computes the UTC window for a calendar month', () => {
    const { start, end } = monthWindowUtc('2026-09', 'Asia/Shanghai');
    expect(start.toISOString()).toBe('2026-08-31T16:00:00.000Z');
    expect(end.toISOString()).toBe('2026-09-30T16:00:00.000Z');
    expect(end.getTime() - start.getTime()).toBe(30 * 24 * 60 * 60 * 1000);
  });

  it('handles February and year boundaries', () => {
    const feb = monthWindowUtc('2028-02', 'Asia/Shanghai'); // 闰年 29 天
    expect(feb.end.getTime() - feb.start.getTime()).toBe(29 * 24 * 60 * 60 * 1000);
    const jan = monthWindowUtc('2026-01', 'Asia/Shanghai');
    expect(jan.start.toISOString()).toBe('2025-12-31T16:00:00.000Z');
    const dec = monthWindowUtc('2026-12', 'Asia/Shanghai');
    expect(dec.end.toISOString()).toBe('2026-12-31T16:00:00.000Z');
  });

  it('rejects invalid month keys', () => {
    expect(() => monthWindowUtc('2026-13', 'Asia/Shanghai')).toThrow();
    expect(() => monthWindowUtc('2026-9', 'Asia/Shanghai')).toThrow();
    expect(() => monthWindowUtc('2026-09-01', 'Asia/Shanghai')).toThrow();
  });

  it('lastMonthKeyInTz returns the previous calendar month', () => {
    expect(lastMonthKeyInTz(new Date('2026-09-28T20:00:00Z'), 'Asia/Shanghai')).toBe('2026-08');
    // 跨年：北京 2026-01-15 → 2025-12
    expect(lastMonthKeyInTz(new Date('2026-01-14T20:00:00Z'), 'Asia/Shanghai')).toBe('2025-12');
  });
});
