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
   *  stately + singletonKey `src:${id}` 防同源任务堆叠；cron 每分钟重派，队列级重试从简。 */
  'sources.fetch': { retryLimit: 1, retryBackoff: true, retryDelay: 30, expireInSeconds: 600, policy: 'stately' },
} as const satisfies Record<string, QueueDef>;

export type QueueName = keyof typeof QUEUES;
export const QUEUE_NAMES = Object.keys(QUEUES) as QueueName[];
