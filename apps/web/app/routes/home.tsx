import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { apiGet } from '~/lib/api.server.ts';
import { formatDate } from '~/lib/format.ts';
import type { DailyReport, EpisodeItem, SiteMeta } from '~/lib/types.ts';

import { SITE } from '@sonde/industry';

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

export async function loader() {
  const [meta, report, episodes] = await Promise.all([
    apiGet<SiteMeta>('/site/meta'),
    apiGet<DailyReport>('/site/reports/daily/latest'),
    apiGet<{ items: EpisodeItem[] }>('/site/episodes?limit=8'),
  ]);
  return { meta, report, episodes: episodes?.items ?? [] };
}

export default function Home() {
  const { meta, report, episodes } = useLoaderData<typeof loader>();
  return (
    <div className="space-y-12">
      <section className="py-10 text-center">
        <h1 className="text-4xl font-bold tracking-wide">{meta?.name ?? SITE.name}</h1>
        <p className="mt-4 text-lg text-stone-500">{meta?.tagline ?? SITE.tagline}</p>
      </section>

      {report ? (
        <section className="rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
          <div className="flex items-baseline justify-between">
            <h2 className="text-sm font-medium text-stone-400">最新日报</h2>
            <Link to={`/daily/${report.reportKey}`} className="text-sm text-stone-500 hover:text-stone-900">
              {formatDate(report.reportKey)}
            </Link>
          </div>
          <h3 className="mt-3 text-xl font-bold text-stone-900">{report.content.title}</h3>
          <p className="mt-2 leading-relaxed text-stone-600">{report.content.leadParagraph}</p>
          <Link
            to={`/daily/${report.reportKey}`}
            className="mt-4 inline-block rounded-md bg-stone-900 px-4 py-2 text-sm font-medium text-white hover:bg-stone-700"
          >
            读完整日报
          </Link>
        </section>
      ) : (
        <section className="rounded-lg border border-dashed border-stone-300 p-8 text-center text-stone-400">
          日报尚未生成。订阅播客后，每天 08:00（北京时间）自动成刊。
        </section>
      )}

      <section>
        <div className="mb-4 flex items-baseline justify-between">
          <h2 className="text-lg font-bold text-stone-900">最近精选</h2>
          <Link to="/archive" className="text-sm text-stone-500 hover:text-stone-900">
            全部 →
          </Link>
        </div>
        {episodes.length === 0 ? (
          <p className="py-6 text-center text-stone-400">还没有入选的单集。</p>
        ) : (
          <ul className="divide-y divide-stone-100 rounded-lg border border-stone-200 bg-white">
            {episodes.map((episode) => (
              <li key={episode.id}>
                <Link to={`/episodes/${episode.id}`} className="block px-5 py-4 hover:bg-stone-50">
                  <div className="flex items-center gap-2 text-xs text-stone-400">
                    <span className="rounded bg-stone-100 px-1.5 py-0.5 text-stone-500">{episode.categoryLabel}</span>
                    <span>{episode.podcast}</span>
                    <span>{formatDate(episode.publishedAt)}</span>
                  </div>
                  <div className="mt-1.5 font-semibold text-stone-900">{episode.titleZh || episode.originalTitle}</div>
                  <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-stone-500">{episode.summaryZh}</p>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
