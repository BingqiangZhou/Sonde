/** receipts：所有付费调用（LLM / 转写）的成本台账。写入永不抛错（记账失败只打日志）。 */

import { rows, sql } from '../db/db.ts';

export interface ReceiptInput {
  service: 'llm' | 'transcription';
  operation: string;
  model?: string | null;
  inputTokens?: number | null;
  outputTokens?: number | null;
  audioSeconds?: number | null;
  ok: boolean;
  error?: string | null;
  durationMs?: number | null;
}

export async function recordReceipt(input: ReceiptInput): Promise<void> {
  try {
    await rows(sql`
      INSERT INTO receipts
        (service, operation, model, input_tokens, output_tokens, audio_seconds, ok, error, duration_ms)
      VALUES
        (${input.service}, ${input.operation}, ${input.model ?? null},
         ${input.inputTokens ?? null}, ${input.outputTokens ?? null}, ${input.audioSeconds ?? null},
         ${input.ok}, ${input.error ? String(input.error).slice(0, 500) : null}, ${input.durationMs ?? null})
    `);
  } catch (error) {
    console.warn('[receipts] failed to record:', error instanceof Error ? error.message : error);
  }
}

export interface ReceiptSummary {
  service: string;
  calls: number;
  failures: number;
  inputTokens: number;
  outputTokens: number;
  audioSeconds: number;
}

export async function receiptsSummary(days = 30): Promise<ReceiptSummary[]> {
  return rows<ReceiptSummary>(sql`
    SELECT service,
           count(*)::int AS calls,
           count(*) FILTER (WHERE NOT ok)::int AS failures,
           coalesce(sum(input_tokens), 0)::int AS "inputTokens",
           coalesce(sum(output_tokens), 0)::int AS "outputTokens",
           coalesce(sum(audio_seconds), 0)::int AS "audioSeconds"
    FROM receipts
    WHERE created_at > now() - (${days} || ' days')::interval
    GROUP BY service
    ORDER BY service
  `);
}
