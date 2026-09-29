import { useLoaderData, useRevalidator } from 'react-router';
import { useState } from 'react';

import { adminSend } from '~/lib/admin-api.ts';
import { apiGet, forwardHeaders } from '~/lib/api.server.ts';

interface Stats {
  sources: { total: number; active: number };
  episodes: Record<string, number>;
  reports: number;
  latestReportKey: string | null;
}

export async function loader({ request }: { request: Request }) {
  return { stats: await apiGet<Stats>('/admin/stats', forwardHeaders(request)) };
}

export default function AdminDashboard() {
  const { stats } = useLoaderData<typeof loader>();
  const revalidator = useRevalidator();
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  async function run(key: string, fn: () => Promise<unknown>, done: string) {
    setBusy(key);
    setMessage(null);
    try {
      await fn();
      setMessage(done);
      revalidator.revalidate();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '操作失败');
    } finally {
      setBusy(null);
    }
  }

  const episodeTotal = Object.values(stats?.episodes ?? {}).reduce((a, b) => a + b, 0);

  return (
    <div className="mt-6 space-y-6">
      {message && (
        <p className="rounded-md border border-stone-200 bg-stone-50 px-3 py-2 text-sm text-stone-600">{message}</p>
      )}

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="订阅源" value={`${stats?.sources.active ?? 0}/${stats?.sources.total ?? 0}`} hint="启用/总数" />
        <StatCard label="单集" value={String(episodeTotal)} hint="累计入库" />
        <StatCard
          label="已完成"
          value={String(stats?.episodes['done'] ?? 0)}
          hint="转写+分析完毕"
        />
        <StatCard label="日报" value={String(stats?.reports ?? 0)} hint={stats?.latestReportKey ?? '最新：无'} />
      </div>

      <div className="rounded-lg border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-stone-500">流水线状态</h2>
        <div className="mt-3 flex flex-wrap gap-2 text-xs">
          {Object.entries(stats?.episodes ?? {}).map(([status, count]) => (
            <span key={status} className="rounded-full bg-stone-100 px-2.5 py-1 text-stone-600">
              {status}: {count}
            </span>
          ))}
          {episodeTotal === 0 && <span className="text-stone-400">还没有单集，先去订阅源页添加一个播客。</span>}
        </div>
      </div>

      <div className="flex flex-wrap gap-3">
        <button
          onClick={() => run('report', () => adminSend('/reports/generate', 'POST'), '日报生成任务已提交')}
          disabled={busy !== null}
          className="rounded-md bg-stone-900 px-4 py-2 text-sm font-medium text-white hover:bg-stone-700 disabled:opacity-50"
        >
          {busy === 'report' ? '提交中…' : '生成昨日日报'}
        </button>
        <a
          href="/admin/sources"
          className="rounded-md border border-stone-300 px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-100"
        >
          管理订阅源
        </a>
      </div>
    </div>
  );
}

function StatCard({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-lg border border-stone-200 bg-white p-4">
      <div className="text-xs text-stone-400">{label}</div>
      <div className="mt-1 text-2xl font-bold text-stone-900">{value}</div>
      <div className="mt-0.5 text-[11px] text-stone-400">{hint}</div>
    </div>
  );
}
