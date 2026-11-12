/** 间隔自适应(aihot adaptIntervals 的播客版,每日 04:10 + 启动各跑一次)。
 *  per_day = 近 7 天单集(published_at)计数 / 7 —— 按发布时间而非入库时间:
 *  首导截断 10 条/14 天,7 天窗口内带回的条目本就是真实近期产出,无需回灌标记。
 *  target = per_day ≤ 0.15 ? 720 : round(clip(1440/(per_day×3), 30, 720))
 *  —— 期望「平均每 3 次抓取撞到 1 条新单集」;播客密度下公式自然收敛:
 *  周更→720,日更→480,下限 30。仅写 is_active 且有变化的行(幂等)。 */

import { rows, sql } from '../db/db.ts';

export async function adaptSourceIntervals(): Promise<{ updated: number }> {
  const updated = await rows<{ id: number }>(sql`
    WITH target AS (
      SELECT s.id,
             GREATEST(30, LEAST(720,
               CASE WHEN COALESCE(p.per_day, 0) <= 0.15 THEN 720
                    ELSE ROUND(1440.0 / (p.per_day * 3))::int
               END)) AS interval_minutes
      FROM sources s
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::float / 7.0 AS per_day
        FROM episodes e
        WHERE e.source_id = s.id AND e.published_at > now() - interval '7 days'
      ) p ON true
      WHERE s.is_active
    )
    UPDATE sources s
    SET interval_minutes = t.interval_minutes, updated_at = now()
    FROM target t
    WHERE s.id = t.id AND s.interval_minutes <> t.interval_minutes
    RETURNING s.id
  `);
  return { updated: updated.length };
}
