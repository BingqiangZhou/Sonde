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
  return {
    sources: (await apiGet<{ sources: AdminSource[] }>('/admin/sources', forwardHeaders(request)))?.sources ?? [],
  };
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
    <div className="space-y-6">
      <section className="rounded-lg border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-stone-500">添加订阅源</h2>
        <form
          className="mt-4 grid gap-3 sm:grid-cols-[1fr_1fr_5rem_6rem_auto]"
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
            className="rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-vermilion focus:outline-none"
          />
          <input
            required
            type="url"
            placeholder="RSS 地址 https://…"
            value={form.feedUrl}
            onChange={(e) => setForm({ ...form, feedUrl: e.target.value })}
            className="rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-vermilion focus:outline-none"
          />
          <select
            value={form.tier}
            onChange={(e) => setForm({ ...form, tier: e.target.value })}
            className="rounded-md border border-stone-300 bg-white px-2 py-2 text-sm"
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
            className="rounded-md bg-ink px-4 py-2 text-sm font-medium text-paper transition-colors hover:bg-vermilion disabled:opacity-50"
          >
            {busy === 'add' ? '添加中…' : '添加'}
          </button>
        </form>
        <p className="mt-2 text-[11px] text-stone-400">
          分级说明：T1 = 高优先播客（入选门槛 60 分），T2 = 一般播客（入选门槛 70 分），可在 industry/selection.ts 调整。
        </p>
        {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
      </section>

      <section className="overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-stone-200 bg-stone-50/70 text-left text-[11px] uppercase tracking-wider text-stone-400">
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
                <td colSpan={6} className="px-4 py-10 text-center text-stone-400">
                  还没有订阅源，用上方表单添加第一个播客
                </td>
              </tr>
            )}
            {sources.map((source) => (
              <tr key={source.id} className={`hover:bg-stone-50/60 ${source.isActive ? '' : 'opacity-50'}`}>
                <td className="px-4 py-2.5">
                  <div className="font-medium text-ink">{source.name}</div>
                  <div className="max-w-[16rem] truncate text-xs text-stone-400" title={source.feedUrl}>
                    {source.feedUrl}
                  </div>
                </td>
                <td className="px-4 py-2.5">
                  <select
                    value={source.tier}
                    onChange={(e) =>
                      run(source.id, () => adminSend(`/sources/${source.id}`, 'PATCH', { tier: e.target.value }))
                    }
                    className="rounded border border-stone-200 bg-white px-1.5 py-1 text-xs"
                  >
                    <option value="T1">T1</option>
                    <option value="T2">T2</option>
                  </select>
                </td>
                <td className="px-4 py-2.5 text-stone-500">{source.intervalMinutes} 分</td>
                <td className="px-4 py-2.5">
                  {source.health?.lastStatus === 'ok' ? (
                    <span className="inline-flex items-center gap-1 text-emerald-600">
                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
                      正常
                    </span>
                  ) : source.health?.lastError ? (
                    <span
                      className="inline-flex items-center gap-1 text-red-600"
                      title={source.health.lastError}
                    >
                      <span className="h-1.5 w-1.5 rounded-full bg-red-500" />
                      异常{source.health.consecutiveFailures ? ` ×${source.health.consecutiveFailures}` : ''}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-stone-400">
                      <span className="h-1.5 w-1.5 rounded-full bg-stone-300" />
                      未抓取
                    </span>
                  )}
                </td>
                <td className="px-4 py-2.5 text-xs text-stone-400">
                  {source.lastFetchedAt ? new Date(source.lastFetchedAt).toLocaleString('zh-CN', { hour12: false }) : '—'}
                </td>
                <td className="whitespace-nowrap px-4 py-2.5 text-right text-xs">
                  <button
                    onClick={() => run(source.id, () => adminSend(`/sources/${source.id}/fetch-now`, 'POST'))}
                    disabled={busy !== null}
                    className="rounded px-2 py-1 text-stone-600 hover:bg-stone-100 disabled:opacity-50"
                  >
                    立即抓取
                  </button>
                  <button
                    onClick={() =>
                      run(source.id, () =>
                        adminSend(`/sources/${source.id}`, 'PATCH', { isActive: !source.isActive }),
                      )
                    }
                    disabled={busy !== null}
                    className="rounded px-2 py-1 text-stone-600 hover:bg-stone-100 disabled:opacity-50"
                  >
                    {source.isActive ? '停用' : '启用'}
                  </button>
                  <button
                    onClick={() => run(source.id, () => adminSend(`/sources/${source.id}`, 'DELETE'))}
                    disabled={busy !== null}
                    className="rounded px-2 py-1 text-red-600 hover:bg-red-50 disabled:opacity-50"
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
