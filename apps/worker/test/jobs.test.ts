import { beforeEach, describe, expect, it, vi } from 'vitest';

/** worker 装配逻辑单测：假 boss 捕获 work()/schedule()/send() 注册，无需 DB。 */
const fetchSource = vi.fn();
const scanDueSources = vi.fn();
const fetchXyzrankTopPodcasts = vi.fn();
const syncXyzrankSources = vi.fn();

vi.mock('@sonde/backend', () => ({
  fetchSource: (...a: unknown[]) => fetchSource(...(a as [])),
  scanDueSources: (...a: unknown[]) => scanDueSources(...(a as [])),
  fetchXyzrankTopPodcasts: (...a: unknown[]) => fetchXyzrankTopPodcasts(...(a as [])),
  syncXyzrankSources: (...a: unknown[]) => syncXyzrankSources(...(a as [])),
  ValidationError: class ValidationError extends Error {},
}));

const { registerJobs } = await import('../src/jobs/index.ts');
const { registerSchedules, REMOVED_QUEUES } = await import('../src/schedules.ts');

interface Registration {
  name: string;
  options: { batchSize?: number };
  handler: (jobs: { data: unknown }[]) => Promise<void>;
}

function makeBoss() {
  const registrations: Registration[] = [];
  const scheduled: { name: string; cron: string; data: unknown; options?: unknown }[] = [];
  const sent: { name: string; data: unknown; options?: unknown }[] = [];
  const unscheduled: string[] = [];
  const deletedQueues: string[] = [];
  return {
    registrations,
    scheduled,
    sent,
    unscheduled,
    deletedQueues,
    work: vi.fn(async (name: string, options: Registration['options'], handler: Registration['handler']) => {
      registrations.push({ name, options, handler });
    }),
    schedule: vi.fn(async (name: string, cron: string, data: unknown, options?: unknown) => {
      scheduled.push({ name, cron, data, options });
    }),
    send: vi.fn(async (name: string, data: unknown, options?: unknown) => {
      sent.push({ name, data, options });
    }),
    unschedule: vi.fn(async (name: string) => {
      unscheduled.push(name);
    }),
    deleteQueue: vi.fn(async (name: string) => {
      deletedQueues.push(name);
    }),
  };
}

beforeEach(() => {
  fetchSource.mockReset().mockResolvedValue(undefined);
  scanDueSources.mockReset().mockResolvedValue(undefined);
  fetchXyzrankTopPodcasts.mockReset().mockResolvedValue({ entries: [], skipped: 0 });
  syncXyzrankSources.mockReset().mockResolvedValue({ added: 0, updated: 0, deactivated: 0 });
});

describe('registerJobs 装配', () => {
  it('注册 8 个并发 sources.fetch worker + 1 个 sources.sync-xyzrank worker（AI 管道已移除）', async () => {
    const boss = makeBoss();
    await registerJobs(boss as never);
    const fetchWorkers = boss.registrations.filter((r) => r.name === 'sources.fetch');
    const syncWorkers = boss.registrations.filter((r) => r.name === 'sources.sync-xyzrank');
    expect(fetchWorkers).toHaveLength(8);
    expect(syncWorkers).toHaveLength(1);
    expect(boss.registrations).toHaveLength(9); // 8 + 1,别无其他队列
    for (const r of boss.registrations) {
      expect(r.options).toEqual({ batchSize: 1 });
    }
  });

  it('sources.fetch：有 sourceId 抓单源，无则扫描', async () => {
    const boss = makeBoss();
    await registerJobs(boss as never);
    const handler = boss.registrations.find((r) => r.name === 'sources.fetch')?.handler;
    if (!handler) throw new Error('sources.fetch handler 未注册');

    await handler([{ data: { sourceId: 5 } }]);
    expect(fetchSource).toHaveBeenCalledWith(5);

    await handler([{ data: {} }]);
    expect(scanDueSources).toHaveBeenCalled();
  });
});

describe('registerSchedules 调度', () => {
  it('保留每分钟 sources.fetch 扫描 + 每日 04:00（北京）xyzrank 同步两个 cron', async () => {
    const boss = makeBoss();
    await registerSchedules(boss as never);
    expect(boss.scheduled).toEqual([
      { name: 'sources.fetch', cron: '* * * * *', data: {}, options: undefined },
      { name: 'sources.sync-xyzrank', cron: '0 4 * * *', data: {}, options: { tz: 'Asia/Shanghai' } },
    ]);
  });

  it('启动即触发一次 xyzrank 同步（singletonKey 防堆叠，空库首启不等凌晨四点）', async () => {
    const boss = makeBoss();
    await registerSchedules(boss as never);
    expect(boss.sent).toEqual([
      { name: 'sources.sync-xyzrank', data: {}, options: { singletonKey: 'xyzrank-sync' } },
    ]);
  });

  it('一次性清理 5 个已删队列的遗留 cron 计划与队列本体（pg-boss 计划持久化在库里）', async () => {
    const boss = makeBoss();
    await registerSchedules(boss as never);
    expect(boss.unscheduled).toEqual([
      'episodes.transcribe',
      'episodes.analyze',
      'reports.daily',
      'reports.weekly',
      'reports.monthly',
    ]);
    expect(boss.deletedQueues).toEqual(boss.unscheduled);
    expect(REMOVED_QUEUES).toHaveLength(5);
  });

  it('清理失败（计划本就不存在）不得中断启动', async () => {
    const boss = makeBoss();
    boss.unschedule.mockRejectedValue(new Error('schedule not found'));
    await expect(registerSchedules(boss as never)).resolves.toBeUndefined();
    expect(boss.scheduled).toHaveLength(2);
  });

  it('启动触发 send 失败也不得中断启动（记日志继续跑 cron）', async () => {
    const boss = makeBoss();
    boss.send.mockRejectedValue(new Error('boss unavailable'));
    await expect(registerSchedules(boss as never)).resolves.toBeUndefined();
    expect(boss.scheduled).toHaveLength(2);
    expect(boss.unscheduled).toHaveLength(5);
  });
});
