/** 单集转写流水线（移植自旧 Python 六步流水线）：
 *  下载 → 转码(16kHz 单声道 mp3) → 分块(≤10MB) → 逐块转写 → 合并 → 派发分析。 */

import { spawn } from 'node:child_process';
import { createWriteStream } from 'node:fs';
import { mkdtemp, readdir, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';

import { loadConfig } from '../config.ts';
import { row, rows, sql } from '../db/db.ts';
import { sendJob } from '../queue/boss.ts';
import { transcribeChunk } from '../providers/transcription.ts';

/** 单集时长上限（超过则跳过转写） */
const MAX_DURATION_SECONDS = 4 * 60 * 60;
/** 音频文件字节上限 */
const MAX_AUDIO_BYTES = 400 * 1024 * 1024;
/** 64kbps 单声道 ≈ 8000 字节/秒；10MB 上限 → 每块约 1250 秒 */
const CHUNK_SECONDS = 1250;
const USER_AGENT = 'SondeBot/1.0 (+https://github.com/BingqiangZhou/Sonde)';

interface EpisodeRow {
  id: number;
  enclosure_url: string | null;
  enclosure_bytes: number | null;
  duration_seconds: number | null;
  transcribe_status: string;
}

export async function transcribeEpisode(episodeId: number): Promise<void> {
  const episode = await row<EpisodeRow>(sql`
    SELECT id, enclosure_url, enclosure_bytes, duration_seconds, transcribe_status
    FROM episodes WHERE id = ${episodeId}
  `);
  if (!episode) {
    console.warn(`[transcribe] episode ${episodeId} not found`);
    return;
  }
  if (episode.transcribe_status === 'done' || episode.transcribe_status === 'skipped') {
    return;
  }

  // 配置缺失时直接失败，不进入下载/转码（避免无谓流量与队列重试）
  const config = loadConfig();
  if (!config.transcriptionBaseUrl || !config.transcriptionApiKey || !config.transcriptionModel) {
    await markEpisode(
      episodeId,
      'failed',
      '转写未配置：请设置 TRANSCRIPTION_BASE_URL / TRANSCRIPTION_API_KEY / TRANSCRIPTION_MODEL',
    );
    return;
  }

  if (!episode.enclosure_url) {
    await markEpisode(episodeId, 'skipped', 'no enclosure url');
    return;
  }
  if ((episode.duration_seconds ?? 0) > MAX_DURATION_SECONDS) {
    await markEpisode(episodeId, 'skipped', `duration ${episode.duration_seconds}s exceeds limit`);
    return;
  }

  const workDir = await mkdtemp(join(tmpdir(), `sonde-ep-${episodeId}-`));
  try {
    // 1/5 下载
    await setStatus(episodeId, 'downloading');
    const originalPath = join(workDir, 'original.bin');
    await downloadAudio(episode.enclosure_url, originalPath, episode.enclosure_bytes);

    // 2/5 转码（统一 16kHz 单声道 64kbps mp3，ASR 友好）
    await setStatus(episodeId, 'converting');
    const convertedPath = join(workDir, 'converted.mp3');
    await runFfmpeg(['-hide_banner', '-loglevel', 'error', '-y', '-i', originalPath, '-vn', '-ac', '1', '-ar', '16000', '-b:a', '64k', convertedPath]);
    const convertedBytes = (await stat(convertedPath)).size;

    // 3/5 分块（10MB 上限对齐 CHUNK_SECONDS）
    await setStatus(episodeId, 'transcribing');
    const chunkFiles = await splitIfNeeded(convertedPath, convertedBytes);

    // 4/5 逐块转写
    const texts: string[] = [];
    for (let i = 0; i < chunkFiles.length; i++) {
      const file = chunkFiles[i] as string;
      const { text } = await transcribeChunk({
        filePath: file,
        fileName: `chunk-${String(i).padStart(3, '0')}.mp3`,
      });
      texts.push(text.trim());
      console.log(`[transcribe] episode=${episodeId} chunk ${i + 1}/${chunkFiles.length} done`);
    }

    // 5/5 合并保存 → 派发分析
    const transcript = texts.filter(Boolean).join('\n');
    if (!transcript) {
      throw new Error('transcription returned empty text');
    }
    await rows(sql`
      UPDATE episodes
      SET body_text = ${transcript},
          body_status = 'ok',
          transcribe_status = 'analyzing',
          transcribe_error = NULL,
          transcribed_at = now(),
          updated_at = now()
      WHERE id = ${episodeId}
    `);
    await sendJob('episodes.analyze', { episodeId }, { singletonKey: `analyze:${episodeId}` });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await markEpisode(episodeId, 'failed', message.slice(0, 500));
    // 4xx 下载错误属永久失败，不再重试；其余抛出让队列重试
    if (error instanceof PermanentTranscribeError) {
      return;
    }
    throw error;
  } finally {
    await rm(workDir, { recursive: true, force: true }).catch(() => {});
  }
}

class PermanentTranscribeError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PermanentTranscribeError';
  }
}

