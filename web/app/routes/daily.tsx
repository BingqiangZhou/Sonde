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
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">日报归档</h1>
        <p className="mt-2 text-xs tracking-widest text-stone-400">每天 08:00（北京时间）自动成刊</p>
      </header>
      {archive.length === 0 ? (
        <p className="mt-12 border border-dashed border-stone-300 bg-white/50 py-12 text-center text-stone-400">
          还没有已生成的日报。
        </p>
      ) : (
        <ul className="mt-8 divide-y divide-stone-200 border-y border-stone-300">
          {archive.map((entry) => (
            <li key={entry.reportKey}>
              <Link
                to={`/daily/${entry.reportKey}`}
                className="group flex items-center justify-between px-2 py-4 hover:bg-white"
              >
                <span className="font-serif text-lg font-semibold group-hover:text-vermilion">
                  {formatDate(entry.reportKey)}
                </span>
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
