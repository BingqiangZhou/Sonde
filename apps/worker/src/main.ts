/** 声读 worker 进程：pg-boss 队列消费 + 定时调度。
 *  job 处理器与 cron 注册在 jobs/ 模块，main.ts 只负责装配。 */

import PgBoss from 'pg-boss';

import { closeDb, loadConfig } from '@sonde/backend';

import { QUEUES } from './queues.ts';
import { registerJobs, registerSchedules } from './jobs/index.ts';

const config = loadConfig();

const boss = new PgBoss({
  connectionString: config.databaseUrl,
});

async function main() {
  for (const [name, def] of Object.entries(QUEUES)) {
    await boss.createQueue(name, { name, ...def });
  }

  registerJobs(boss);
  await boss.start();
  await registerSchedules(boss);

  console.log(`[sonde-worker] started (concurrency=${config.workConcurrency})`);
}

const shutdown = async (signal: string) => {
  console.log(`[sonde-worker] ${signal} received, shutting down`);
  const timer = setTimeout(() => process.exit(1), 15_000);
  await boss.stop({ graceful: true, timeout: 10_000 }).catch(() => {});
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