async function downloadAudio(url: string, destPath: string, expectedBytes: number | null): Promise<void> {
  if (expectedBytes && expectedBytes > MAX_AUDIO_BYTES) {
    throw new PermanentTranscribeError(`audio size ${expectedBytes} exceeds limit`);
  }
  const res = await fetch(url, {
    headers: { 'user-agent': USER_AGENT },
    redirect: 'follow',
    signal: AbortSignal.timeout(30 * 60 * 1000),
  });
  if (res.status >= 400 && res.status < 500 && res.status !== 429) {
    throw new PermanentTranscribeError(`download failed: ${res.status}`);
  }
  if (!res.ok) {
    throw new Error(`download failed: ${res.status}`);
  }
  if (!res.body) {
    throw new Error('download returned no body');
  }

  const declared = Number.parseInt(res.headers.get('content-length') ?? '', 10);
  if (Number.isFinite(declared) && declared > MAX_AUDIO_BYTES) {
    throw new PermanentTranscribeError(`audio size ${declared} exceeds limit`);
  }

  await pipelineToFile(res.body, destPath, MAX_AUDIO_BYTES);
}

async function pipelineToFile(
  body: ReadableStream<Uint8Array>,
  destPath: string,
  maxBytes: number,
): Promise<void> {
  const { Readable } = await import('node:stream');
  const { pipeline } = await import('node:stream/promises');
  const nodeStream = Readable.fromWeb(body as import('node:stream/web').ReadableStream);
  let total = 0;
  nodeStream.on('data', (chunk: Buffer) => {
    total += chunk.length;
    if (total > maxBytes) {
      nodeStream.destroy(new PermanentTranscribeError(`audio stream exceeded ${maxBytes} bytes`));
    }
  });
  await pipeline(nodeStream, createWriteStream(destPath));
}

async function splitIfNeeded(convertedPath: string, convertedBytes: number): Promise<string[]> {
  const tenMb = 10 * 1024 * 1024;
  if (convertedBytes <= tenMb) {
    return [convertedPath];
  }
  const prefix = convertedPath.replace(/\.mp3$/, '');
  await runFfmpeg([
    '-hide_banner', '-loglevel', 'error', '-y',
    '-i', convertedPath,
    '-f', 'segment',
    '-segment_time', String(CHUNK_SECONDS),
    '-c', 'copy',
    `${prefix}-chunk-%03d.mp3`,
  ]);
  const dir = dirname(convertedPath);
  const chunks = (await readdir(dir))
    .filter((f) => f.startsWith('converted-chunk-') && f.endsWith('.mp3'))
    .sort();
  if (chunks.length === 0) {
    throw new Error('ffmpeg segmentation produced no chunks');
  }
  return chunks.map((f) => join(dir, f));
}
async function runFfmpeg(args: string[]): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn('ffmpeg', args, { windowsHide: true });
    let stderr = '';
    child.stderr.on('data', (data: Buffer) => {
      stderr += data.toString();
      if (stderr.length > 4000) {
        stderr = stderr.slice(-4000);
      }
    });
    child.on('error', (error) => reject(new Error(`ffmpeg spawn failed: ${error.message}`)));
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`ffmpeg exited ${code}: ${stderr.slice(-500)}`));
      }
    });
  });
}

async function setStatus(episodeId: number, status: string): Promise<void> {
  await rows(sql`
    UPDATE episodes SET transcribe_status = ${status}, updated_at = now()
    WHERE id = ${episodeId}
  `);
}


async function markEpisode(episodeId: number, status: string, error: string | null): Promise<void> {
  await rows(sql`
    UPDATE episodes
    SET transcribe_status = ${status},
        transcribe_error = ${error},
        updated_at = now()
    WHERE id = ${episodeId}
  `);
}

