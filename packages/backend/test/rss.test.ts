import { describe, expect, it } from 'vitest';

import { episodeInputsFromFeed, parseItunesDuration } from '../src/sources/rss.ts';

function item(overrides: Record<string, unknown> = {}) {
  return {
    guid: 'guid-1',
    title: '第 42 期：聊聊 AI',
    link: 'https://example.com/42',
    isoDate: '2026-09-28T08:00:00.000Z',
    contentSnippet: '本期邀请嘉宾聊 AI 的最新进展。',
    enclosure: { url: 'https://cdn.example.com/42.mp3', length: '52428800', type: 'audio/mpeg' },
    itunesDuration: '1:23:45',
    ...overrides,
  };
}

describe('parseItunesDuration', () => {
  it('parses seconds form', () => {
    expect(parseItunesDuration('5025')).toBe(5025);
  });
  it('parses h:m:s form', () => {
    expect(parseItunesDuration('1:23:45')).toBe(5025);
  });
  it('parses m:s form', () => {
    expect(parseItunesDuration('23:45')).toBe(1425);
  });
  it('returns null on garbage or empty', () => {
    expect(parseItunesDuration('abc')).toBeNull();
    expect(parseItunesDuration('')).toBeNull();
    expect(parseItunesDuration(null)).toBeNull();
  });
});

describe('episodeInputsFromFeed', () => {
  it('normalizes a regular item', () => {
    const [ep] = episodeInputsFromFeed([item()]);
    expect(ep).toMatchObject({
      guid: 'guid-1',
      title: '第 42 期：聊聊 AI',
      url: 'https://example.com/42',
      publishedAt: new Date('2026-09-28T08:00:00.000Z'),
      durationSeconds: 5025,
      enclosureUrl: 'https://cdn.example.com/42.mp3',
      enclosureBytes: 52428800,
    });
  });

  it('skips items without enclosure (cannot transcribe)', () => {
    const result = episodeInputsFromFeed([item({ enclosure: undefined })]);
    expect(result).toHaveLength(0);
  });

  it('skips items without title', () => {
    const result = episodeInputsFromFeed([item({ title: '  ' })]);
    expect(result).toHaveLength(0);
  });

  it('falls back guid to enclosure url', () => {
    const [ep] = episodeInputsFromFeed([item({ guid: undefined, id: undefined })]);
    expect(ep?.guid).toBe('https://cdn.example.com/42.mp3');
  });

  it('strips html from shownotes', () => {
    const [ep] = episodeInputsFromFeed([item({ contentSnippet: undefined, content: '<p>hello <b>world</b></p>' })]);
    expect(ep?.shownotes).toBe('hello world');
  });

  it('first import filters by recency and limit', () => {
    const old = item({ guid: 'old', isoDate: '2020-01-01T00:00:00.000Z' });
    const fresh1 = item({ guid: 'f1' });
    const fresh2 = item({ guid: 'f2' });
    const result = episodeInputsFromFeed([old, fresh1, fresh2], { firstImport: true, firstImportLimit: 1 });
    expect(result.map((e) => e.guid)).toEqual(['f1']);
  });

  it('first import skips items without publish date', () => {
    const result = episodeInputsFromFeed([item({ isoDate: undefined, pubDate: undefined })], { firstImport: true });
    expect(result).toHaveLength(0);
  });

  it('non-first import takes everything up to limit', () => {
    const many = Array.from({ length: 70 }, (_, i) => item({ guid: `g${i}` }));
    expect(episodeInputsFromFeed(many)).toHaveLength(60);
  });
});
