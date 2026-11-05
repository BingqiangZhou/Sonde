import { beforeEach, describe, expect, it, vi } from 'vitest';

/** worker 装配逻辑单测：假 boss 捕获 work() 注册，无需 DB。 */
const analyzeEpisode = vi.fn();
const fetchSource = vi.fn();
const generateReport = vi.fn();
const scanDueSources = vi.fn();
const sweepPendingAnalyses = vi.fn();
const transcribeEpisode = vi.fn();
const loadConfig = vi.fn(() => ({ workConcurrency: 2 }));

vi.mock('@sonde/backend', () => ({
  analyzeEpisode: (...a: unknown[]) => analyzeEpisode(...(a as [])),
  fetchSource: (...a: unknown[]) => fetchSource(...(a as [])),
  generateReport: (...a: unknown[]) => generateReport(...(a as [])),
  scanDueSources: (...a: unknown[]) => scanDueSources(...(a as [])),
  sweepPendingAnalyses: (...a: unknown[]) => sweepPendingAnalyses(...(a as [])),
  transcribeEpisode: (...a: unknown[]) => transcribeEpisode(...(a as [])),
  loadConfig: () => loadConfig(),
}));

const { registerJobs } = await import('../src/jobs/index.ts');

interface Registration {
  name: string;
  options: { batchSize?: number };
  handler: (jobs: { data: unknown }[]) => Promise<void>;
}

function makeBoss() {
  const registrations: Registration[] = [];
  return {
    registrations,
    work: vi.fn(async (name: string, options: Registration['options'], handler: Registration['handler']) => {
      registrations.push({ name, options, handler });
    }),
  };
}

function byName(regs: Registration[], name: string): Registration[] {
  return regs.filter((r) => r.name === name);
}

beforeEach(() => {
  analyzeEpisode.mockReset().mockResolvedValue(undefined);
  fetchSource.mockReset().mockResolvedValue(undefined);
  generateReport.mockReset().mockResolvedValue(undefined);
  scanDueSources.mockReset().mockResolvedValue(undefined);
  sweepPendingAnalyses.mockReset().mockResolvedValue(undefined);
  transcribeEpisode.mockReset().mockResolvedValue(undefined);
});

describe('registerJobs 并发装配', () => {
  it('WORK_CONCURRENCY=N：transcribe/analyze 各注册 N 个 worker，sources/reports 单 worker', async () => {
    loadConfig.mockReturnValue({ workConcurrency: 3 });
    const boss = makeBoss();

    await registerJobs(boss as never);

    expect(byName(boss.registrations, 'episodes.transcribe')).toHaveLength(3);
    expect(byName(boss.registrations, 'episodes.analyze')).toHaveLength(3);
    expect(byName(boss.registrations, 'sources.fetch')).toHaveLength(1);
    expect(byName(boss.registrations, 'reports.daily')).toHaveLength(1);
    expect(byName(boss.registrations, 'reports.weekly')).toHaveLength(1);
    expect(byName(boss.registrations, 'reports.monthly')).toHaveLength(1);
  });

  it('WORK_CONCURRENCY 收敛到 [1,4]（pg pool max=10 留余量）', async () => {
    loadConfig.mockReturnValue({ workConcurrency: 99 });
    const boss = makeBoss();
    await registerJobs(boss as never);
    expect(byName(boss.registrations, 'episodes.transcribe')).toHaveLength(4);

    loadConfig.mockReturnValue({ workConcurrency: 0 });
    const boss2 = makeBoss();
    await registerJobs(boss2 as never);
    expect(byName(boss2.registrations, 'episodes.transcribe')).toHaveLength(1);
  });
});

describe('worker 处理器委派', () => {
  it('sources.fetch：有 sourceId 抓单源，无则扫描', async () => {
    loadConfig.mockReturnValue({ workConcurrency: 1 });
    const boss = makeBoss();
    await registerJobs(boss as never);
    const handler = byName(boss.registrations, 'sources.fetch')[0]?.handler;
    if (!handler) throw new Error('sources.fetch handler 未注册');

    await handler([{ data: { sourceId: 5 } }]);
    expect(fetchSource).toHaveBeenCalledWith(5);

    await handler([{ data: {} }]);
    expect(scanDueSources).toHaveBeenCalled();
  });

  it('episodes.transcribe → transcribeEpisode；analyze 分 sweep/单集两路', async () => {
    loadConfig.mockReturnValue({ workConcurrency: 1 });
    const boss = makeBoss();
    await registerJobs(boss as never);

    const transcribe = byName(boss.registrations, 'episodes.transcribe')[0]?.handler;
    if (!transcribe) throw new Error('episodes.transcribe handler 未注册');
    await transcribe([{ data: { episodeId: 9 } }]);
    expect(transcribeEpisode).toHaveBeenCalledWith(9);

    const analyze = byName(boss.registrations, 'episodes.analyze')[0]?.handler;
    if (!analyze) throw new Error('episodes.analyze handler 未注册');
    await analyze([{ data: { sweep: true } }]);
    expect(sweepPendingAnalyses).toHaveBeenCalled();
    await analyze([{ data: { episodeId: 12 } }]);
    expect(analyzeEpisode).toHaveBeenCalledWith(12);
  });

  it('reports.*：按 kind 委派 generateReport', async () => {
    loadConfig.mockReturnValue({ workConcurrency: 1 });
    const boss = makeBoss();
    await registerJobs(boss as never);

    const daily = byName(boss.registrations, 'reports.daily')[0]?.handler;
    if (!daily) throw new Error('reports.daily handler 未注册');
    await daily([{ data: { reportKey: '2026-11-04' } }]);
    expect(generateReport).toHaveBeenCalledWith('daily', { reportKey: '2026-11-04', force: true });

    const weekly = byName(boss.registrations, 'reports.weekly')[0]?.handler;
    if (!weekly) throw new Error('reports.weekly handler 未注册');
    await weekly([{ data: {} }]);
    expect(generateReport).toHaveBeenCalledWith('weekly', { reportKey: undefined, force: true });

    const monthly = byName(boss.registrations, 'reports.monthly')[0]?.handler;
    if (!monthly) throw new Error('reports.monthly handler 未注册');
    await monthly([{ data: {} }]);
    expect(generateReport).toHaveBeenCalledWith('monthly', { reportKey: undefined, force: true });
  });
});
