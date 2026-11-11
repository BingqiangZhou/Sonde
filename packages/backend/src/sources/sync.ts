/** 订阅源同步：库内订阅全部来自 xyzrank 榜单自动同步（手工订阅 sources.json 已废弃删除）。
 *  - 榜单内：按 lower(feedUrl) upsert（掉榜再回榜的源重新激活并改名）
 *  - 榜单外：置 is_active=false 停抓（不删行，历史单集保留）
 *  - 空榜单防线：entries 为空一律拒绝（上游 API 异常返回空列表时，
 *    绝不能把全量订阅停用——宁可这次同步失败）。
 *  新增其他订阅来源时需重新引入来源隔离逻辑。
 *  幂等：重复执行第二次 added=0、deactivated=0。
 *  由 worker 每日 cron 与启动触发调用。 */

import { ValidationError } from '../errors.ts';
import { sql, withTx } from '../db/db.ts';

export interface SourceEntry {
  name: string;
  feedUrl: string;
  intervalMinutes: number;
  /** 一级分类(xyzrank 经 GENRE_ROLLUP 归并)。缺省 = 无分类(前端「其他」)。 */
  category?: string | null;
}

export interface SyncResult {
  added: number;
  updated: number;
  deactivated: number;
}

/** xyzrank 榜单同步：单事务内完成 upsert × N + 停用掉榜源。 */
export async function syncXyzrankSources(entries: SourceEntry[]): Promise<SyncResult> {
  if (entries.length === 0) {
    throw new ValidationError('xyzrank 榜单为空,跳过同步以免清空订阅(上游 API 异常?)');
  }
  const urls = entries.map((entry) => entry.feedUrl.toLowerCase());

  return withTx(async (client) => {
    let added = 0;
    let updated = 0;
    for (const entry of entries) {
      const result = await client.query<{ inserted: boolean }>(sql`
        INSERT INTO sources (name, config, interval_minutes, is_active, category)
        VALUES (${entry.name}, jsonb_build_object('feedUrl', ${entry.feedUrl}::text, 'origin', 'xyzrank'), ${entry.intervalMinutes}, true, ${entry.category ?? null})
        ON CONFLICT (lower(config->>'feedUrl')) WHERE config->>'feedUrl' IS NOT NULL
        DO UPDATE SET
          name = EXCLUDED.name,
          interval_minutes = EXCLUDED.interval_minutes,
          is_active = true,
          category = EXCLUDED.category,
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
        AND lower(config->>'feedUrl') <> ALL(${urls}::text[])
      RETURNING id
    `);

    return { added, updated, deactivated: gone.rowCount ?? 0 };
  });
}
