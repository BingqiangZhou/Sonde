import { describe, expect, it } from 'vitest';

import { QUEUES } from '../src/queue/queues.ts';

/** 队列策略契约：
 *  - stately 策略让 singletonKey 真正去重（standard 策略下是空操作）
 *  - expire 必须覆盖最坏执行时长，否则 handler 仍在跑就被判过期重试 */
describe('QUEUES 队列策略', () => {
  it('仅保留 sources.fetch、sources.sync-xyzrank、sources.adapt-intervals 三个队列（AI 管道已移除）', () => {
    expect(Object.keys(QUEUES)).toEqual(['sources.fetch', 'sources.sync-xyzrank', 'sources.adapt-intervals']);
  });

  it('sources.fetch：stately 策略 + 派发器语义（单源任务，cron 每分钟重派）', () => {
    const q = QUEUES['sources.fetch'];
    expect(q.policy).toBe('stately');
    // expire 必须 < 最短订阅间隔(10 分钟),否则单例键占位吞掉下一轮派发
    expect(q.expireInSeconds).toBe(180);
    expect(q.retryLimit).toBe(1);
  });

  it('sources.sync-xyzrank：stately 防同步堆叠,expire 覆盖 10 页 API + 千级 upsert 的事务', () => {
    const q = QUEUES['sources.sync-xyzrank'];
    expect(q.policy).toBe('stately');
    expect(q.expireInSeconds).toBeGreaterThanOrEqual(1200);
    expect(q.retryLimit).toBe(1);
  });

  it('sources.adapt-intervals：stately 防与启动触发堆叠,expire 覆盖千级源的间隔重算', () => {
    const q = QUEUES['sources.adapt-intervals'];
    expect(q.policy).toBe('stately');
    expect(q.expireInSeconds).toBeGreaterThanOrEqual(600);
    expect(q.retryLimit).toBe(1);
  });
});
