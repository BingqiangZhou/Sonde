/** web 进程访问 api 的唯一通道（SSR loader 中调用，服务端执行）。
 *  path 以 / 开头，自动加 /api 前缀；可转发浏览器请求的 cookie（admin 页面需要）。 */

const API_URL = process.env.API_URL ?? 'http://localhost:3001';

export async function apiGet<T>(
  path: string,
  options: { cookie?: string | null } = {},
): Promise<T | null> {
  try {
    const res = await fetch(`${API_URL}/api${path}`, {
      headers: {
        accept: 'application/json',
        ...(options.cookie ? { cookie: options.cookie } : {}),
      },
      signal: AbortSignal.timeout(8_000),
    });
    if (!res.ok) {
      return null;
    }
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

/** 从 Request 提取需要转发给 api 的头（目前仅 cookie）。 */
export function forwardHeaders(request: Request): { cookie: string | null } {
  return { cookie: request.headers.get('cookie') };
}
