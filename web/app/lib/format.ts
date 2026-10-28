/** 展示格式化（中文）。 */

export function formatDate(value: string | Date | null | undefined): string {
  if (!value) {
    return '日期未知';
  }
  const date = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) {
    return '日期未知';
  }
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function formatDuration(seconds: number | null | undefined): string {
  if (!seconds || seconds <= 0) {
    return '';
  }
  const h = Math.floor(seconds / 3600);
  const m = Math.round((seconds % 3600) / 60);
  return h > 0 ? `${h} 小时 ${m} 分钟` : `${m} 分钟`;
}

/** 周报 key（周一 YYYY-MM-DD）→ '9月21日–9月27日'（覆盖周一至周日）。 */
export function formatWeekRange(mondayKey: string): string {
  const [y, m, d] = mondayKey.split('-').map((part) => Number.parseInt(part, 10));
  const noon = Date.UTC(y as number, (m as number) - 1, d as number) + 12 * 60 * 60 * 1000;
  const start = new Date(noon);
  const end = new Date(noon + 6 * 24 * 60 * 60 * 1000);
  const md = (date: Date) => `${date.getUTCMonth() + 1}月${date.getUTCDate()}日`;
  return `${md(start)}–${md(end)}`;
}

/** 月报 key（YYYY-MM）→ '2026年9月'。 */
export function formatMonthKey(monthKey: string): string {
  const [y, m] = monthKey.split('-').map((part) => Number.parseInt(part, 10));
  return `${y} 年 ${m} 月`;
}
