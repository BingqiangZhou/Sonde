/** 队列定义与命名（worker 使用；api 发送任务时也引用名称）。 */

interface QueueDef {
  /** 最大尝试次数 */
  retryLimit: number;
  /** 重试间隔是否指数退避 */
  retryBackoff?: boolean;
  /** 首次重试延迟（秒） */
  retryDelay?: number;
  /** 任务过期时间（秒），超时视为失败 */
  expireInSeconds?: number;
}

export const QUEUES = {
  /** 每分钟扫描到期源并派发抓取（job data 为空，处理器自行扫描） */
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
