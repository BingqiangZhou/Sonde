import { useEffect, useRef } from 'react';
import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { SITE } from '@sonde/industry';

import { BackToTop } from '~/components/BackToTop.tsx';
import { IconSearch } from '~/components/icons.tsx';
import { TimelineFeed } from '~/components/TimelineFeed.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { episodesApiPath, parseTimelineQuery } from '~/lib/timeline.ts';
import type { EpisodesPage, SourcesList } from '~/lib/types.ts';

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

export async function loader({ request }: { request: Request }) {
  // page 一律忽略:时间线已是无限滚动,始终从第 1 页起(遗留 ?page= 链接静默回落)
  const { source, q } = parseTimelineQuery(new URL(request.url));
  const [sources, feed] = await Promise.all([
    apiGet<SourcesList>('/site/sources'),
    apiGet<EpisodesPage>(episodesApiPath({ page: 1, source, q })),
  ]);
  return { sources, feed, source, q };
}

export default function Timeline() {
  const { sources, feed, source, q } = useLoaderData<typeof loader>();
  const items = feed?.items ?? [];
  const hasMore = feed?.hasMore ?? false;
  const total = feed?.total ?? null;
  const sourceItems = sources?.items ?? [];
  const searchRef = useRef<HTMLInputElement>(null);

  // "/" 快捷聚焦搜索框(已在输入框内时不抢)
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== '/' || event.ctrlKey || event.metaKey || event.altKey) {
        return;
      }
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) {
        return;
      }
      const input = searchRef.current;
      if (input) {
        event.preventDefault();
        input.focus();
        input.select();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  /** 生成保留筛选上下文的站内链接:source/q 缺省沿用当前值 */
  const buildHref = (next: { source?: number | null; q?: string | null }) => {
    const nextSource = next.source !== undefined ? next.source : source;
    const nextQ = next.q !== undefined ? next.q : q;
    const params = new URLSearchParams();
    if (nextSource) {
      params.set('source', String(nextSource));
    }
    if (nextQ) {
      params.set('q', nextQ);
    }
    const search = params.toString();
    return search ? `/?${search}` : '/';
  };

  const chipClass = (active: boolean) =>
    `flex flex-none items-center gap-1.5 rounded-full border px-3 py-1 text-xs transition-colors ${
      active
        ? 'border-vermilion font-medium text-vermilion'
        : 'border-stone-300 text-stone-500 hover:border-stone-400 hover:text-ink'
    }`;

  const hasFilters = Boolean(source || q);
  const activeSource = source ? sourceItems.find((s) => s.id === source) : undefined;
  const filterLabel = [activeSource?.name, q ? `“${q}”` : null].filter(Boolean).join(' · ');

  // chips 封顶:订阅源可达上千,按单集数(API 已倒序)只显前 20 个;
  // 当前选中的源若在 20 名外,强制追加以保持筛选可见;其余靠搜索框触达。
  const MAX_CHIPS = 20;
  const chipsSources = sourceItems.slice(0, MAX_CHIPS);
  if (source && !chipsSources.some((s) => s.id === source)) {
    const active = sourceItems.find((s) => s.id === source);
    if (active) {
      chipsSources.push(active);
    }
  }
  const hiddenChips = sourceItems.length - chipsSources.length;

  return (
    // @container:时间线的窄态切换看"内容列实际宽度"而非视口(侧栏展开会挤窄主栏)
    <div className="@container space-y-10 pt-8 pb-4">
      {sourceItems.length === 0 ? (
        /* 还没有任何订阅:引导接入(筛选与搜索此时无意义) */
        <div className="border border-dashed border-stone-300 bg-white/50 px-6 py-14 text-center text-stone-400">
          <p className="font-serif text-lg font-semibold text-stone-500">时间线还是空的</p>
          <p className="mt-2 text-sm leading-relaxed">
            在 industry/sources.json 里添加播客订阅并运行 npm run db:seed，
            <br className="hidden sm:block" />
            worker 会按源间隔自动抓取，新单集就会出现在这里。
          </p>
        </div>
      ) : (
        <>
          {/* 筛选与搜索:原生 GET 表单(SSR 即可用),chips 走 Link 保留搜索词 */}
          <section aria-label="筛选与搜索">
            <form method="get" action="/" className="flex gap-2">
              {source ? <input type="hidden" name="source" value={source} /> : null}
              <div className="relative min-w-0 flex-1">
                <span
                  className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-stone-400"
                  aria-hidden="true"
                >
                  <IconSearch size={15} />
                </span>
                <input
                  ref={searchRef}
                  type="search"
                  name="q"
                  defaultValue={q ?? ''}
                  maxLength={100}
                  placeholder="搜索标题与简介,按 / 聚焦"
                  aria-label="搜索标题与简介"
                  className="h-9 w-full rounded-md border border-stone-300 bg-white/60 pl-8 pr-3 text-sm outline-none placeholder:text-stone-400 focus:border-vermilion"
                />
              </div>
              <button
                type="submit"
                className="h-9 flex-none rounded-md border border-stone-300 px-3 text-sm text-stone-500 hover:border-vermilion hover:text-vermilion"
              >
                搜索
              </button>
            </form>

            <nav className="tl-chips -mx-4 mt-3 flex gap-2 overflow-x-auto px-4" aria-label="按播客筛选">
              <Link to={buildHref({ source: null })} className={chipClass(!source)}>
                全部
              </Link>
              {chipsSources.map((s) => (
                <Link key={s.id} to={buildHref({ source: s.id })} className={chipClass(source === s.id)}>
                  {s.name}
                  <span className="tabular-nums opacity-60">{s.episodeCount}</span>
                </Link>
              ))}
              {hiddenChips > 0 && (
                <span className="flex flex-none items-center px-1 text-xs text-stone-400" title="其余订阅源请用搜索筛选">
                  …还有 {hiddenChips} 个
                </span>
              )}
            </nav>

            {hasFilters && (
              <p className="mt-3 text-xs text-stone-400">
                {filterLabel} · 共 {total ?? items.length} 集
                <Link to="/" className="ml-2 text-stone-500 underline underline-offset-2 hover:text-vermilion">
                  清除筛选
                </Link>
              </p>
            )}
          </section>

          {/* 更新时间线:按日分组 + 无限滚动,首批来自 SSR,追加批客户端拉取。
              key 随筛选变化:换筛选即重挂载,追加状态整体复位。 */}
          {items.length === 0 ? (
            <div className="border border-dashed border-stone-300 bg-white/50 px-6 py-12 text-center text-stone-400">
              <p className="font-serif text-lg font-semibold text-stone-500">没有匹配的单集</p>
              <p className="mt-2 text-sm leading-relaxed">
                换个关键词，或清除筛选看看全部更新。
              </p>
              <Link
                to="/"
                className="mt-3 inline-block text-sm text-stone-500 underline underline-offset-2 hover:text-vermilion"
              >
                清除筛选
              </Link>
            </div>
          ) : (
            <TimelineFeed
              key={`${source ?? 'all'}|${q ?? ''}`}
              initialItems={items}
              initialHasMore={hasMore}
              source={source}
              q={q}
            />
          )}
        </>
      )}

      <BackToTop />
    </div>
  );
}
