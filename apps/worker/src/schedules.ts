/** cron 注册（worker 独有）。全部处理器已就绪。 */

import type PgBoss from 'pg-boss';

import { loadConfig } from '@sonde/backend';

export async function registerSchedules(boss: PgBoss): Promise<void> {
  const config = loadConfig();

  // 每分钟扫描到期源
  await boss.schedule('sources.fetch', '* * * * *', {});
  // 每半小时兜底扫描：转写完成但丢失分析任务的单集
  await boss.schedule('episodes.analyze', '*/30 * * * *', { sweep: true });
  // 每天 08:00（站点时区，默认北京）成刊昨日日报；force 重新生成（修订+1）
  await boss.schedule('reports.daily', '0 8 * * *', {}, { tz: config.reportTimezone });
}
