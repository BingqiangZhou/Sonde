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
  const inFlight = (stats?.episodes['pending'] ?? 0)
    + (stats?.episodes['downloading'] ?? 0)
    + (stats?.episodes['converting'] ?? 0)
    + (stats?.episodes['transcribing'] ?? 0)
    + (stats?.episodes['analyzing'] ?? 0);

  return (
    <div className="space-y-6">
      {message && (
        <p className="rounded-md border border-vermilion/30 bg-vermilion/5 px-3 py-2 text-sm text-stone-700">
          {message}
        </p>
      )}

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard
          icon={<IconRadio />}
          label="订阅源"
          value={`${stats?.sources.active ?? 0}`}
          hint={`共 ${stats?.sources.total ?? 0} 个（含停用）`}
          tone="emerald"
        />
        <StatCard
          icon={<IconDisc />}
          label="单集"
          value={String(episodeTotal)}
          hint="累计入库"
          tone="blue"
        />
        <StatCard
          icon={<IconCheck />}
          label="已完成"
          value={String(stats?.episodes['done'] ?? 0)}
          hint={inFlight > 0 ? `${inFlight} 个进行中` : '全部处理完毕'}
          tone="amber"
        />
        <StatCard
          icon={<IconNews />}
          label="日报"
          value={String(stats?.reports ?? 0)}
          hint={stats?.latestReportKey ? `最新 ${stats.latestReportKey}` : '尚未成刊'}
          tone="violet"
        />
      </div>

      <div className="rounded-lg border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-stone-500">流水线状态</h2>
        <div className="mt-3 flex flex-wrap gap-2 text-xs">
          {Object.entries(stats?.episodes ?? {}).map(([status, count]) => (
            <span
              key={status}
              className={`rounded-full px-2.5 py-1 ${STATUS_CHIP[status] ?? 'bg-stone-100 text-stone-600'}`}
            >
              {STATUS_LABEL[status] ?? status}：{count}
            </span>
          ))}
          {episodeTotal === 0 && (
            <span className="text-stone-400">还没有单集，先去订阅源页添加一个播客。</span>
          )}
        </div>
      </div>

      <div className="flex flex-wrap gap-3">
        <button
          onClick={() => run('report', () => adminSend('/reports/generate', 'POST'), '日报生成任务已提交，稍后可在「日报」页查看')}
          disabled={busy !== null}
          className="rounded-md bg-ink px-4 py-2 text-sm font-medium text-paper transition-colors hover:bg-vermilion disabled:opacity-50"
        >
          {busy === 'report' ? '提交中…' : '生成昨日日报'}
        </button>
        <a
          href="/admin/sources"
          className="rounded-md border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50"
        >
          管理订阅源
        </a>
      </div>
    </div>
  );
}

const STATUS_LABEL: Record<string, string> = {
  pending: '待处理',
  downloading: '下载中',
  converting: '转码中',
  transcribing: '转写中',
  analyzing: '分析中',
  done: '完成',
  failed: '失败',
  skipped: '跳过',
};

const STATUS_CHIP: Record<string, string> = {
  done: 'bg-emerald-50 text-emerald-700',
  failed: 'bg-red-50 text-red-700',
  skipped: 'bg-stone-100 text-stone-400',
  pending: 'bg-stone-100 text-stone-600',
  downloading: 'bg-blue-50 text-blue-700',
  converting: 'bg-blue-50 text-blue-700',
  transcribing: 'bg-amber-50 text-amber-700',
  analyzing: 'bg-violet-50 text-violet-700',
};

const TONE_CLASSES: Record<string, string> = {
  emerald: 'bg-emerald-50 text-emerald-600',
  blue: 'bg-blue-50 text-blue-600',
  amber: 'bg-amber-50 text-amber-600',
  violet: 'bg-violet-50 text-violet-600',
};

function StatCard({
  icon,
  label,
  value,
  hint,
  tone,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  hint: string;
  tone: keyof typeof TONE_CLASSES;
}) {
  return (
    <div className="rounded-lg border border-stone-200 bg-white p-4">
      <div className="flex items-center justify-between">
        <span className="text-xs text-stone-400">{label}</span>
        <span className={`flex h-7 w-7 items-center justify-center rounded-md ${TONE_CLASSES[tone]}`}>{icon}</span>
      </div>
      <div className="mt-2 text-2xl font-bold text-ink">{value}</div>
      <div className="mt-0.5 text-[11px] text-stone-400">{hint}</div>
    </div>
  );
}

function IconRadio() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="2" />
      <path d="M4.9 19.1a10 10 0 0 1 0-14.2M7.8 16.2a6 6 0 0 1 0-8.4M16.2 7.8a6 6 0 0 1 0 8.4M19.1 4.9a10 10 0 0 1 0 14.2" />
    </svg>
  );
}

function IconDisc() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <circle cx="12" cy="12" r="4" />
    </svg>
  );
}

function IconCheck() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}

function IconNews() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-4 0V9" />
      <path d="M18 14h-8M15 18h-5M10 6h8v4h-8V6Z" />
    </svg>
  );
}
