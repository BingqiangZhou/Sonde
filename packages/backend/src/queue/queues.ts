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
  /** 转写一个单集：下载 → 转码 → 分块 → 转写 → 合并（data: { episodeId }）。
   *  最坏 ≈ 下载 30min + ~12 块 × 3 次 × 600s ≈ 6.5h，expire 需覆盖（28800s）。 */
  'episodes.transcribe': {
    retryLimit: 2,
    retryBackoff: true,
    retryDelay: 60,
    expireInSeconds: 28800,
    policy: 'stately',
  },
  /** 分析一个单集：评分 →（过门槛）写作（data: { episodeId }）。
   *  2 次 LLM 调用最坏 18+ 分钟，expire 1800s。 */
  'episodes.analyze': { retryLimit: 3, retryBackoff: true, expireInSeconds: 1800, policy: 'stately' },
  /** 生成/补发日报（data: { reportKey? }，缺省为昨天） */
  'reports.daily': { retryLimit: 2, retryBackoff: true, retryDelay: 60, expireInSeconds: 1800 },
  /** 生成/补发周报（data: { reportKey? }，缺省为上周一；每周一 08:30 定时） */
  'reports.weekly': { retryLimit: 2, retryBackoff: true, retryDelay: 60, expireInSeconds: 1800 },
  /** 生成/补发月报（data: { reportKey? }，缺省为上个自然月；每月 1 日 08:30 定时） */
  'reports.monthly': { retryLimit: 2, retryBackoff: true, retryDelay: 60, expireInSeconds: 1800 },
} as const satisfies Record<string, QueueDef>;

export type QueueName = keyof typeof QUEUES;
export const QUEUE_NAMES = Object.keys(QUEUES) as QueueName[];
