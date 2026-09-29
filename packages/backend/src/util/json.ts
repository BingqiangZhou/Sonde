/** LLM 输出的容错 JSON 提取：剥思考标签 / 代码围栏 / 杂文，取首个平衡 JSON 块。 */

const THINK_BLOCK_RE = /<think(?:ing)?>[\s\S]*?<\/think(?:ing)?>\s*/gi;
const FENCE_RE = /```(?:json|jsonc)?\s*([\s\S]*?)```/gi;

/** 去掉 <think>…</think> 块（部分推理模型会把推理过程放进正文）。 */
export function stripThinking(text: string): string {
  return text.replace(THINK_BLOCK_RE, '').trim();
}

/** 从模型回复中提取第一个平衡的 JSON 对象或数组（感知字符串内的括号与转义）。 */
export function extractJsonPayload(text: string): string | null {
  const cleaned = stripThinking(text);
  const candidates: string[] = [cleaned, ...fencedBlocks(cleaned)];

  for (const candidate of candidates) {
    const extracted = findBalancedJson(candidate);
    if (extracted !== null) {
      return extracted;
    }
  }
  return null;
}

/** 提取并解析；失败返回 null。 */
export function parseJsonLoose<T = unknown>(text: string): T | null {
  const payload = extractJsonPayload(text);
  if (payload === null) {
    return null;
  }
  try {
    return JSON.parse(payload) as T;
  } catch {
    return null;
  }
}

function fencedBlocks(text: string): string[] {
  const blocks: string[] = [];
  for (const match of text.matchAll(FENCE_RE)) {
    const body = match[1];
    if (body !== undefined) {
      blocks.push(body);
    }
  }
  return blocks;
}

function findBalancedJson(text: string): string | null {
  const start = firstJsonBracket(text);
  if (start === -1) {
    return null;
  }
  const open = text[start] as '{' | '[';
  const close = open === '{' ? '}' : ']';

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i] as string;
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
    } else if (ch === open) {
      depth++;
    } else if (ch === close) {
      depth--;
      if (depth === 0) {
        return text.slice(start, i + 1);
      }
    }
  }
  return null;
}

function firstJsonBracket(text: string): number {
  const object = text.indexOf('{');
  const array = text.indexOf('[');
  if (object === -1 && array === -1) {
    return -1;
  }
  if (object === -1) {
    return array;
  }
  if (array === -1) {
    return object;
  }
  return Math.min(object, array);
}
