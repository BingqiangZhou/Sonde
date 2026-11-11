/** job 处理器注册（worker 进程装配点）。
 *  pg-boss v10 无 teamSize——并发 = 注册 N 个 worker；await 注册让失败能冒泡到 main 的 catch。 */

import type PgBoss from 'pg-boss';

import { fetchSource, scanDueSources } from '@sonde/backend';

type Job = { data: unknown }[];

const sourcesFetchHandler = async (jobs: Job): Promise<void> => {
  for (const job of jobs) {
    const data = job.data as { sourceId?: number };
    if (data?.sourceId) {
      await fetchSource(data.sourceId);
    } else {
      await scanDueSources();
    }
  }
};

export async function registerJobs(boss: PgBoss): Promise<void> {
  // 单 worker 足够：cron 每分钟重派 + singletonKey `src:<id>` 去重，单源任务本身很轻。
  await boss.work('sources.fetch', { batchSize: 1 }, sourcesFetchHandler);
  console.log('[sonde-worker] registered jobs (sources.fetch)');
}
