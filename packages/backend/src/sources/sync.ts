/** 订阅源同步：industry/sources.json 是手工订阅的唯一事实来源。
 *  - 列表内：按 lower(feedUrl) upsert（重列出的源重新激活并改名）
 *  - 列表外：置 is_active=false 停抓（不删行，历史单集保留）
 *  - 只管无 origin 的手工源;origin=xyzrank 等自动同步的源归各自的同步器管,
 *    空 sources.json 的 seed 不会误伤它们(docker compose 每次起栈都会跑 seed)
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
        VALUES (${entry.name}, jsonb_build_object('feedUrl', ${entry.feedUrl}::text), ${entry.intervalMinutes}, true)
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
        AND coalesce(config->>'origin', '') = ''
        AND lower(config->>'feedUrl') <> ALL(${urls}::text[])
      RETURNING id
    `);

    return { added, updated, deactivated: gone.rowCount ?? 0 };
  });
}

export interface XyzrankSyncResult extends SyncResult {
  /** 已存在的同 feed 是手工订阅(origin 不是 xyzrank)、被保护跳过的条数 */
  keptManual: number;
}

/** xyzrank 榜单同步(origin 隔离版):与 syncSources 的区别 ——
 *  - config 写入 origin='xyzrank',upsert 的 DO UPDATE 带 WHERE origin='xyzrank':
 *    已是手工订阅的 feed 不被改名/改间隔/重新激活;
 *  - 停用只针对自家(origin=xyzrank)且不在当前榜单的源,手工订阅永不触碰。
 *  空榜单防线:entries 为空一律拒绝(上游 API 异常返回空列表时,
 *  绝不能把自家订阅全量停用——宁可这次同步失败)。
 *  由 worker 每日 cron 调用;幂等。 */
export async function syncXyzrankSources(entries: SeedSourceEntry[]): Promise<XyzrankSyncResult> {
  if (entries.length === 0) {
    throw new ValidationError('xyzrank 榜单为空,跳过同步以免清空订阅(上游 API 异常?)');
  }
  const urls = entries.map((entry) => entry.feedUrl.toLowerCase());

  return withTx(async (client) => {
    let added = 0;
    let updated = 0;
    let keptManual = 0;
    for (const entry of entries) {
      const result = await client.query<{ inserted: boolean }>(sql`
        INSERT INTO sources (name, config, interval_minutes, is_active)
        VALUES (${entry.name}, jsonb_build_object('feedUrl', ${entry.feedUrl}::text, 'origin', 'xyzrank'), ${entry.intervalMinutes}, true)
        ON CONFLICT (lower(config->>'feedUrl')) WHERE config->>'feedUrl' IS NOT NULL
        DO UPDATE SET
          name = EXCLUDED.name,
          interval_minutes = EXCLUDED.interval_minutes,
          is_active = true,
          updated_at = now()
        WHERE sources.config->>'origin' = 'xyzrank'
        RETURNING (xmax = 0) AS inserted
      `);
      if (result.rows.length === 0) {
        keptManual++;
      } else if (result.rows[0]?.inserted) {
        added++;
      } else {
        updated++;
      }
    }

    const gone = await client.query<{ id: number }>(sql`
      UPDATE sources
      SET is_active = false, updated_at = now()
      WHERE is_active
        AND config->>'origin' = 'xyzrank'
        AND lower(config->>'feedUrl') <> ALL(${urls}::text[])
      RETURNING id
    `);

    return { added, updated, keptManual, deactivated: gone.rowCount ?? 0 };
  });
}
