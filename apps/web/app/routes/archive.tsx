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
      <h1 className="text-2xl font-bold text-stone-900">全部精选</h1>
      {episodes.length === 0 ? (
        <p className="mt-10 text-center text-stone-400">还没有入选的单集。</p>
      ) : (
        <ul className="mt-6 divide-y divide-stone-100 rounded-lg border border-stone-200 bg-white">
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
  );
}
