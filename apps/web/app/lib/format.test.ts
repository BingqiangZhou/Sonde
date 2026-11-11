import { describe, expect, it } from 'vitest';

import {
  currentShanghaiYear,
  formatDate,
  formatDateTime,
  formatDuration,
  formatTimelineStamp,
  formatWeekdayCn,
  shanghaiYmd,
} from './format.ts';

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

/** 时间线左槽分两行渲染:月日(不补零)在上、HH:mm 在下;年份单独给出,
 *  供组件判断跨年(与当前北京年份不同才在左槽标年份)。 */
describe('formatTimelineStamp / currentShanghaiYear', () => {
  it('UTC 20:30 在北京已是次日:取北京日期,月日去前导零', () => {
    expect(formatTimelineStamp('2026-11-04T20:30:00.000Z')).toEqual({
      year: '2026',
      date: '11月5日',
      time: '04:30',
    });
  });

  it('个位数月日不补零(北京时间同日 10:00 样本)', () => {
    expect(formatTimelineStamp('2026-03-04T02:00:00.000Z')).toEqual({
      year: '2026',
      date: '3月4日',
      time: '10:00',
    });
  });

  it('空值/非法值返回 null(组件回落 日期未知)', () => {
    expect(formatTimelineStamp(null)).toBeNull();
    expect(formatTimelineStamp('not-a-date')).toBeNull();
  });

  it('currentShanghaiYear 取北京年份(UTC 年末已跨年样本)', () => {
    expect(currentShanghaiYear(new Date('2026-12-31T20:00:00.000Z'))).toBe('2027');
  });
});

/** 时间线按日分组用的日键与中文短星期(通栏日分隔线),同样固定北京时区。 */
describe('shanghaiYmd / formatWeekdayCn', () => {
  it('UTC 20:30 在北京已是次日:日键取北京日期(跨日样本)', () => {
    expect(shanghaiYmd('2026-11-04T20:30:00.000Z')).toBe('2026-11-05');
    expect(shanghaiYmd('2026-11-04T02:00:00.000Z')).toBe('2026-11-04');
  });

  it('空值/非法值返回 null', () => {
    expect(shanghaiYmd(null)).toBeNull();
    expect(shanghaiYmd('not-a-date')).toBeNull();
  });

  it('星期取北京日期的中文短星期(跨日样本同样落在次日)', () => {
    expect(formatWeekdayCn('2026-11-11T02:00:00.000Z')).toBe('周三');
    expect(formatWeekdayCn('2026-11-12T02:00:00.000Z')).toBe('周四');
    expect(formatWeekdayCn('2026-11-10T20:30:00.000Z')).toBe('周三');
  });

  it('星期空值/非法值返回 null', () => {
    expect(formatWeekdayCn(null)).toBeNull();
    expect(formatWeekdayCn('not-a-date')).toBeNull();
  });
});
