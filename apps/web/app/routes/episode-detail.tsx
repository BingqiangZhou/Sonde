import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { apiGet } from '~/lib/api.server.ts';
import { formatDate, formatDuration } from '~/lib/format.ts';
import type { EpisodeItem } from '~/lib/types.ts';

export const meta: MetaFunction = () => [
  { title: '单集 — 声读' },
];

export async function loader({ params }: { params: { id: string } }) {
  const detail = await apiGet<{ episode: EpisodeItem }>(`/site/episodes/${params.id}`);
  return { episode: detail?.episode ?? null };
}

export default function EpisodeDetail() {
  const { episode } = useLoaderData<typeof loader>();

  if (!episode) {
    return (
      <section className="py-16 text-center text-stone-500">
        <p>单集不存在或未入选。</p>
        <Link to="/" className="mt-3 inline-block text-sm text-stone-400 hover:text-stone-600">
          ← 返回首页
        </Link>
      </section>
    );
  }

  return (
    <article className="py-8">
      <div className="flex items-center gap-2 text-xs text-stone-400">
        <span className="rounded bg-stone-100 px-1.5 py-0.5 text-stone-500">{episode.categoryLabel}</span>
        <span>{episode.podcast}</span>
        <span>{formatDate(episode.publishedAt)}</span>
        {formatDuration(episode.durationSeconds) && <span>{formatDuration(episode.durationSeconds)}</span>}
        <span className="rounded-full bg-emerald-50 px-2 py-0.5 font-medium text-emerald-700">
          评分 {episode.score}
        </span>
      </div>

      <h1 className="mt-4 text-2xl font-bold leading-snug text-stone-900">
        {episode.titleZh || episode.originalTitle}
      </h1>
      {episode.titleZh && episode.originalTitle && (
        <p className="mt-1.5 text-sm text-stone-400">原标题：{episode.originalTitle}</p>
      )}

      <div className="mt-6 rounded-lg border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-stone-500">摘要</h2>
        <p className="mt-3 leading-relaxed text-stone-700">{episode.summaryZh}</p>
        <p className="mt-4 border-t border-stone-100 pt-3 text-xs text-stone-400">
          为什么值得听：{episode.reasonZh}
        </p>
      </div>

      {episode.url && (
        <a
          href={episode.url}
          target="_blank"
          rel="noreferrer"
          className="mt-6 inline-block rounded-md border border-stone-300 px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-100"
        >
          去原始单集 ↗
        </a>
      )}

      <div className="mt-10">
        <Link to="/" className="text-sm text-stone-400 hover:text-stone-600">
          ← 返回首页
        </Link>
      </div>
    </article>
  );
}
