/** 队列定义（api 发送 / worker 消费共用）。 */

export interface QueueDef {
  retryLimit: number;
  retryBackoff?: boolean;
  retryDelay?: number;
  expireInSeconds?: number;
}

export const QUEUES = {
  /** data: {} = 扫描全部到期源；data: { sourceId } = 手动抓取单个源 */
  'sources.fetch': { retryLimit: 3, retryBackoff: true, expireInSeconds: 600 },
  /** 转写一个单集：下载 → 转码 → 分块 → 转写 → 合并（data: { episodeId }） */
  'episodes.transcribe': {
    retryLimit: 2,
    retryBackoff: true,
    retryDelay: 60,
    expireInSeconds: 7200,
  },
  /** 分析一个单集：评分 →（过门槛）写作（data: { episodeId }） */
  'episodes.analyze': { retryLimit: 3, retryBackoff: true, expireInSeconds: 600 },
  /** 生成/补发日报（data: { reportKey? }，缺省为昨天） */
  'reports.daily': { retryLimit: 2, retryBackoff: true, retryDelay: 60, expireInSeconds: 1800 },
} as const satisfies Record<string, QueueDef>;

export type QueueName = keyof typeof QUEUES;
export const QUEUE_NAMES = Object.keys(QUEUES) as QueueName[];
