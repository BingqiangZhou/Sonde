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
    // 无监听的 error 事件会直接抛出（EventEmitter 语义）——DB 瞬断不能击穿进程
    boss.on('error', (error) => console.error('[pg-boss] error:', error));
    await boss.start();
    for (const name of QUEUE_NAMES) {
      // createQueue 对已存在队列是 no-op（ON CONFLICT DO NOTHING + 早返回），
      // 策略/expire 变更必须经 updateQueue 才能落到存量部署
      await boss.createQueue(name, { name, ...QUEUES[name] });
      await boss.updateQueue(name, { name, ...QUEUES[name] });
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
