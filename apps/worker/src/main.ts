/** 声读 worker 进程：pg-boss 队列消费 + 定时调度。
 *  main.ts 只负责装配；job 处理器在 jobs/，cron 在 schedules.ts。 */

import { closeDb, getBoss, loadConfig } from '@sonde/backend';

import { registerJobs } from './jobs/index.ts';
import { registerSchedules } from './schedules.ts';

const config = loadConfig();

async function main() {
  const boss = await getBoss();
  registerJobs(boss);
  await registerSchedules(boss);
  console.log(`[sonde-worker] started (concurrency=${config.workConcurrency})`);
}

const shutdown = async (signal: string) => {
  console.log(`[sonde-worker] ${signal} received, shutting down`);
  const timer = setTimeout(() => process.exit(1), 15_000);
  const { shutdownBoss } = await import('@sonde/backend');
  await shutdownBoss();
  await closeDb();
  clearTimeout(timer);
  process.exit(0);
};

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

main().catch((error) => {
  console.error('[sonde-worker] failed to start:', error);
  process.exit(1);
});
