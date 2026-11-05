/** web 进程访问 api 的唯一通道（SSR loader 中调用，服务端执行）。
 *  path 以 / 开头，自动加 /api 前缀；可转发浏览器请求的 cookie（admin 页面需要）。
 *  错误分层：404/401/403 → null（维持各 loader 的"还没有"/未登录空态）；
 *  其余失败 → 抛 Response(5xx)——React Router 框架模式对自定义 Error 会序列化
 *  掉 status 字段，throw Response 是保留状态码的原生通道，root ErrorBoundary
 *  按 error.status >= 500 呈现"服务暂时不可用"。 */

const API_URL = process.env.API_URL ?? 'http://localhost:3001';

export async function apiGet<T>(
  path: string,
  options: { cookie?: string | null } = {},
): Promise<T | null> {
  let res: Response;
  try {
    res = await fetch(`${API_URL}/api${path}`, {
      headers: {
        accept: 'application/json',
        ...(options.cookie ? { cookie: options.cookie } : {}),
      },
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    throw new Response(`api unreachable: ${path}`, { status: 503 });
  }
  if (res.status === 404 || res.status === 401 || res.status === 403) {
    return null;
  }
  if (!res.ok) {
    throw new Response(`api ${res.status}: ${path}`, { status: res.status });
  }
  return (await res.json()) as T;
}

/** 从 Request 提取需要转发给 api 的头（目前仅 cookie）。 */
export function forwardHeaders(request: Request): { cookie: string | null } {
  return { cookie: request.headers.get('cookie') };
}
