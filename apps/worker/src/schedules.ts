/** cron 注册（worker 独有）。 */

import type PgBoss from 'pg-boss';

/** 已删除的 AI 管道队列：pg-boss 的 cron 计划持久化在数据库里，
 *  只删代码不清理计划，5 个死 cron 会永远往无人消费的队列塞任务。 */
export const REMOVED_QUEUES = [
  'episodes.transcribe',
  'episodes.analyze',
  'reports.daily',
  'reports.weekly',
  'reports.monthly',
] as const;

export async function registerSchedules(boss: PgBoss): Promise<void> {
  // 每分钟扫描到期源并逐源派发 sources.fetch（每源一个 job，singletonKey 去重）
  await boss.schedule('sources.fetch', '* * * * *', {});

  // 每日 04:00（北京）同步 xyzrank 播客榜前 1000：进榜新增、掉榜停用（origin=xyzrank 隔离，手工订阅不受影响）
  await boss.schedule('sources.sync-xyzrank', '0 4 * * *', {}, { tz: 'Asia/Shanghai' });

  // 启动即触发一次同步（幂等；singletonKey 防堆叠）——空库首启不用等到凌晨四点
  await boss.send('sources.sync-xyzrank', {}, { singletonKey: 'xyzrank-sync' }).catch((error) => {
    console.error('[sonde-worker] xyzrank 同步触发失败:', error instanceof Error ? error.message : error);
  });

  // 一次性清理遗留计划与队列（连同在途孤儿任务一起丢弃）；计划本就不存在时静默通过
  for (const name of REMOVED_QUEUES) {
    await boss.unschedule(name).catch(() => {});
    await boss.deleteQueue(name).catch(() => {});
  }
}
