/** cron 注册（worker 独有；processor 就绪一个注册一个，避免无消费者时积压）。 */

import type PgBoss from 'pg-boss';

export async function registerSchedules(boss: PgBoss): Promise<void> {
  // 每分钟扫描到期源（fetch 处理器已就绪）
  await boss.schedule('sources.fetch', '* * * * *', {});
  // reports.daily 的 cron（08:00 成刊 + 每小时补发）在分析/成刊阶段开启
}
