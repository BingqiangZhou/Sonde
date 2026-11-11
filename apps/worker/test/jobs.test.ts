import { beforeEach, describe, expect, it, vi } from 'vitest';

/** worker 装配逻辑单测：假 boss 捕获 work()/schedule() 注册，无需 DB。 */
const fetchSource = vi.fn();
const scanDueSources = vi.fn();

vi.mock('@sonde/backend', () => ({
  fetchSource: (...a: unknown[]) => fetchSource(...(a as [])),
  scanDueSources: (...a: unknown[]) => scanDueSources(...(a as [])),
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
  const scheduled: { name: string; cron: string; data: unknown }[] = [];
  const unscheduled: string[] = [];
  const deletedQueues: string[] = [];
  return {
    registrations,
    scheduled,
    unscheduled,
    deletedQueues,
    work: vi.fn(async (name: string, options: Registration['options'], handler: Registration['handler']) => {
      registrations.push({ name, options, handler });
    }),
    schedule: vi.fn(async (name: string, cron: string, data: unknown) => {
      scheduled.push({ name, cron, data });
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
});

describe('registerJobs 装配', () => {
  it('只注册一个 sources.fetch worker（AI 管道已移除）', async () => {
    const boss = makeBoss();
    await registerJobs(boss as never);
    expect(boss.registrations).toHaveLength(1);
    expect(boss.registrations[0]?.name).toBe('sources.fetch');
  });

  it('sources.fetch：有 sourceId 抓单源，无则扫描', async () => {
    const boss = makeBoss();
    await registerJobs(boss as never);
    const handler = boss.registrations[0]?.handler;
    if (!handler) throw new Error('sources.fetch handler 未注册');

    await handler([{ data: { sourceId: 5 } }]);
    expect(fetchSource).toHaveBeenCalledWith(5);

    await handler([{ data: {} }]);
    expect(scanDueSources).toHaveBeenCalled();
  });
});

describe('registerSchedules 调度', () => {
  it('只保留每分钟一次的 sources.fetch 扫描 cron', async () => {
    const boss = makeBoss();
    await registerSchedules(boss as never);
    expect(boss.scheduled).toEqual([{ name: 'sources.fetch', cron: '* * * * *', data: {} }]);
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
    expect(boss.scheduled).toHaveLength(1);
  });
});
