import { describe, expect, it } from 'vitest';

import { dayWindowUtc, todayKeyInTz, yesterdayKeyInTz } from '../src/util/time.ts';

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
