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
      <section className="py-20 text-center text-stone-500">
        <p className="font-serif text-xl">单集不存在或未入选。</p>
        <Link to="/" className="mt-4 inline-block text-sm text-stone-400 hover:text-vermilion">
          ← 返回首页
        </Link>
      </section>
    );
  }

  return (
    <article className="py-8">
      <div className="flex items-center gap-2 text-xs text-stone-400">
        <span className="rounded-sm border border-stone-300 px-1.5 py-px text-stone-500">
          {episode.categoryLabel}
        </span>
        <span>{episode.podcast}</span>
        <span aria-hidden>·</span>
        <span>{formatDate(episode.publishedAt)}</span>
        {formatDuration(episode.durationSeconds) && (
          <>
            <span aria-hidden>·</span>
            <span>{formatDuration(episode.durationSeconds)}</span>
          </>
        )}
      </div>

      <h1 className="mt-4 font-serif text-3xl font-bold leading-snug">{episode.titleZh || episode.originalTitle}</h1>
      {episode.titleZh && episode.originalTitle && (
        <p className="mt-2 text-sm text-stone-400">原标题：{episode.originalTitle}</p>
      )}

      <div className="rule-double mt-6" />

      <div className="mt-8 grid gap-6 sm:grid-cols-[1fr_9rem]">
        <div>
          <h2 className="font-serif text-sm font-bold tracking-widest text-vermilion">本期摘要</h2>
          <p className="mt-4 text-[15px] leading-loose text-stone-700">{episode.summaryZh}</p>
          <p className="mt-6 border-t border-dashed border-stone-200 pt-4 text-xs leading-relaxed text-stone-400">
            <span className="text-vermilion">▲</span> 为什么值得听：{episode.reasonZh}
          </p>
        </div>
        <aside className="flex flex-col items-start gap-4 sm:items-end">
          <div className="text-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-full border-2 border-vermilion font-serif text-2xl font-bold text-vermilion">
              {episode.score}
            </div>
            <p className="mt-1.5 text-[11px] tracking-widest text-stone-400">注意力价值分</p>
          </div>
          {episode.url && (
            <a
              href={episode.url}
              target="_blank"
              rel="noreferrer"
              className="rounded-md bg-ink px-4 py-2 text-xs font-medium text-paper transition-colors hover:bg-vermilion"
            >
              去原始单集 ↗
            </a>
          )}
        </aside>
      </div>

      <div className="rule-double mt-12 pt-4 text-center">
        <Link to="/" className="text-sm text-stone-400 hover:text-vermilion">
          ← 返回首页
        </Link>
      </div>
    </article>
  );
}
