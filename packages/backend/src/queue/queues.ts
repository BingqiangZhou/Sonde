/** 队列定义（api 发送 / worker 消费共用）。 */

export interface QueueDef {
  retryLimit: number;
  retryBackoff?: boolean;
  retryDelay?: number;
  expireInSeconds?: number;
  /** stately = singletonKey 真正按 key 去重（standard 策略下 singletonKey 是空操作） */
  policy?: 'standard' | 'short' | 'singleton' | 'stately';
}

export const QUEUES = {
  /** data: {} = 扫描到期源并逐源派发单源任务；data: { sourceId } = 抓取单个源。
   *  stately + singletonKey `src:${id}` 防同源任务堆叠；cron 每分钟重派，队列级重试从简。
   *  expire 必须 < 最短订阅间隔(10 分钟):完成的任务行会占住单例键直到过期+清理,
   *  expire ≥ 间隔会导致下一轮派发被吞(实测一半派发被去重)。最坏路径 60s 超时
   *  +30s 重试延迟 +60s 重试 = 150s,180s 留余量。 */
  'sources.fetch': { retryLimit: 1, retryBackoff: true, retryDelay: 30, expireInSeconds: 180, policy: 'stately' },
  /** 每日 04:00(北京)同步 xyzrank 播客榜前 1000(进榜新增/掉榜停用,origin=xyzrank 隔离手工订阅)。
   *  10 页 API + 单事务千级 upsert,expire 给足;stately + singletonKey 防与启动触发的同步堆叠。 */
  'sources.sync-xyzrank': {
    retryLimit: 1,
    retryBackoff: true,
    retryDelay: 300,
    expireInSeconds: 1200,
    policy: 'stately',
  },
} as const satisfies Record<string, QueueDef>;

export type QueueName = keyof typeof QUEUES;
export const QUEUE_NAMES = Object.keys(QUEUES) as QueueName[];
