import { afterEach, describe, expect, it, vi } from 'vitest';
import { z } from 'zod';

const receiptSpy = vi.fn();
vi.mock('../src/providers/receipts.ts', () => ({
  recordReceipt: (...args: unknown[]) => receiptSpy(...args),
}));

const { chatJson } = await import('../src/providers/llm.ts');

function okResponse(content: string) {
  return {
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{ message: { content } }],
      usage: { prompt_tokens: 100, completion_tokens: 50 },
    }),
  };
}

function errorResponse(status: number) {
  return {
    ok: false,
    status,
    text: async () => 'upstream error',
  };
}

const baseEnv = {
  LLM_BASE_URL: 'https://api.example.com/v1',
  LLM_API_KEY: 'test-key',
  LLM_MODEL: 'test-model',
};

function setEnv(extra: Record<string, string | undefined> = {}) {
  const merged = { ...baseEnv, ...extra };
  for (const [key, value] of Object.entries(merged)) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }
}

afterEach(() => {
  vi.unstubAllGlobals();
  receiptSpy.mockClear();
});

describe('chatJson', () => {
  it('parses plain JSON and records an ok receipt', async () => {
    setEnv();
    const fetchMock = vi.fn(async () => okResponse('{"score": 88, "reason": "好"}'));
    vi.stubGlobal('fetch', fetchMock);

    const result = await chatJson<{ score: number }>({
      system: 's',
      user: 'u',
      operation: 'score',
    });

    expect(result.data).toEqual({ score: 88, reason: '好' });
    expect(result.model).toBe('test-model');
    expect(receiptSpy).toHaveBeenCalledTimes(1);
    expect(receiptSpy.mock.calls[0]?.[0]).toMatchObject({ service: 'llm', operation: 'score', ok: true });
  });

  it('parses JSON wrapped in fences and thinking blocks', async () => {
    setEnv();
    vi.stubGlobal('fetch', vi.fn(async () =>
      okResponse('<think>推理</think>```json\n{"score": 60}\n```'),
    ));

    const result = await chatJson({ system: 's', user: 'u', operation: 'score' });
    expect(result.data).toEqual({ score: 60 });
  });

  it('validates with zod schema', async () => {
    setEnv();
    vi.stubGlobal('fetch', vi.fn(async () => okResponse('{"score": 88}')));

    const schema = z.object({ score: z.number().min(0).max(100) });
    const result = await chatJson({ system: 's', user: 'u', operation: 'score', schema });
    expect(result.data).toEqual({ score: 88 });

    vi.stubGlobal('fetch', vi.fn(async () => okResponse('{"score": 999}')));
    await expect(
      chatJson({ system: 's', user: 'u', operation: 'score', schema, retryBaseMs: 1 }),
    ).rejects.toThrow(/校验失败/);
  });

  it('retries on 5xx then succeeds', async () => {
    setEnv();
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(errorResponse(502))
      .mockResolvedValueOnce(okResponse('{"a": 1}'));
    vi.stubGlobal('fetch', fetchMock);

    const result = await chatJson({
      system: 's',
      user: 'u',
      operation: 'score',
      retryBaseMs: 1,
    });
    expect(result.data).toEqual({ a: 1 });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    // 失败一次 + 成功一次 = 两条 receipt
    expect(receiptSpy).toHaveBeenCalledTimes(2);
  });

  it('does not retry on 400', async () => {
    setEnv();
    const fetchMock = vi.fn(async () => errorResponse(400));
    vi.stubGlobal('fetch', fetchMock);

    await expect(
      chatJson({ system: 's', user: 'u', operation: 'score', retryBaseMs: 1 }),
    ).rejects.toThrow(/400/);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('fails fast with a clear message when not configured', async () => {
    setEnv({ LLM_BASE_URL: undefined });
    vi.stubGlobal('fetch', vi.fn());

    await expect(
      chatJson({ system: 's', user: 'u', operation: 'score' }),
    ).rejects.toThrow(/LLM 未配置/);
    expect(receiptSpy).not.toHaveBeenCalled();
  });
});
