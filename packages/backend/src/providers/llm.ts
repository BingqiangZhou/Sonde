/** 通用 OpenAI 兼容 LLM 客户端：chatJson（重试 + 记账 + 容错 JSON 解析）。 */

import { createHash } from 'node:crypto';
import type { ZodType } from 'zod';

import { loadConfig } from '../config.ts';
import { ProviderError } from '../errors.ts';
import { parseJsonLoose, stripThinking } from '../util/json.ts';
import { recordReceipt } from './receipts.ts';

export interface ChatOptions {
  system: string;
  user: string;
  /** 业务操作名（receipts 记账用），如 'score' | 'write' | 'report' */
  operation: string;
  /** 输出 JSON 的 zod 校验；提供时校验失败按可重试错误处理 */
  schema?: ZodType;
  temperature?: number;
  maxTokens?: number;
  timeoutMs?: number;
  /** 覆盖 env 中的模型（留空用 LLM_MODEL） */
  model?: string;
  maxAttempts?: number;
  /** 重试基础退避毫秒（默认 2000，测试注入用） */
  retryBaseMs?: number;
}

export interface ChatJsonResult<T> {
  data: T;
  model: string;
  promptVersion: string;
}

interface ChatCompletionResponse {
  choices?: { message?: { content?: string | null; reasoning_content?: string | null } }[];
  usage?: { prompt_tokens?: number; completion_tokens?: number };
  error?: { message?: string };
}

export async function chatJson<T = unknown>(options: ChatOptions): Promise<ChatJsonResult<T>> {
  const { data, rawText } = await chatWithRetry(options);
  return {
    data: data as T,
    model: resolveModel(options.model),
    promptVersion: promptHash(options.system + '\n\n' + options.user),
  };
}

/** 纯文本补全（目前无调用方，保留给未来全文类需求）。 */
export async function chatText(options: Omit<ChatOptions, 'schema'>): Promise<string> {
  const { rawText } = await chatWithRetry({ ...options, schema: undefined });
  return rawText;
}

async function chatWithRetry(options: ChatOptions): Promise<{ data: unknown; rawText: string }> {
  const config = loadConfig();
  if (!config.llmBaseUrl || !config.llmApiKey || !resolveModel(options.model)) {
    throw new ProviderError('llm', 'LLM 未配置：请设置 LLM_BASE_URL / LLM_API_KEY / LLM_MODEL');
  }

  const maxAttempts = options.maxAttempts ?? 3;
  let lastError: Error = new ProviderError('llm', 'no attempt made');

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const startedAt = Date.now();
    let usage: { prompt_tokens?: number; completion_tokens?: number } | undefined;
    let model = resolveModel(options.model);
    try {
      const { text, usage: u, model: m } = await callChatCompletions(options);
      usage = u;
      model = m;

      const parsed = parseJsonLoose(text);
      if (parsed === null) {
        throw new ProviderError('llm', '回复中未找到 JSON');
      }
      if (options.schema) {
        const validated = options.schema.safeParse(parsed);
        if (!validated.success) {
          throw new ProviderError(
            'llm',
            `JSON 校验失败: ${validated.error.issues.slice(0, 3).map((i) => `${i.path.join('.')}: ${i.message}`).join('; ')}`,
          );
        }
        await recordReceipt({
          service: 'llm',
          operation: options.operation,
          model,
          inputTokens: usage?.prompt_tokens ?? null,
          outputTokens: usage?.completion_tokens ?? null,
          ok: true,
          durationMs: Date.now() - startedAt,
        });
        return { data: validated.data, rawText: text };
      }

      await recordReceipt({
        service: 'llm',
        operation: options.operation,
        model,
        inputTokens: usage?.prompt_tokens ?? null,
        outputTokens: usage?.completion_tokens ?? null,
        ok: true,
        durationMs: Date.now() - startedAt,
      });
      return { data: parsed, rawText: text };
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      await recordReceipt({
        service: 'llm',
        operation: options.operation,
        model,
        ok: false,
        error: lastError.message,
        durationMs: Date.now() - startedAt,
      });
      if (attempt < maxAttempts && isRetryable(lastError)) {
        await sleep(backoffMs(attempt, options.retryBaseMs));
        continue;
      }
      throw new ProviderError('llm', `调用失败（${attempt}/${maxAttempts}）: ${lastError.message}`);
    }
  }
  throw new ProviderError('llm', lastError.message);
}

async function callChatCompletions(
  options: ChatOptions,
): Promise<{ text: string; usage: NonNullable<ChatCompletionResponse['usage']>; model: string }> {
  const config = loadConfig();
  const model = resolveModel(options.model);
  const url = joinUrl(config.llmBaseUrl, '/chat/completions');

  const body: Record<string, unknown> = {
    model,
    messages: [
      { role: 'system', content: options.system },
      { role: 'user', content: options.user },
    ],
    temperature: options.temperature ?? 0.3,
  };
  if (options.maxTokens) {
    body.max_tokens = options.maxTokens;
  }
  if (process.env.LLM_JSON_MODE === '1') {
    body.response_format = { type: 'json_object' };
  }

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${config.llmApiKey}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(options.timeoutMs ?? 180_000),
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    const err = new LlmHttpError(res.status, `${res.status} ${detail.slice(0, 300)}`);
    throw err;
  }

  const json = (await res.json()) as ChatCompletionResponse;
  if (json.error?.message) {
    throw new LlmHttpError(500, json.error.message);
  }
  const message = json.choices?.[0]?.message;
  const content = stripThinking(message?.content ?? '');
  if (!content) {
    throw new ProviderError('llm', '回复内容为空');
  }
  return {
    text: content,
    usage: json.usage ?? {},
    model,
  };
}

class LlmHttpError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'LlmHttpError';
    this.status = status;
  }
}

function isRetryable(error: Error): boolean {
  if (error instanceof LlmHttpError) {
    return error.status === 429 || error.status === 408 || error.status >= 500;
  }
  // fetch 网络错误（TypeError）与超时（TimeoutError）可重试
  return error instanceof TypeError || error.name === 'TimeoutError' || error.name === 'AbortError';
}

function backoffMs(attempt: number, baseMs = 2_000): number {
  return Math.min(baseMs * 2 ** (attempt - 1), 30_000);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function resolveModel(override?: string): string {
  return override || loadConfig().llmModel;
}

function joinUrl(base: string, path: string): string {
  return `${base.replace(/\/+$/, '')}${path}`;
}

function promptHash(text: string): string {
  return createHash('sha256').update(text).digest('hex').slice(0, 8);
}
