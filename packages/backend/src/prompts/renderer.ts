/** industry/prompts 渲染器。
 *  语法（对齐 AIHOT 的设计）：
 *    {{name}}   变量替换（调用方传值；缺失为硬错误）
 *    {{> file}} 内联同目录下 file.md（缺失为硬错误，防止静默丢规则）
 *  渲染结果附带内容哈希版本（name@hash8），随 analyses/receipts 落库。 */

import { createHash } from 'node:crypto';

export class PromptError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PromptError';
  }
}

const VAR_RE = /\{\{([>~]?)\s*([\w./-]+)\s*\}\}/g;

export interface RenderedPrompt {
  /** 渲染后的完整文本 */
  text: string;
  /** 版本标识 name@hash8 */
  version: string;
}

export function renderPrompt(
  files: Record<string, string>,
  name: string,
  vars: Record<string, string>,
): RenderedPrompt {
  const resolved = new Set<string>();
  const text = renderFile(files, name, vars, resolved, [name]);
  return {
    text,
    version: `${name}@${contentHash(text)}`,
  };
}

function renderFile(
  files: Record<string, string>,
  name: string,
  vars: Record<string, string>,
  resolved: Set<string>,
  stack: string[],
): string {
  if (resolved.has(name)) {
    // 同一文件在一次渲染中只展开一次（公共规则被多个位置 include 时）
    return '';
  }
  const source = files[name];
  if (source === undefined) {
    throw new PromptError(`prompt file not found: ${name} (from ${stack.join(' → ')})`);
  }
  resolved.add(name);

  return source.replace(VAR_RE, (_match, flag: string, key: string) => {
    if (flag === '>') {
      return renderFile(files, key, vars, resolved, [...stack, key]);
    }
    if (flag === '~') {
      throw new PromptError(`unsupported prompt syntax {{~${key}}}`);
    }
    const value = vars[key];
    if (value === undefined) {
      throw new PromptError(`prompt variable missing: {{${key}}} in ${stack.join(' → ')}`);
    }
    return value;
  });
}

function contentHash(text: string): string {
  return createHash('sha256').update(text).digest('hex').slice(0, 8);
}
