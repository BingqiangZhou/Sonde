/**
 * HTTP 封装：统一 User-Agent、超时、错误处理。
 * 用于所有 skills 的网络抓取。
 */
const DEFAULT_UA =
  "PodcastInsight/3.0 (+https://github.com/BingqiangZhou/PodcastInsight)";
const DEFAULT_TIMEOUT_MS = 30_000;

export interface FetchOptions {
  headers?: Record<string, string>;
  timeoutMs?: number;
  accept?: string;
}

function buildHeaders(opts: FetchOptions = {}): Record<string, string> {
  return {
    "User-Agent": DEFAULT_UA,
    ...(opts.accept ? { Accept: opts.accept } : {}),
    ...(opts.headers ?? {}),
  };
}

async function withTimeout(
  input: string,
  init: RequestInit,
  timeoutMs: number
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchText(url: string, opts: FetchOptions = {}): Promise<string> {
  const res = await withTimeout(
    url,
    { headers: buildHeaders(opts) },
    opts.timeoutMs ?? DEFAULT_TIMEOUT_MS
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return res.text();
}

export async function fetchJson<T = unknown>(url: string, opts: FetchOptions = {}): Promise<T> {
  const res = await withTimeout(
    url,
    { headers: buildHeaders(opts) },
    opts.timeoutMs ?? DEFAULT_TIMEOUT_MS
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${url}`);
  return (await res.json()) as T;
}
