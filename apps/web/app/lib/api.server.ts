/** web 进程访问 api 的唯一通道（SSR loader 中调用，服务端执行）。
 *  path 以 / 开头，自动加 /api 前缀。
 *  错误分层：404/401/403 → null（维持 loader 的"还没有"空态）；
 *  其余失败 → 抛 Response(5xx)——React Router 框架模式对自定义 Error 会序列化
 *  掉 status 字段，throw Response 是保留状态码的原生通道，root ErrorBoundary
 *  按 error.status >= 500 呈现"服务暂时不可用"。 */

const API_URL = process.env.API_URL ?? 'http://localhost:3001';

export async function apiGet<T>(path: string): Promise<T | null> {
  let res: Response;
  try {
    res = await fetch(`${API_URL}/api${path}`, {
      headers: { accept: 'application/json' },
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

/** apiGet 的带响应头版本(错误分层语义完全一致):
 *  返回 { data, etag } —— api 读路由现在带弱 ETag,资源路由转发它即可让
 *  浏览器做条件 GET(304 省传输)。既有 apiGet 调用方零改动。 */
export async function apiGetWithHeaders<T>(path: string): Promise<{ data: T; etag: string | null } | null> {
  let res: Response;
  try {
    res = await fetch(`${API_URL}/api${path}`, {
      headers: { accept: 'application/json' },
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
  return { data: (await res.json()) as T, etag: res.headers.get('etag') };
}
