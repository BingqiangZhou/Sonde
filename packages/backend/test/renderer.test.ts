import { describe, expect, it } from 'vitest';

import { PromptError, renderPrompt } from '../src/prompts/renderer.ts';

const files = {
  main: '站点：{{siteName}}\n规则：\n{{> rules}}\n材料：{{material}}',
  rules: '- 规则一\n- 规则二（引用 {{siteName}}）',
  dup: 'A{{> rules}} B {{> rules}} C',
};

describe('renderPrompt', () => {
  it('substitutes variables and inlines includes', () => {
    const result = renderPrompt(files, 'main', { siteName: '声读', material: 'M' });
    expect(result.text).toBe('站点：声读\n规则：\n- 规则一\n- 规则二（引用 声读）\n材料：M');
  });

  it('includes can use variables provided by the caller', () => {
    const result = renderPrompt(
      { a: '{{> b}}', b: '值：{{v}}' },
      'a',
      { v: 'X' },
    );
    expect(result.text).toBe('值：X');
  });

  it('expands the same include only once', () => {
    const result = renderPrompt(files, 'dup', { siteName: '声读' });
    expect(result.text).toBe('A- 规则一\n- 规则二（引用 声读） B  C');
  });

  it('throws hard error on missing variable', () => {
    expect(() => renderPrompt(files, 'main', { siteName: 'x' })).toThrow(PromptError);
    expect(() => renderPrompt(files, 'main', { siteName: 'x' })).toThrow(/material/);
  });

  it('throws hard error on missing file', () => {
    expect(() => renderPrompt({ a: '{{> nope}}' }, 'a', {})).toThrow(PromptError);
    expect(() => renderPrompt({}, 'missing', {})).toThrow(PromptError);
  });

  it('version is name@hash8 and stable for identical content', () => {
    const a = renderPrompt(files, 'main', { siteName: '声读', material: 'M' });
    const b = renderPrompt(files, 'main', { siteName: '声读', material: 'M' });
    const c = renderPrompt(files, 'main', { siteName: '其他', material: 'M' });
    expect(a.version).toBe(b.version);
    expect(a.version).not.toBe(c.version);
    expect(a.version).toMatch(/^main@[0-9a-f]{8}$/);
  });
});
