import { afterEach, describe, expect, it, vi } from 'vitest';

const receiptSpy = vi.fn();
vi.mock('../src/providers/receipts.ts', () => ({
  recordReceipt: (...args: unknown[]) => receiptSpy(...args),
}));

/** 转码后 64kbps 单声道 mp3 ≈ 8000 字节/秒（pipeline/transcribe.ts -b:a 64k）。
 *  stat/readFile 都 mock：80000 字节 → 10 秒，除数回归的锚点。 */
vi.mock('node:fs/promises', () => ({
  stat: async () => ({ size: 80_000 }),
  readFile: async () => Buffer.alloc(80_000),
}));

const { transcribeChunk } = await import('../src/providers/transcription.ts');

function okResponse() {
  return {
    ok: true,
    status: 200,
    json: async () => ({ text: '转写文本' }),
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
  TRANSCRIPTION_BASE_URL: 'https://t.example.com/v1',
  TRANSCRIPTION_API_KEY: 'test-key',
  TRANSCRIPTION_MODEL: 'test-model',
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
  vi.useRealTimers();
  receiptSpy.mockClear();
});

describe('transcribeChunk', () => {
  it('成功：audioSeconds 按转码后 64kbps≈8000B/s 估算（80000B → 10s）', async () => {
    setEnv();
    vi.stubGlobal('fetch', vi.fn(async () => okResponse()));

    const result = await transcribeChunk({ filePath: '/tmp/chunk-000.mp3', fileName: 'chunk-000.mp3' });

    expect(result).toEqual({ text: '转写文本', model: 'test-model' });
    expect(receiptSpy).toHaveBeenCalledTimes(1);
    expect(receiptSpy.mock.calls[0]?.[0]).toMatchObject({ service: 'transcription', ok: true, audioSeconds: 10 });
  });

  it('失败：receipt 同样按 8000B/s 记账并重抛', async () => {
    setEnv();
    vi.stubGlobal('fetch', vi.fn(async () => errorResponse(400)));

    await expect(
      transcribeChunk({ filePath: '/tmp/chunk-000.mp3', fileName: 'chunk-000.mp3' }),
    ).rejects.toThrow(/400/);
    expect(receiptSpy).toHaveBeenCalledTimes(1);
    expect(receiptSpy.mock.calls[0]?.[0]).toMatchObject({ ok: false, audioSeconds: 10 });
  });

  it('5xx 重试后成功（线性退避）', async () => {
    setEnv();
    vi.useFakeTimers();
    const fetchMock = vi.fn().mockResolvedValueOnce(errorResponse(503)).mockResolvedValueOnce(okResponse());
    vi.stubGlobal('fetch', fetchMock);

    const pending = transcribeChunk({ filePath: '/tmp/chunk-000.mp3', fileName: 'chunk-000.mp3' });
    await vi.advanceTimersByTimeAsync(3_100);
    const result = await pending;

    expect(result.text).toBe('转写文本');
    expect(fetchMock).toHaveBeenCalledTimes(2);
    // 400 非重试类只记一条；这里 503 一次后成功，只写成功 receipt
    expect(receiptSpy).toHaveBeenCalledTimes(1);
    expect(receiptSpy.mock.calls[0]?.[0]).toMatchObject({ ok: true });
  });

  it('未配置时快速失败且不记 receipt', async () => {
    setEnv({ TRANSCRIPTION_BASE_URL: undefined });
    vi.stubGlobal('fetch', vi.fn());

    await expect(
      transcribeChunk({ filePath: '/tmp/chunk-000.mp3', fileName: 'chunk-000.mp3' }),
    ).rejects.toThrow(/转写未配置/);
    expect(receiptSpy).not.toHaveBeenCalled();
  });
});
