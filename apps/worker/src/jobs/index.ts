/** job 处理器注册（worker 进程装配点）。 */

import type PgBoss from 'pg-boss';

import {
  analyzeEpisode,
  fetchSource,
  generateReport,
  scanDueSources,
  sweepPendingAnalyses,
  transcribeEpisode,
} from '@sonde/backend';

export function registerJobs(boss: PgBoss): void {
  void boss.work('sources.fetch', { batchSize: 1 }, async (jobs) => {
    for (const job of jobs) {
      const data = job.data as { sourceId?: number };
      if (data?.sourceId) {
        await fetchSource(data.sourceId);
      } else {
        await scanDueSources();
      }
    }
  });

  void boss.work('episodes.transcribe', { batchSize: 1 }, async (jobs) => {
    for (const job of jobs) {
      await transcribeEpisode((job.data as { episodeId: number }).episodeId);
    }
  });

  void boss.work('episodes.analyze', { batchSize: 2 }, async (jobs) => {
    for (const job of jobs) {
      const data = job.data as { episodeId?: number; sweep?: boolean };
      if (data?.sweep) {
        await sweepPendingAnalyses();
      } else if (data?.episodeId) {
        await analyzeEpisode(data.episodeId);
      }
    }
  });

  void boss.work('reports.daily', { batchSize: 1 }, async (jobs) => {
    for (const job of jobs) {
      const data = job.data as { reportKey?: string };
      await generateReport('daily', { reportKey: data?.reportKey, force: true });
    }
  });

  void boss.work('reports.weekly', { batchSize: 1 }, async (jobs) => {
    for (const job of jobs) {
      const data = job.data as { reportKey?: string };
      await generateReport('weekly', { reportKey: data?.reportKey, force: true });
    }
  });

  void boss.work('reports.monthly', { batchSize: 1 }, async (jobs) => {
    for (const job of jobs) {
      const data = job.data as { reportKey?: string };
      await generateReport('monthly', { reportKey: data?.reportKey, force: true });
    }
  });
}
