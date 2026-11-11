import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { SITE } from '@sonde/industry';

import { IconWave } from '~/components/icons.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { formatDateTime, formatDuration } from '~/lib/format.ts';
import type { EpisodesPage, SiteMeta, EpisodeListItem } from '~/lib/types.ts';

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

export async function loader({ request }: { request: Request }) {
  const url = new URL(request.url);
  const page = Math.max(1, Number.parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
  const [meta, feed] = await Promise.all([
    apiGet<SiteMeta>('/site/meta'),
    apiGet<EpisodesPage>(`/site/episodes?page=${page}`),
  ]);
  return { meta, feed, page };
}

/** 单集条目：封面 + 播客名/时间/时长 + 衬线标题（外链）+ RSS 简介。 */
function EpisodeRow({ item }: { item: EpisodeListItem }) {
  const duration = formatDuration(item.durationSeconds);
  return (
    <li className="py-5">
      <div className="flex gap-4">
        {item.imageUrl ? (
          <img
            src={item.imageUrl}
            alt=""
            loading="lazy"
            className="h-12 w-12 flex-none rounded-sm border border-stone-300 bg-white object-cover"
          />
        ) : (
          <div className="flex h-12 w-12 flex-none items-center justify-center rounded-sm border border-stone-200 bg-white text-stone-300">
            <IconWave size={20} />
          </div>
        )}
        <div className="min-w-0 flex-1">
          <p className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-stone-400">
            <span className="font-medium text-stone-500">{item.podcast}</span>
            <span aria-hidden>·</span>
            <span>{formatDateTime(item.publishedAt)}</span>
            {duration && (
              <>
                <span aria-hidden>·</span>
                <span>{duration}</span>
              </>
            )}
          </p>
          {item.url ? (
            <a
              href={item.url}
              target="_blank"
              rel="noreferrer"
              className="mt-1 block font-serif text-lg font-semibold leading-snug hover:text-vermilion"
            >
              {item.title}
              <span className="ml-1.5 align-middle text-xs font-normal text-stone-400" aria-hidden>
                ↗
              </span>
              <span className="sr-only">（在新窗口打开）</span>
            </a>
          ) : (
            <p className="mt-1 font-serif text-lg font-semibold leading-snug">{item.title}</p>
          )}
          {item.shownotes && (
            <p className="mt-1 line-clamp-3 text-sm leading-relaxed text-stone-500">{item.shownotes}</p>
          )}
        </div>
      </div>
    </li>
  );
}

export default function Timeline() {
  const { meta, feed, page } = useLoaderData<typeof loader>();
  const items = feed?.items ?? [];
  const hasMore = feed?.hasMore ?? false;
  const today = new Date().toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  });

  return (
    <div className="space-y-10 pt-8 pb-4">
      {/* 刊头（报名板） */}
      <section className="text-center">
        <p className="text-xs tracking-[0.35em] text-stone-400">{today}</p>
        <div className="rule-double mt-3 pt-5">
          <h1 className="font-serif text-5xl font-bold tracking-[0.15em]">{meta?.name ?? SITE.name}</h1>
          <p className="mt-3 text-sm tracking-widest text-stone-500">{meta?.tagline ?? SITE.tagline}</p>
        </div>
      </section>

      {/* 更新时间线 */}
      {items.length === 0 ? (
        <div className="border border-dashed border-stone-300 bg-white/50 px-6 py-14 text-center text-stone-400">
          <p className="font-serif text-lg font-semibold text-stone-500">时间线还是空的</p>
          <p className="mt-2 text-sm leading-relaxed">
            在 industry/sources.json 里添加播客订阅并运行 npm run db:seed，
            <br className="hidden sm:block" />
            worker 会按源间隔自动抓取，新单集就会出现在这里。
          </p>
        </div>
      ) : (
        <ul className="divide-y divide-stone-200 border-y border-stone-300">
          {items.map((item) => (
            <EpisodeRow key={item.id} item={item} />
          ))}
        </ul>
      )}

      {/* 翻页：第 2 页起为更早的更新 */}
      {(page > 1 || hasMore) && (
        <nav className="flex items-center justify-between text-sm" aria-label="翻页">
          {page > 1 ? (
            <Link to={`/?page=${page - 1}`} className="text-stone-500 hover:text-vermilion">
              ← 较新
            </Link>
          ) : (
            <span className="text-stone-300">← 较新</span>
          )}
          <span className="text-xs text-stone-400">第 {page} 页</span>
          {hasMore ? (
            <Link to={`/?page=${page + 1}`} className="text-stone-500 hover:text-vermilion">
              较早 →
            </Link>
          ) : (
            <span className="text-stone-300">较早 →</span>
          )}
        </nav>
      )}
    </div>
  );
}
