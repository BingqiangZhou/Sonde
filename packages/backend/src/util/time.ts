/** 报刊时间窗计算：以 REPORT_TIMEZONE（默认 Asia/Shanghai）的日历日为准，换算成 UTC 窗口。
 *  日报 key = 'YYYY-MM-DD'；周报 key = 覆盖周的周一 'YYYY-MM-DD'；月报 key = 'YYYY-MM'。 */

const KEY_RE = /^\d{4}-\d{2}-\d{2}$/;
const MONTH_KEY_RE = /^\d{4}-\d{2}$/;

/** 指定时区“此刻”的日历日 key（YYYY-MM-DD）。 */
export function todayKeyInTz(now: Date, timeZone: string): string {
  return calendarKey(now, timeZone);
}

/** 指定时区“昨天”的日历日 key。 */
export function yesterdayKeyInTz(now: Date, timeZone: string): string {
  return calendarKey(new Date(now.getTime() - 24 * 60 * 60 * 1000), timeZone);
}

/** 某时区日历日 [start, end) 的 UTC 窗口。key 必须是 YYYY-MM-DD。 */
export function dayWindowUtc(
  key: string,
  timeZone: string,
): { start: Date; end: Date } {
  const start = localMidnightUtc(key, timeZone);
  const end = localMidnightUtc(nextDayKey(key), timeZone);
  if (end.getTime() <= start.getTime()) {
    throw new Error(`window computation failed for ${key}`);
  }
  return { start, end };
}

function localMidnightUtc(key: string, timeZone: string): Date {
  if (!KEY_RE.test(key)) {
    throw new Error(`invalid date key: ${key}`);
  }
  const [y, m, d] = key.split('-').map((part) => Number.parseInt(part, 10));
  const [year, month, day] = [y as number, m as number, d as number];
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw new Error(`invalid date key: ${key}`);
  }

  // 两遍逼近：先按 UTC 解释当地午夜，再用真实偏移修正（覆盖夏令时）
  let guess = Date.UTC(year, month - 1, day, 0, 0, 0);
  for (let i = 0; i < 2; i++) {
    const offset = tzOffsetMs(new Date(guess), timeZone);
    guess = Date.UTC(year, month - 1, day, 0, 0, 0) - offset;
  }
  const result = new Date(guess);

  // 校验：窗口起点必须落在目标日历日内（防偏移漂移）
  const verifyKey = calendarKey(result, timeZone);
  if (verifyKey !== key) {
    throw new Error(`window computation drifted: ${verifyKey} != ${key}`);
  }
  return result;
}

function nextDayKey(key: string): string {
  const [y, m, d] = key.split('-').map((part) => Number.parseInt(part, 10));
  const next = new Date(Date.UTC((y as number), (m as number) - 1, (d as number) + 1));
  return calendarKey(new Date(next.getTime() + 12 * 60 * 60 * 1000), 'UTC');
}

// ---------- 周报 / 月报 ----------

/** 纯日期（YYYY-MM-DD）是否为周一。星期与日历日期绑定，与时区无关。 */
export function isMondayKey(key: string): boolean {
  if (!KEY_RE.test(key)) {
    throw new Error(`invalid date key: ${key}`);
  }
  const [y, m, d] = key.split('-').map((part) => Number.parseInt(part, 10));
  const weekday = new Date(Date.UTC((y as number), (m as number) - 1, (d as number))).getUTCDay();
  return weekday === 1;
}

/** 指定时区“上周一”的 key。周一成刊的周报覆盖上一个自然周（周一 00:00 至周日 24:00）。 */
export function lastWeekMondayKeyInTz(now: Date, timeZone: string): string {
  const today = calendarKey(now, timeZone);
  const [y, m, d] = today.split('-').map((part) => Number.parseInt(part, 10));
  const utcNoon = Date.UTC((y as number), (m as number) - 1, (d as number));
  const weekday = new Date(utcNoon).getUTCDay();
  const monday = new Date(utcNoon - ((weekday + 6) % 7) * 24 * 60 * 60 * 1000 - 7 * 24 * 60 * 60 * 1000);
  return calendarKey(new Date(monday.getTime() + 12 * 60 * 60 * 1000), 'UTC');
}

/** 周报 [start, end) 的 UTC 窗口。key 必须是覆盖周的周一（YYYY-MM-DD）。 */
export function weekWindowUtc(
  key: string,
  timeZone: string,
): { start: Date; end: Date } {
  if (!isMondayKey(key)) {
    throw new Error(`weekly report key must be a Monday: ${key}`);
  }
  const start = localMidnightUtc(key, timeZone);
  const [y, m, d] = key.split('-').map((part) => Number.parseInt(part, 10));
  const nextMonday = new Date(Date.UTC((y as number), (m as number) - 1, (d as number) + 7));
  const end = localMidnightUtc(calendarKey(new Date(nextMonday.getTime() + 12 * 60 * 60 * 1000), 'UTC'), timeZone);
  if (end.getTime() <= start.getTime()) {
    throw new Error(`window computation failed for ${key}`);
  }
  return { start, end };
}

/** 指定时区“上个自然月”的 key（YYYY-MM）。每月 1 日成刊的月报覆盖上一个自然月。 */
export function lastMonthKeyInTz(now: Date, timeZone: string): string {
  const today = calendarKey(now, timeZone);
  const [y, m] = today.split('-').map((part) => Number.parseInt(part, 10));
  const year = m === 1 ? (y as number) - 1 : y;
  const month = m === 1 ? 12 : (m as number) - 1;
  return `${year}-${String(month).padStart(2, '0')}`;
}

/** 月报 [start, end) 的 UTC 窗口。key 必须是 'YYYY-MM'。 */
export function monthWindowUtc(
  key: string,
  timeZone: string,
): { start: Date; end: Date } {
  if (!MONTH_KEY_RE.test(key)) {
    throw new Error(`invalid month key: ${key}`);
  }
  const [y, m] = key.split('-').map((part) => Number.parseInt(part, 10));
  if ((m as number) < 1 || (m as number) > 12) {
    throw new Error(`invalid month key: ${key}`);
  }
  const nextYear = m === 12 ? (y as number) + 1 : y;
  const nextMonth = m === 12 ? 1 : (m as number) + 1;
  const start = localMidnightUtc(`${key}-01`, timeZone);
  const end = localMidnightUtc(
    `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`,
    timeZone,
  );
  if (end.getTime() <= start.getTime()) {
    throw new Error(`window computation failed for ${key}`);
  }
  return { start, end };
}

function calendarKey(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
  return parts; // en-CA 输出即为 YYYY-MM-DD
}

function tzOffsetMs(date: Date, timeZone: string): number {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const map = new Map<string, number>();
  for (const part of dtf.formatToParts(date)) {
    if (part.type !== 'literal') {
      map.set(part.type, Number.parseInt(part.value, 10));
    }
  }
  const asUtc = Date.UTC(
    (map.get('year') as number),
    (map.get('month') as number) - 1,
    (map.get('day') as number),
    (map.get('hour') as number) % 24,
    (map.get('minute') as number),
    (map.get('second') as number),
  );
  return asUtc - date.getTime();
}
