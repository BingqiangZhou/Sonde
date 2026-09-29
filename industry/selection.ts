/** 精选门槛与兴趣画像（声读定制层）。
 *  - thresholds：按源分级的入选门槛。LLM 为单集打 0-100 注意力价值分，
 *    score >= thresholds[source.tier] 才会进入写作与日报。
 *  - interestProfile：兴趣画像，注入评分 prompt 的“听众相关性”维度。
 *    留空则使用通用标准。 */

export const SELECTION = {
  thresholds: {
    T1: 60,
    T2: 70,
  } as Record<string, number>,
  /** 未配置 tier 的源使用的默认门槛 */
  defaultThreshold: 70,
  /** 每日日报最多收录条目数 */
  maxReportItems: 10,
  /** 周报最多收录条目数（从上一周入选单集中取分数最高者） */
  maxWeeklyItems: 16,
  /** 月报最多收录条目数 */
  maxMonthlyItems: 24,
  /** 兴趣画像（中文，一句话到一段话均可） */
  interestProfile: '',
} as const;

export function thresholdFor(tier: string | null | undefined): number {
  if (tier == null) {
    return SELECTION.defaultThreshold;
  }
  return SELECTION.thresholds[tier] ?? SELECTION.defaultThreshold;
}
