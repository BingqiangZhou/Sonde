import { Link, useLoaderData, useRevalidator } from 'react-router';
import { useState } from 'react';

import { adminSend } from '~/lib/admin-api.ts';
import { apiGet } from '~/lib/api.server.ts';
import { formatDate } from '~/lib/format.ts';

export async function loader({ request }: { request: Request }) {
  return { archive: (await apiGet<{ keys: { reportKey: string; revision: number }[] }>('/site/reports/daily?size=60'))?.keys ?? [] };
}

export default function AdminReports() {
  const { archive } = useLoaderData<typeof loader>();
  const revalidator = useRevalidator();
  const [key, setKey] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function generate(reportKey?: string) {
    setBusy(true);
    setMessage(null);
    try {
      await adminSend('/reports/generate', 'POST', reportKey ? { reportKey } : {});
      setMessage(`日报生成任务已提交（${reportKey ?? '昨日'}），稍后刷新查看`);
      revalidator.revalidate();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : '操作失败');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-6 space-y-5">
      <section className="flex flex-wrap items-center gap-3 rounded-lg border border-stone-200 bg-white p-5">
        <input
          type="date"
          value={key}
          onChange={(e) => setKey(e.target.value)}
          className="rounded-md border border-stone-300 px-3 py-2 text-sm"
        />
        <button
          onClick={() => generate(key || undefined)}
          disabled={busy}
          className="rounded-md bg-stone-900 px-4 py-2 text-sm font-medium text-white hover:bg-stone-700 disabled:opacity-50"
        >
          {busy ? '提交中…' : key ? `生成 ${key} 的日报` : '生成昨日日报'}
        </button>
        {message && <span className="text-xs text-stone-500">{message}</span>}
      </section>

      {archive.length === 0 ? (
        <p className="py-6 text-center text-stone-400">还没有已生成的日报。</p>
      ) : (
        <ul className="divide-y divide-stone-100 rounded-lg border border-stone-200 bg-white">
          {archive.map((entry) => (
            <li key={entry.reportKey} className="flex items-center justify-between px-4 py-3">
              <Link to={`/daily/${entry.reportKey}`} className="font-medium text-stone-900 hover:underline">
                {formatDate(entry.reportKey)}
              </Link>
              <div className="flex items-center gap-3 text-xs">
                {entry.revision > 1 && <span className="text-stone-400">第 {entry.revision} 版</span>}
                <button
                  onClick={() => generate(entry.reportKey)}
                  disabled={busy}
                  className="text-stone-600 underline hover:text-stone-900 disabled:opacity-50"
                >
                  重新生成
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
