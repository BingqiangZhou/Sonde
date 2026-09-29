/** web 进程访问 api 的唯一通道（SSR loader 中调用，服务端执行）。 */

const API_URL = process.env.API_URL ?? 'http://localhost:3001';

export async function apiGet<T>(path: string): Promise<T | null> {
  try {
    const res = await fetch(`${API_URL}${path}`, {
      headers: { accept: 'application/json' },
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
