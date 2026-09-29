import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { FavoriteButton } from '~/components/FavoriteButton.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { formatDate, formatDuration } from '~/lib/format.ts';
import type { AnalyzedEpisodeItem } from '~/lib/types.ts';

export const meta: MetaFunction = () => [{ title: '全部动态 — 声读' }];

interface AllFeedResponse {
  items: AnalyzedEpisodeItem[];
  total: number;
  page: number;
  pages: number;
}

export async function loader({ request }: { request: Request }) {
  const url = new URL(request.url);
  const page = Math.max(1, Number.parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
  const feed = await apiGet<AllFeedResponse>(`/site/episodes/all?page=${page}`);
  return { feed, page };
}

export default function AllFeed() {
  const { feed, page } = useLoaderData<typeof loader>();
  const items = feed?.items ?? [];
  const total = feed?.total ?? 0;
  const pages = feed?.pages ?? 1;

  return (
    <section className="py-8">
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">全部动态</h1>
        <p className="mt-2 text-xs tracking-widest text-stone-400">
          每一集都经过评分 · 共 {total} 集（含未入选）
        </p>
      </header>

      {items.length === 0 ? (
        <p className="mt-12 border border-dashed border-stone-300 bg-white/50 py-12 text-center text-stone-400">
          还没有已分析的单集。
        </p>
      ) : (
        <ul className="mt-8 divide-y divide-stone-200 border-y border-stone-300">
          {items.map((item) => (
            <li key={item.id} className={`py-4 hover:bg-white ${item.selected ? '' : 'opacity-80'}`}>
              <div className="flex items-center gap-2 text-xs text-stone-400">
                <span className="rounded-sm border border-stone-300 px-1.5 py-px text-stone-500">
                  {item.categoryLabel}
                </span>
                <span>{item.podcast}</span>
                <span aria-hidden>·</span>
                <span>{formatDate(item.publishedAt)}</span>
                {formatDuration(item.durationSeconds) && (
                  <>
                    <span aria-hidden>·</span>
                    <span>{formatDuration(item.durationSeconds)}</span>
                  </>
                )}
                <span
                  className={`ml-auto inline-flex items-center gap-1 rounded-full px-2 py-0.5 font-serif text-sm font-semibold ${
                    item.selected ? 'bg-vermilion/10 text-vermilion' : 'bg-stone-100 text-stone-400'
                  }`}
                  title={item.selected ? `入选（评分 ${item.score}）` : `未入选（评分 ${item.score}）`}
                >
                  {item.score}
                  {item.selected && <span className="text-[10px]">★</span>}
                </span>
                {item.selected && (
                  <FavoriteButton
                    episode={{
                      id: item.id,
                      title: item.titleZh || item.originalTitle,
                      podcast: item.podcast,
                      url: item.url,
                    }}
                    variant="icon"
                  />
                )}
              </div>

              {item.selected ? (
                <>
                  <Link
                    to={`/episodes/${item.id}`}
                    className="group mt-1.5 block font-serif text-lg font-semibold leading-snug group-hover:text-vermilion hover:text-vermilion"
                  >
                    {item.titleZh || item.originalTitle}
                  </Link>
                  <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-stone-500">
                    {item.summaryZh || item.reason}
                  </p>
                </>
              ) : (
                <>
                  <div className="mt-1.5 font-serif text-lg font-semibold leading-snug text-stone-500">
                    {item.originalTitle}
                    {item.url && (
                      <a
                        href={item.url}
                        target="_blank"
                        rel="noreferrer"
                        className="ml-2 align-middle text-xs font-normal text-stone-400 hover:text-vermilion"
                      >
                        原始单集 ↗
                      </a>
                    )}
                  </div>
                  <p className="mt-1 text-sm leading-relaxed text-stone-400">
                    <span className="mr-1.5 rounded-sm bg-stone-100 px-1 py-px text-[11px] text-stone-500">
                      未入选
                    </span>
                    {item.reason}
                  </p>
                </>
              )}
            </li>
          ))}
        </ul>
      )}

      {pages > 1 && (
        <nav className="mt-8 flex items-center justify-between text-sm">
          {page > 1 ? (
            <Link to={`/all?page=${page - 1}`} className="text-stone-500 hover:text-vermilion">
              ← 上一页
            </Link>
          ) : (
            <span className="text-stone-300">← 上一页</span>
          )}
          <span className="text-xs text-stone-400">
            第 {page} / {pages} 页
          </span>
          {page < pages ? (
            <Link to={`/all?page=${page + 1}`} className="text-stone-500 hover:text-vermilion">
              下一页 →
            </Link>
          ) : (
            <span className="text-stone-300">下一页 →</span>
          )}
        </nav>
      )}
    </section>
  );
}
