/** job 处理器与 cron 注册表（后续阶段逐个填充实现）。 */

import type PgBoss from 'pg-boss';

export function registerJobs(boss: PgBoss): void {
  // 阶段 4/5 填充：
  //   boss.work('sources.fetch', handler)
  //   boss.work('episodes.transcribe', handler)
  //   boss.work('episodes.analyze', handler)
  //   boss.work('reports.daily', handler)
  void boss;
}

export async function registerSchedules(boss: PgBoss): Promise<void> {
  // 阶段 4/5 填充（注：先有处理器再注册 cron，避免积压）：
  //   await boss.schedule('sources.fetch', '* * * * *')
  //   await boss.schedule('reports.daily', '0 8 * * *', {}, { tz: config.reportTimezone })
  //   await boss.schedule('reports.daily', '15 * * * *')   // 每小时补发
  void boss;
}
