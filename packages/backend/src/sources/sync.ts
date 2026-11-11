/** 订阅源同步：industry/sources.json 是订阅的唯一事实来源。
 *  - 列表内：按 lower(feedUrl) upsert（重列出的源重新激活并改名）
 *  - 列表外：置 is_active=false 停抓（不删行，历史单集保留）
 *  幂等：重复执行第二次 added=0、deactivated=0。 */

import { ValidationError } from '../errors.ts';
import { sql, withTx } from '../db/db.ts';

export interface SeedSourceEntry {
  name: string;
  feedUrl: string;
  intervalMinutes: number;
}

export interface SyncResult {
  added: number;
  updated: number;
  deactivated: number;
}

const DEFAULT_INTERVAL_MINUTES = 60;

/** 校验并归一化 sources.json 原始内容（坏条目直接抛错：配置错误应当响亮）。 */
export function normalizeSeedEntries(raw: unknown): SeedSourceEntry[] {
  if (!Array.isArray(raw)) {
    throw new ValidationError('industry/sources.json 必须是数组');
  }
  return raw.map((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new ValidationError(`sources.json 第 ${index} 项不是对象`);
    }
    const { name, feedUrl, intervalMinutes } = item as Record<string, unknown>;
    if (typeof name !== 'string' || !name.trim()) {
      throw new ValidationError(`sources.json 第 ${index} 项缺少 name`);
    }
    if (typeof feedUrl !== 'string' || !feedUrl.trim()) {
      throw new ValidationError(`sources.json 第 ${index} 项缺少 feedUrl`);
    }
    const interval =
      intervalMinutes === undefined
        ? DEFAULT_INTERVAL_MINUTES
        : typeof intervalMinutes === 'number' && Number.isInteger(intervalMinutes) && intervalMinutes > 0
          ? intervalMinutes
          : null;
    if (interval === null) {
      throw new ValidationError(`sources.json 第 ${index} 项 intervalMinutes 必须是正整数`);
    }
    return { name: name.trim(), feedUrl: feedUrl.trim(), intervalMinutes: interval };
  });
}

/** 单事务内完成全量同步（upsert × N + 停用列表外源）。 */
export async function syncSources(entries: SeedSourceEntry[]): Promise<SyncResult> {
  const urls = entries.map((entry) => entry.feedUrl.toLowerCase());

  return withTx(async (client) => {
    let added = 0;
    let updated = 0;
    for (const entry of entries) {
      const result = await client.query<{ inserted: boolean }>(sql`
        INSERT INTO sources (name, config, interval_minutes, is_active)
        VALUES (${entry.name}, jsonb_build_object('feedUrl', ${entry.feedUrl}), ${entry.intervalMinutes}, true)
        ON CONFLICT (lower(config->>'feedUrl')) WHERE config->>'feedUrl' IS NOT NULL
        DO UPDATE SET
          name = EXCLUDED.name,
          interval_minutes = EXCLUDED.interval_minutes,
          is_active = true,
          updated_at = now()
        RETURNING (xmax = 0) AS inserted
      `);
      if (result.rows[0]?.inserted) {
        added++;
      } else {
        updated++;
      }
    }

    const gone = await client.query<{ id: number }>(sql`
      UPDATE sources
      SET is_active = false, updated_at = now()
      WHERE is_active
        AND config->>'feedUrl' IS NOT NULL
        AND lower(config->>'feedUrl') <> ALL(${urls})
      RETURNING id
    `);

    return { added, updated, deactivated: gone.rowCount ?? 0 };
  });
}
