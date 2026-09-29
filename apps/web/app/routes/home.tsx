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
  const today = new Date().toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  });

  return (
    <div className="space-y-14">
      {/* 刊头（报名板） */}
      <section className="pt-8 text-center">
        <p className="text-xs tracking-[0.35em] text-stone-400">{today}</p>
        <div className="rule-double mt-3 pt-5">
          <h1 className="font-serif text-5xl font-bold tracking-[0.15em]">{meta?.name ?? SITE.name}</h1>
          <p className="mt-3 text-sm tracking-widest text-stone-500">{meta?.tagline ?? SITE.tagline}</p>
        </div>
      </section>

      {/* 最新日报 */}
      {report ? (
        <section className="card-lift relative border border-stone-300 bg-white p-7">
          <span className="absolute -top-2.5 left-6 bg-vermilion px-2 py-0.5 text-[11px] font-medium tracking-widest text-white">
            最新日报
          </span>
          <div className="flex items-baseline justify-between gap-3">
            <Link
              to={`/daily/${report.reportKey}`}
              className="font-serif text-2xl font-bold leading-snug hover:text-vermilion"
            >
              {report.content.title}
            </Link>
            <span className="flex-none font-serif text-sm text-stone-400">{formatDate(report.reportKey)}</span>
          </div>
          <p className="mt-3 leading-loose text-stone-600">{report.content.leadParagraph}</p>
          {report.content.highlights.length > 0 && (
            <ul className="mt-4 space-y-1.5 border-t border-dashed border-stone-200 pt-4 text-sm text-stone-500">
              {report.content.highlights.slice(0, 3).map((highlight, index) => (
                <li key={index} className="flex gap-2">
                  <span className="font-serif text-vermilion">—</span>
                  {highlight}
                </li>
              ))}
            </ul>
          )}
          <Link
            to={`/daily/${report.reportKey}`}
            className="mt-5 inline-block border-b-2 border-vermilion pb-0.5 text-sm font-medium text-ink hover:text-vermilion"
          >
            读完整日报 →
          </Link>
        </section>
      ) : (
        <section className="border border-dashed border-stone-300 bg-white/50 p-10 text-center text-stone-400">
          日报尚未生成。订阅播客后，每天 08:00（北京时间）自动成刊。
        </section>
      )}

      {/* 最近精选 */}
      <section>
        <div className="mb-5 flex items-baseline justify-between">
          <h2 className="font-serif text-xl font-bold">最近精选</h2>
          <Link to="/archive" className="text-sm text-stone-400 hover:text-vermilion">
            全部 →
          </Link>
        </div>
        {episodes.length === 0 ? (
          <p className="border border-dashed border-stone-300 bg-white/50 py-10 text-center text-stone-400">
            还没有入选的单集。
          </p>
        ) : (
          <ul className="divide-y divide-stone-200 border-y border-stone-200">
            {episodes.map((episode) => (
              <li key={episode.id}>
                <Link to={`/episodes/${episode.id}`} className="group block py-4">
                  <div className="flex items-center gap-2 text-xs text-stone-400">
                    <span className="rounded-sm border border-stone-300 px-1.5 py-px text-stone-500">
                      {episode.categoryLabel}
                    </span>
                    <span>{episode.podcast}</span>
                    <span aria-hidden>·</span>
                    <span>{formatDate(episode.publishedAt)}</span>
                    <span className="ml-auto font-serif text-sm font-semibold text-vermilion">{episode.score}</span>
                  </div>
                  <div className="mt-1.5 font-serif text-lg font-semibold leading-snug group-hover:text-vermilion">
                    {episode.titleZh || episode.originalTitle}
                  </div>
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
