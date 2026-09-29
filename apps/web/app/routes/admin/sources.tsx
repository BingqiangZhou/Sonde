import { useLoaderData, useRevalidator } from 'react-router';
import { useState } from 'react';

import { adminSend } from '~/lib/admin-api.ts';
import { apiGet, forwardHeaders } from '~/lib/api.server.ts';

interface AdminSource {
  id: number;
  name: string;
  feedUrl: string;
  tier: string;
  intervalMinutes: number;
  isActive: boolean;
  lastFetchedAt: string | null;
  health: { lastStatus?: string; lastError?: string | null; consecutiveFailures?: number };
}

export async function loader({ request }: { request: Request }) {
  return { sources: (await apiGet<{ sources: AdminSource[] }>('/admin/sources', forwardHeaders(request)))?.sources ?? [] };
}

export default function AdminSources() {
  const { sources } = useLoaderData<typeof loader>();
  const revalidator = useRevalidator();
  const [busy, setBusy] = useState<number | string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', feedUrl: '', tier: 'T2', intervalMinutes: 60 });

  async function run(key: number | string, fn: () => Promise<unknown>) {
    setBusy(key);
    setError(null);
    try {
      await fn();
      revalidator.revalidate();
    } catch (err) {
      setError(err instanceof Error ? err.message : '操作失败');
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="mt-6 space-y-6">
      <section className="rounded-lg border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-stone-500">添加订阅源</h2>
        <form
          className="mt-3 grid gap-3 sm:grid-cols-[1fr_1fr_80px_90px_auto]"
          onSubmit={async (event) => {
            event.preventDefault();
            await run('add', () => adminSend('/sources', 'POST', form));
            setForm({ name: '', feedUrl: '', tier: 'T2', intervalMinutes: 60 });
          }}
        >
          <input
            required
            placeholder="播客名称"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-stone-500 focus:outline-none"
          />
          <input
            required
            type="url"
            placeholder="RSS 地址 https://…"
            value={form.feedUrl}
            onChange={(e) => setForm({ ...form, feedUrl: e.target.value })}
            className="rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-stone-500 focus:outline-none"
          />
          <select
            value={form.tier}
            onChange={(e) => setForm({ ...form, tier: e.target.value })}
            className="rounded-md border border-stone-300 px-2 py-2 text-sm"
            title="T1=高优先（门槛 60），T2=一般（门槛 70）"
          >
            <option value="T1">T1</option>
            <option value="T2">T2</option>
          </select>
          <input
            type="number"
            min={5}
            max={1440}
            value={form.intervalMinutes}
            onChange={(e) => setForm({ ...form, intervalMinutes: Number(e.target.value) })}
            className="rounded-md border border-stone-300 px-2 py-2 text-sm"
            title="抓取间隔（分钟）"
          />
          <button
            type="submit"
            disabled={busy !== null}
            className="rounded-md bg-stone-900 px-4 py-2 text-sm font-medium text-white hover:bg-stone-700 disabled:opacity-50"
          >
            {busy === 'add' ? '添加中…' : '添加'}
          </button>
        </form>
        {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
      </section>

      <section className="overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-stone-200 text-left text-xs text-stone-400">
              <th className="px-4 py-2.5">名称</th>
              <th className="px-4 py-2.5">分级</th>
              <th className="px-4 py-2.5">间隔</th>
              <th className="px-4 py-2.5">状态</th>
              <th className="px-4 py-2.5">最近抓取</th>
              <th className="px-4 py-2.5 text-right">操作</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {sources.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-stone-400">
                  还没有订阅源
                </td>
              </tr>
            )}
            {sources.map((source) => (
              <tr key={source.id} className={source.isActive ? '' : 'opacity-50'}>
                <td className="px-4 py-2.5">
                  <div className="font-medium text-stone-900">{source.name}</div>
                  <div className="max-w-[16rem] truncate text-xs text-stone-400" title={source.feedUrl}>
                    {source.feedUrl}
                  </div>
                </td>
                <td className="px-4 py-2.5">
                  <select
                    value={source.tier}
                    onChange={(e) => run(source.id, () => adminSend(`/sources/${source.id}`, 'PATCH', { tier: e.target.value }))}
                    className="rounded border border-stone-200 px-1.5 py-1 text-xs"
                  >
                    <option value="T1">T1</option>
                    <option value="T2">T2</option>
                  </select>
                </td>
                <td className="px-4 py-2.5 text-stone-500">{source.intervalMinutes} 分</td>
                <td className="px-4 py-2.5">
                  {source.health?.lastStatus === 'ok' ? (
                    <span className="text-emerald-600">正常</span>
                  ) : source.health?.lastError ? (
                    <span className="text-red-600" title={source.health.lastError}>
                      异常{source.health.consecutiveFailures ? ` ×${source.health.consecutiveFailures}` : ''}
                    </span>
                  ) : (
                    <span className="text-stone-400">未抓取</span>
                  )}
                </td>
                <td className="px-4 py-2.5 text-xs text-stone-400">
                  {source.lastFetchedAt ? new Date(source.lastFetchedAt).toLocaleString('zh-CN') : '—'}
                </td>
                <td className="px-4 py-2.5 text-right text-xs">
                  <button
                    onClick={() => run(source.id, () => adminSend(`/sources/${source.id}/fetch-now`, 'POST'))}
                    disabled={busy !== null}
                    className="text-stone-600 underline hover:text-stone-900 disabled:opacity-50"
                  >
                    立即抓取
                  </button>
                  <span className="mx-1.5 text-stone-200">|</span>
                  <button
                    onClick={() =>
                      run(source.id, () =>
                        adminSend(`/sources/${source.id}`, 'PATCH', { isActive: !source.isActive }),
                      )
                    }
                    disabled={busy !== null}
                    className="text-stone-600 underline hover:text-stone-900 disabled:opacity-50"
                  >
                    {source.isActive ? '停用' : '启用'}
                  </button>
                  <span className="mx-1.5 text-stone-200">|</span>
                  <button
                    onClick={() => run(source.id, () => adminSend(`/sources/${source.id}`, 'DELETE'))}
                    disabled={busy !== null}
                    className="text-red-600 underline hover:text-red-700 disabled:opacity-50"
                  >
                    删除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
