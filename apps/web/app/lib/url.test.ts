import { describe, expect, it } from 'vitest';

import { safeHttpUrl } from './url.ts';

describe('safeHttpUrl', () => {
  it('http/https 原样放行', () => {
    expect(safeHttpUrl('https://example.com/ep')).toBe('https://example.com/ep');
    expect(safeHttpUrl('http://example.com/ep.mp3')).toBe('http://example.com/ep.mp3');
  });
  it('javascript:/data: 等非 http 协议一律拒绝(feed 是唯一注入面)', () => {
    expect(safeHttpUrl('javascript:alert(1)')).toBeNull();
    expect(safeHttpUrl('data:text/html,<script>')).toBeNull();
    expect(safeHttpUrl('ftp://example.com/x')).toBeNull();
  });
  it('null/空/空白返回 null', () => {
    expect(safeHttpUrl(null)).toBeNull();
    expect(safeHttpUrl('')).toBeNull();
    expect(safeHttpUrl('   ')).toBeNull();
  });
});
