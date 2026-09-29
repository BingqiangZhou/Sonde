import { describe, expect, it } from 'vitest';

import {
  extractJsonPayload,
  parseJsonLoose,
  stripThinking,
} from '../src/util/json.ts';

describe('stripThinking', () => {
  it('removes <think> and <thinking> blocks', () => {
    expect(stripThinking('<think>内部推理</think>{"a":1}')).toBe('{"a":1}');
    expect(stripThinking('<thinking>x</thinking>\n答案')).toBe('答案');
  });

  it('keeps text without blocks unchanged', () => {
    expect(stripThinking('普通文本')).toBe('普通文本');
  });
});

describe('extractJsonPayload', () => {
  it('extracts plain object', () => {
    expect(extractJsonPayload('{"score": 88}')).toBe('{"score": 88}');
  });

  it('extracts from leading/trailing prose', () => {
    const text = '好的，以下是结果：\n{"score": 72, "reason": "有价值"}\n以上。';
    expect(extractJsonPayload(text)).toBe('{"score": 72, "reason": "有价值"}');
  });

  it('extracts from markdown json fence', () => {
    const text = '```json\n{"a": [1, 2]}\n```';
    expect(extractJsonPayload(text)).toBe('{"a": [1, 2]}');
  });

  it('extracts array', () => {
    expect(extractJsonPayload('结果：[{"id":1},{"id":2}] 完毕')).toBe('[{"id":1},{"id":2}]');
  });

  it('handles braces inside strings', () => {
    const text = '{"note": "包含 } 和 { 的文本", "score": 1}';
    expect(extractJsonPayload(text)).toBe(text);
  });

  it('handles escaped quotes inside strings', () => {
    const json = '{"q": "他说：\\"你好 { }\\""}';
    expect(extractJsonPayload(`前置 ${json} 后置`)).toBe(json);
  });

  it('strips thinking block before extracting', () => {
    const text = '<think>我该输出 {"decoy": true}</think>{"real": 1}';
    expect(extractJsonPayload(text)).toBe('{"real": 1}');
  });

  it('returns null when no JSON present', () => {
    expect(extractJsonPayload('这只是一段普通文字。')).toBeNull();
  });

  it('returns null for unbalanced JSON', () => {
    expect(extractJsonPayload('{"broken": ')).toBeNull();
  });
});

describe('parseJsonLoose', () => {
  it('parses extracted payload', () => {
    expect(parseJsonLoose('```json\n{"score": 66}\n```')).toEqual({ score: 66 });
  });

  it('returns null on failure', () => {
    expect(parseJsonLoose('no json here')).toBeNull();
  });
});
