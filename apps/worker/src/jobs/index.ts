/** job 处理器注册（worker 进程装配点）。
 *  pg-boss v10 无 teamSize——并发 = 注册 N 个 worker；await 注册让失败能冒泡到 main 的 catch。 */

import type PgBoss from 'pg-boss';

import {
  ValidationError,
  fetchSource,
  fetchXyzrankTopPodcasts,
  scanDueSources,
  syncXyzrankSources,
} from '@sonde/backend';

type Job = { data: unknown }[];

/** sources.fetch:并发 worker 数。
 *  1000 源 × 10 分钟间隔 ≈ 100 抓/分钟,恰好顶到每分钟扫描上限;串行会被慢 feed(60s 超时)
 *  拖垮整个队列,8 并发 + 绝大多数 304 快返回即可稳定跟上。 */
const FETCH_WORKERS = 8;

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

const sourcesSyncXyzrankHandler = async (jobs: Job): Promise<void> => {
  for (const job of jobs) {
    void job;
    const { entries, skipped } = await fetchXyzrankTopPodcasts();
    if (entries.length === 0) {
      // 空榜单按告警处理而不是失败:syncXyzrankSources 也会拒绝,这里先温和拦下
      console.warn('[sonde-worker] xyzrank 榜单拉取结果为空,跳过本次同步(订阅保持原状)');
      continue;
    }
    try {
      const result = await syncXyzrankSources(entries);
      console.log(
        `[sonde-worker] xyzrank 同步完成: 榜单 ${entries.length} 个(跳过 ${skipped}),` +
          `新增 ${result.added},更新 ${result.updated},停用 ${result.deactivated}`,
      );
    } catch (error) {
      if (error instanceof ValidationError) {
        console.warn(`[sonde-worker] xyzrank 同步被防线拦下: ${error.message}`);
        continue;
      }
      throw error;
    }
  }
};

export async function registerJobs(boss: PgBoss): Promise<void> {
  for (let i = 0; i < FETCH_WORKERS; i++) {
    await boss.work('sources.fetch', { batchSize: 1 }, sourcesFetchHandler);
  }
  await boss.work('sources.sync-xyzrank', { batchSize: 1 }, sourcesSyncXyzrankHandler);
  console.log(`[sonde-worker] registered jobs (sources.fetch ×${FETCH_WORKERS}, sources.sync-xyzrank)`);
}
