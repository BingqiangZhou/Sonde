import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { apiGet } from '~/lib/api.server.ts';
import { formatDate } from '~/lib/format.ts';

export const meta: MetaFunction = () => [{ title: '日报归档 — 声读' }];

interface ArchiveResponse {
  keys: { reportKey: string; generatedAt: string; revision: number }[];
  total: number;
}

export async function loader() {
  const archive = await apiGet<ArchiveResponse>('/site/reports/daily?size=60');
  return { archive: archive?.keys ?? [] };
}

export default function Daily() {
  const { archive } = useLoaderData<typeof loader>();
  return (
    <section className="py-8">
      <h1 className="text-2xl font-bold text-stone-900">播客日报</h1>
      <p className="mt-2 text-sm text-stone-500">每天 08:00（北京时间）自动成刊。</p>
      {archive.length === 0 ? (
        <p className="mt-10 text-center text-stone-400">还没有已生成的日报。</p>
      ) : (
        <ul className="mt-6 divide-y divide-stone-100 rounded-lg border border-stone-200 bg-white">
          {archive.map((entry) => (
            <li key={entry.reportKey}>
              <Link
                to={`/daily/${entry.reportKey}`}
                className="flex items-center justify-between px-5 py-3.5 hover:bg-stone-50"
              >
                <span className="font-medium text-stone-900">{formatDate(entry.reportKey)}</span>
                <span className="text-xs text-stone-400">
                  {entry.revision > 1 ? `第 ${entry.revision} 版 · ` : ''}
                  {formatDate(entry.generatedAt)} 生成
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
