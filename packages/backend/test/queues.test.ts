import { describe, expect, it } from 'vitest';

import { QUEUES } from '../src/queue/queues.ts';

/** 管线队列的策略/超时契约（见加固方案 6.0/6.2 Step 2）：
 *  - stately 策略让 singletonKey 真正去重（standard 策略下是空操作）
 *  - expire 必须覆盖最坏执行时长，否则 handler 仍在跑就被判过期重试 */
describe('QUEUES 管线队列策略', () => {
  it('sources.fetch：stately 策略 + 派发器语义（单源任务，cron 每分钟重派）', () => {
    const q = QUEUES['sources.fetch'];
    expect(q.policy).toBe('stately');
    expect(q.expireInSeconds).toBe(600);
    expect(q.retryLimit).toBe(1);
  });

  it('episodes.transcribe：stately + expire ≥ 28800s（下载 30min + ~12 块 × 3 次 × 600s ≈ 6.5h）', () => {
    const q = QUEUES['episodes.transcribe'];
    expect(q.policy).toBe('stately');
    expect(q.expireInSeconds ?? 0).toBeGreaterThanOrEqual(28800);
  });

  it('episodes.analyze：stately + expire ≥ 1800s（2 次 LLM 调用最坏 18+ 分钟）', () => {
    const q = QUEUES['episodes.analyze'];
    expect(q.policy).toBe('stately');
    expect(q.expireInSeconds ?? 0).toBeGreaterThanOrEqual(1800);
  });

  it('reports.*：保持原状（并发由生成函数内的咨询锁串行化）', () => {
    for (const name of ['reports.daily', 'reports.weekly', 'reports.monthly'] as const) {
      expect(QUEUES[name].retryLimit).toBe(2);
      expect(QUEUES[name].expireInSeconds).toBe(1800);
    }
  });
});
