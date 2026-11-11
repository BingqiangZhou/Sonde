import { describe, expect, it } from 'vitest';

import type { EpisodeListItem } from './types.ts';
import { buildTimelineHref, episodesApiPath, groupTimelineDays, parseTimelineQuery } from './timeline.ts';

function item(id: number, publishedAt: string | null): EpisodeListItem {
  return {
    id,
    sourceId: 1,
    podcast: '测试播客',
    imageUrl: null,
    title: `第${id}期`,
    url: null,
    publishedAt,
    durationSeconds: null,
    shownotes: null,
  };
}

/** 按日分组:合并连续同北京日的单集(后端按 published_at DESC 下发,追加批严格更早)。 */
describe('groupTimelineDays', () => {
  it('同日单集并为一个组:UTC 20:30(北京次日 04:30)与同日 10:00 同属北京 11月5日', () => {
    const groups = groupTimelineDays([
      item(2, '2026-11-05T02:00:00.000Z'), // 北京 11-05 10:00
      item(1, '2026-11-04T20:30:00.000Z'), // 北京 11-05 04:30
    ]);
    expect(groups).toHaveLength(1);
    expect(groups[0]).toMatchObject({
      key: '2026-11-05',
      year: '2026',
      label: '11月5日',
      weekday: '周四',
      isoDate: '2026-11-05',
    });
    expect(groups[0]?.items.map((i) => i.id)).toEqual([2, 1]);
  });

  it('不同日产出有序组,月日不补零', () => {
    const groups = groupTimelineDays([
      item(3, '2026-03-05T02:00:00.000Z'),
      item(2, '2026-03-04T10:00:00.000Z'),
      item(1, '2026-02-28T10:00:00.000Z'),
    ]);
    expect(groups.map((g) => g.label)).toEqual(['3月5日', '3月4日', '2月28日']);
    expect(groups.map((g) => g.key)).toEqual(['2026-03-05', '2026-03-04', '2026-02-28']);
  });

  it('首页尾部与追加批头部同日时熔为一组(无限滚动拼接场景)', () => {
    const firstBatch = [item(2, '2026-11-05T02:00:00.000Z'), item(1, '2026-11-04T20:30:00.000Z')];
    const appendedBatch = [item(3, '2026-11-04T12:00:00.000Z')]; // 北京 11-04 20:00,与上一条同日
    const groups = groupTimelineDays([...firstBatch, ...appendedBatch]);
    expect(groups).toHaveLength(2);
    expect(groups[0]?.items).toHaveLength(2);
    expect(groups[1]?.items).toHaveLength(1);
  });

  it('空 publishedAt 落入 日期未知 组,year/weekday/isoDate 均为 null(防御路径)', () => {
    const groups = groupTimelineDays([item(1, null), item(2, 'not-a-date')]);
    expect(groups).toHaveLength(1);
    expect(groups[0]).toEqual({
      key: 'unknown',
      year: null,
      label: '日期未知',
      weekday: null,
      isoDate: null,
      items: [item(1, null), item(2, 'not-a-date')],
    });
  });

  it('空列表返回空数组', () => {
    expect(groupTimelineDays([])).toEqual([]);
  });
});

/** ?page=&source=&q= 的宽容解析(与 api 的垃圾值兜底一致)与 api 路径组装。 */
describe('parseTimelineQuery / episodesApiPath', () => {
  it('page 垃圾值/0/负数兜底为 1,正常值保留', () => {
    expect(parseTimelineQuery(new URL('https://x/?page=abc')).page).toBe(1);
    expect(parseTimelineQuery(new URL('https://x/?page=0')).page).toBe(1);
    expect(parseTimelineQuery(new URL('https://x/?page=-3')).page).toBe(1);
    expect(parseTimelineQuery(new URL('https://x/?page=999')).page).toBe(999);
    expect(parseTimelineQuery(new URL('https://x/')).page).toBe(1);
  });

  it('source 正整数保留,垃圾值忽略为 null', () => {
    expect(parseTimelineQuery(new URL('https://x/?source=7')).source).toBe(7);
    expect(parseTimelineQuery(new URL('https://x/?source=abc')).source).toBeNull();
    expect(parseTimelineQuery(new URL('https://x/?source=0')).source).toBeNull();
    expect(parseTimelineQuery(new URL('https://x/?source=-2')).source).toBeNull();
  });

  it('q 去空白并截断到 100,全空白忽略为 null', () => {
    expect(parseTimelineQuery(new URL('https://x/?q=%20%E6%B7%B1%E5%BA%A6%20')).q).toBe('深度');
    expect(parseTimelineQuery(new URL('https://x/?q=%20%20')).q).toBeNull();
    const long = 'a'.repeat(150);
    expect(parseTimelineQuery(new URL(`https://x/?q=${long}`)).q).toHaveLength(100);
  });

  it('category 去空白并截断到 30,全空白忽略为 null', () => {
    expect(parseTimelineQuery(new URL('https://x/?category=%E7%A7%91%E6%8A%80')).category).toBe('科技');
    expect(parseTimelineQuery(new URL('https://x/?category=%20%E5%BD%B1%E8%A7%86%20')).category).toBe('影视');
    expect(parseTimelineQuery(new URL('https://x/?category=%20%20')).category).toBeNull();
    expect(parseTimelineQuery(new URL('https://x/')).category).toBeNull();
    const long = 'a'.repeat(50);
    expect(parseTimelineQuery(new URL(`https://x/?category=${long}`)).category).toHaveLength(30);
  });

  it('episodesApiPath 组装:筛选缺省省略,q/category 编码', () => {
    expect(episodesApiPath({ page: 1, source: null, category: null, q: null })).toBe('/site/episodes?page=1');
    expect(episodesApiPath({ page: 2, source: 3, category: null, q: '深度 学习' })).toBe(
      `/site/episodes?page=2&source=3&q=${encodeURIComponent('深度 学习')}`,
    );
    expect(episodesApiPath({ page: 1, source: null, category: '科技', q: null })).toBe(
      `/site/episodes?page=1&category=${encodeURIComponent('科技')}`,
    );
    expect(episodesApiPath({ page: 1, source: 3, category: '其他', q: 'AI' })).toBe(
      `/site/episodes?page=1&source=3&category=${encodeURIComponent('其他')}&q=AI`,
    );
  });
});

/** 站内筛选链接组装:patch 显式 null 即清除,page 恒丢弃。 */
describe('buildTimelineHref', () => {
  const current = { page: 1, source: 5, category: '科技', q: 'AI' } as const;

  it('点分类 chip:清 source、保留 q', () => {
    expect(buildTimelineHref(current, { source: null, category: '喜剧' })).toBe(
      `/?category=${encodeURIComponent('喜剧')}&q=AI`,
    );
  });

  it('点「全部」:清 source+category、保留 q;全空回落 /', () => {
    expect(buildTimelineHref(current, { source: null, category: null })).toBe('/?q=AI');
    expect(buildTimelineHref({ page: 3, source: null, category: null, q: null }, { source: null, category: null })).toBe('/');
  });

  it('点时间线里的播客名:设 source、清 category、保留 q', () => {
    expect(buildTimelineHref(current, { source: 9, category: null })).toBe('/?source=9&q=AI');
  });

  it('播客 chip 的 ✕:只清 source,category 与 q 保留;空 patch 全保留', () => {
    expect(buildTimelineHref(current, { source: null })).toBe(
      `/?category=${encodeURIComponent('科技')}&q=AI`,
    );
    expect(buildTimelineHref(current)).toBe(
      `/?source=5&category=${encodeURIComponent('科技')}&q=AI`,
    );
  });
});
