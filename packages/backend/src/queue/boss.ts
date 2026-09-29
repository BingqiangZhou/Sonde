/** 每进程一个 pg-boss 实例（api 只发送；worker 发送+消费+调度）。 */

import PgBoss from 'pg-boss';

import { loadConfig } from '../config.ts';
import { QUEUE_NAMES, QUEUES } from './queues.ts';

let instance: PgBoss | null = null;
let starting: Promise<PgBoss> | null = null;

export async function getBoss(): Promise<PgBoss> {
  if (instance) {
    return instance;
  }
  if (starting) {
    return starting;
  }
  starting = (async () => {
    const boss = new PgBoss({ connectionString: loadConfig().databaseUrl });
    await boss.start();
    for (const name of QUEUE_NAMES) {
      await boss.createQueue(name, { name, ...QUEUES[name] });
    }
    instance = boss;
    return boss;
  })();
  try {
    return await starting;
  } finally {
    starting = null;
  }
}

export async function sendJob(
  name: string,
  data: object,
  options?: { singletonKey?: string },
): Promise<string | null> {
  const boss = await getBoss();
  if (options?.singletonKey) {
    return boss.send(name, data, { singletonKey: options.singletonKey });
  }
  return boss.send(name, data);
}

export async function shutdownBoss(): Promise<void> {
  if (instance) {
    await instance.stop({ graceful: true, timeout: 10_000 }).catch(() => {});
    instance = null;
  }
}
