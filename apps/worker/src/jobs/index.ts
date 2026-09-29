/** job 处理器注册（worker 进程装配点）。 */

import type PgBoss from 'pg-boss';

import { fetchSource, scanDueSources, transcribeEpisode } from '@sonde/backend';

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

  // episodes.analyze / reports.daily 在后续阶段注册
}
