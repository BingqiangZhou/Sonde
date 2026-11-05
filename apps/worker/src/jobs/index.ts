/** job 处理器注册（worker 进程装配点）。
 *  pg-boss v10 无 teamSize——并发 = 注册 N 个 worker；await 注册让失败能冒泡到 main 的 catch。 */

import type PgBoss from 'pg-boss';

import {
  analyzeEpisode,
  fetchSource,
  generateReport,
  loadConfig,
  scanDueSources,
  sweepPendingAnalyses,
  transcribeEpisode,
} from '@sonde/backend';

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

const transcribeHandler = async (jobs: Job): Promise<void> => {
  for (const job of jobs) {
    await transcribeEpisode((job.data as { episodeId: number }).episodeId);
  }
};

const analyzeHandler = async (jobs: Job): Promise<void> => {
  for (const job of jobs) {
    const data = job.data as { episodeId?: number; sweep?: boolean };
    if (data?.sweep) {
      await sweepPendingAnalyses();
    } else if (data?.episodeId) {
      await analyzeEpisode(data.episodeId);
    }
  }
};

function reportHandler(kind: 'daily' | 'weekly' | 'monthly') {
  return async (jobs: Job): Promise<void> => {
    for (const job of jobs) {
      const data = job.data as { reportKey?: string; force?: boolean };
      // 缺省 force=true 保持 cron 覆盖语义（schedules.ts 显式传 true）；catch-up 场景可显式传 false
      await generateReport(kind, { reportKey: data?.reportKey, force: data.force ?? true });
    }
  };
}

export async function registerJobs(boss: PgBoss): Promise<void> {
  // WORK_CONCURRENCY 真正生效：transcribe/analyze 各注册 N 个 worker。
  // 上限 4：pg pool max=10，需给 sources.fetch / reports / 队列轮询留连接余量。
  const concurrency = Math.min(Math.max(1, loadConfig().workConcurrency), 4);

  await boss.work('sources.fetch', { batchSize: 1 }, sourcesFetchHandler);
  for (let i = 0; i < concurrency; i++) {
    await boss.work('episodes.transcribe', { batchSize: 1 }, transcribeHandler);
    await boss.work('episodes.analyze', { batchSize: 1 }, analyzeHandler);
  }
  await boss.work('reports.daily', { batchSize: 1 }, reportHandler('daily'));
  await boss.work('reports.weekly', { batchSize: 1 }, reportHandler('weekly'));
  await boss.work('reports.monthly', { batchSize: 1 }, reportHandler('monthly'));

  console.log(`[sonde-worker] registered jobs (transcribe/analyze concurrency=${concurrency})`);
}
