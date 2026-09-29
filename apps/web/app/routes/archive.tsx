import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { apiGet } from '~/lib/api.server.ts';
import { formatDate } from '~/lib/format.ts';
import type { EpisodeItem } from '~/lib/types.ts';

export const meta: MetaFunction = () => [{ title: '全部精选 — 声读' }];

export async function loader() {
  const result = await apiGet<{ items: EpisodeItem[] }>('/site/episodes?limit=50');
  return { episodes: result?.items ?? [] };
}

export default function Archive() {
  const { episodes } = useLoaderData<typeof loader>();
  return (
    <section className="py-8">
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">全部精选</h1>
        <p className="mt-2 text-xs tracking-widest text-stone-400">共 {episodes.length} 集</p>
      </header>
      {episodes.length === 0 ? (
        <p className="mt-12 border border-dashed border-stone-300 bg-white/50 py-12 text-center text-stone-400">
          还没有入选的单集。
        </p>
      ) : (
        <ul className="mt-8 divide-y divide-stone-200 border-y border-stone-300">
          {episodes.map((episode) => (
            <li key={episode.id}>
              <Link to={`/episodes/${episode.id}`} className="group block py-4 hover:bg-white">
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
  );
}
