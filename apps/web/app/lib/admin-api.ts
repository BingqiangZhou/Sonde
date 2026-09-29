/** admin 客户端 API（同源经 web 服务器反代到 api）。 */

export async function adminGet<T>(path: string): Promise<T> {
  const res = await fetch(`/api/admin${path}`, { credentials: 'same-origin' });
  if (!res.ok) {
    throw new Error((await res.json().catch(() => ({}))).error ?? `HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function adminSend<T = { ok: boolean }>(
  path: string,
  method: 'POST' | 'PATCH' | 'DELETE',
  body?: unknown,
): Promise<T> {
  const res = await fetch(`/api/admin${path}`, {
    method,
    credentials: 'same-origin',
    headers: body !== undefined ? { 'content-type': 'application/json' } : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    throw new Error((await res.json().catch(() => ({}))).error ?? `HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}
