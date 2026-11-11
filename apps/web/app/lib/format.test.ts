import { describe, expect, it } from 'vitest';

import { formatDate, formatDateTime, formatDuration } from './format.ts';

/** 时间线展示固定用北京(Asia/Shanghai)时间,与运行环境时区无关:
 *  SSR 容器是 UTC,浏览器时区不定——不固定时区会导致首屏与水合文本不一致。 */
describe('formatDate / formatDateTime 固定北京时区', () => {
  it('UTC 20:30 在北京已是次日 04:30(跨日样本)', () => {
    expect(formatDate('2026-11-04T20:30:00.000Z')).toBe('2026-11-05');
    expect(formatDateTime('2026-11-04T20:30:00.000Z')).toBe('2026-11-05 04:30');
  });

  it('UTC 02:00 在北京同日 10:00', () => {
    expect(formatDateTime('2026-11-04T02:00:00.000Z')).toBe('2026-11-04 10:00');
  });

  it('空值/非法值返回 日期未知', () => {
    expect(formatDate(null)).toBe('日期未知');
    expect(formatDateTime('not-a-date')).toBe('日期未知');
  });
});

describe('formatDuration', () => {
  it('小时+分钟 / 仅分钟 / 空值', () => {
    expect(formatDuration(5025)).toBe('1 小时 24 分钟');
    expect(formatDuration(1425)).toBe('24 分钟');
    expect(formatDuration(0)).toBe('');
    expect(formatDuration(null)).toBe('');
  });
});
