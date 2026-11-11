/** 展示格式化(中文)。
 *  时间线展示固定用北京(Asia/Shanghai)时间,与运行环境时区无关:
 *  SSR 容器是 UTC、浏览器时区不定——不固定时区会导致首屏与水合文本不一致。 */

const SHANGHAI_TZ = 'Asia/Shanghai';

const shanghaiFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: SHANGHAI_TZ,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

function toDate(value: string | Date): Date | null {
  const date = typeof value === 'string' ? new Date(value) : value;
  return Number.isNaN(date.getTime()) ? null : date;
}

function shanghaiParts(date: Date): { date: string; time: string } {
  const parts: Record<string, string> = {};
  for (const part of shanghaiFormatter.formatToParts(date)) {
    parts[part.type] = part.value;
  }
  return {
    date: `${parts['year']}-${parts['month']}-${parts['day']}`,
    time: `${parts['hour']}:${parts['minute']}`,
  };
}

export function formatDate(value: string | Date | null | undefined): string {
  if (!value) {
    return '日期未知';
  }
  const date = toDate(value);
  return date ? shanghaiParts(date).date : '日期未知';
}

/** 时间线粒度:YYYY-MM-DD HH:mm(北京时间)。 */
export function formatDateTime(value: string | Date | null | undefined): string {
  if (!value) {
    return '日期未知';
  }
  const date = toDate(value);
  if (!date) {
    return '日期未知';
  }
  const parts = shanghaiParts(date);
  return `${parts.date} ${parts.time}`;
}

export function formatDuration(seconds: number | null | undefined): string {
  if (!seconds || seconds <= 0) {
    return '';
  }
  const h = Math.floor(seconds / 3600);
  const m = Math.round((seconds % 3600) / 60);
  return h > 0 ? `${h} 小时 ${m} 分钟` : `${m} 分钟`;
}
