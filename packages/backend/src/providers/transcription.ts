/** 转写 provider：OpenAI 兼容 /audio/transcriptions（默认面向 SiliconFlow 风格端点）。
 *  一次调用转写一个音频分块文件；下载/转码/分块编排见 pipeline/transcribe.ts。 */

import { stat } from 'node:fs/promises';

import { loadConfig } from '../config.ts';
import { ProviderError } from '../errors.ts';
import { recordReceipt } from './receipts.ts';

export interface TranscribeChunkOptions {
  /** 音频分块文件路径 */
  filePath: string;
  /** 上传文件名（含扩展名，如 chunk-000.mp3） */
  fileName: string;
  /** 音频语言提示（可选） */
  language?: string;
  timeoutMs?: number;
}

export interface TranscribeChunkResult {
  text: string;
  model: string;
}

export async function transcribeChunk(options: TranscribeChunkOptions): Promise<TranscribeChunkResult> {
  const config = loadConfig();
  if (!config.transcriptionBaseUrl || !config.transcriptionApiKey || !config.transcriptionModel) {
    throw new ProviderError(
      'transcription',
      '转写未配置：请设置 TRANSCRIPTION_BASE_URL / TRANSCRIPTION_API_KEY / TRANSCRIPTION_MODEL',
    );
  }

  const startedAt = Date.now();
  const bytes = (await stat(options.filePath)).size;
  // 按字节估算音频时长（16kHz 单声道 mp3 ≈ 16kbps ≈ 2000 字节/秒），仅用于记账
  const estimatedSeconds = Math.round(bytes / 2000);

  try {
    const { text } = await callWithRetry(options, 3);
    await recordReceipt({
      service: 'transcription',
      operation: 'transcribe',
      model: config.transcriptionModel,
      audioSeconds: estimatedSeconds,
      ok: true,
      durationMs: Date.now() - startedAt,
    });
    return { text, model: config.transcriptionModel };
  } catch (error) {
    await recordReceipt({
      service: 'transcription',
      operation: 'transcribe',
      model: config.transcriptionModel,
      audioSeconds: estimatedSeconds,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
      durationMs: Date.now() - startedAt,
    });
    throw error;
  }
}

async function callWithRetry(
  options: TranscribeChunkOptions,
  maxAttempts: number,
): Promise<{ text: string }> {
  const config = loadConfig();
  const url = joinUrl(config.transcriptionBaseUrl, '/audio/transcriptions');
  let lastError: Error = new Error('no attempt');

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const { readFile } = await import("node:fs/promises");
      const fileBuffer = await readFile(options.filePath);
      const form = new FormData();
      form.append('file', new Blob([fileBuffer]), options.fileName);
      form.append('model', config.transcriptionModel);
      if (options.language) {
        form.append('language', options.language);
      }

      const res = await fetch(url, {
        method: 'POST',
        headers: { authorization: `Bearer ${config.transcriptionApiKey}` },
        body: form,
        signal: AbortSignal.timeout(options.timeoutMs ?? 600_000),
      });
      if (!res.ok) {
        const detail = await res.text().catch(() => '');
        if ((res.status === 429 || res.status >= 500) && attempt < maxAttempts) {
          lastError = new Error(`${res.status} ${detail.slice(0, 200)}`);
          await sleep(3_000 * attempt);
          continue;
        }
        throw new ProviderError('transcription', `${res.status} ${detail.slice(0, 300)}`);
      }
      const json = (await res.json()) as { text?: string };
      if (!json.text) {
        throw new ProviderError('transcription', '回复缺少 text 字段');
      }
      return { text: json.text };
    } catch (error) {
      // 网络类错误重试；ProviderError 直接抛
      if (error instanceof ProviderError) {
        throw error;
      }
      lastError = error instanceof Error ? error : new Error(String(error));
      if (attempt < maxAttempts) {
        await sleep(3_000 * attempt);
        continue;
      }
    }
  }
  throw new ProviderError('transcription', `转写失败: ${lastError.message}`);
}

function joinUrl(base: string, path: string): string {
  return `${base.replace(/\/+$/, '')}${path}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
