import { useEffect, useRef } from 'react';
import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { SITE } from '@sonde/industry';

import { BackToTop } from '~/components/BackToTop.tsx';
import { IconSearch } from '~/components/icons.tsx';
import { TimelineFeed } from '~/components/TimelineFeed.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { buildTimelineHref, episodesApiPath, parseTimelineQuery, type TimelineQuery } from '~/lib/timeline.ts';
import type { CategoriesList, EpisodesPage, SourcesList } from '~/lib/types.ts';

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

// 60 秒内浏览器不再回源(时间线的「分钟级」观感来自这里 + api 的 60s 层);
// 无 CDN 下 SSR 每请求照跑,s-maxage 为将来套 CDN 预留 —— aihot 首页同款策略。
export const headers = () => ({ 'Cache-Control': 'public, max-age=60, s-maxage=60' });

export async function loader({ request }: { request: Request }) {
  // page 一律忽略:时间线已是无限滚动,始终从第 1 页起(遗留 ?page= 链接静默回落)
  const { source, category, q } = parseTimelineQuery(new URL(request.url));
  const [sources, categories, feed] = await Promise.all([
    // 源列表只在按源筛选时才需要(给激活 chip 显示播客名);分类 chips 走 /site/categories
    source ? apiGet<SourcesList>('/site/sources') : Promise.resolve(null),
    apiGet<CategoriesList>('/site/categories'),
    apiGet<EpisodesPage>(episodesApiPath({ page: 1, source, category, q })),
  ]);
  return { sources, categories, feed, source, category, q };
}

export default function Timeline() {
  const { sources, categories, feed, source, category, q } = useLoaderData<typeof loader>();
  const items = feed?.items ?? [];
  const hasMore = feed?.hasMore ?? false;
  const total = feed?.total ?? null;
  const sourceItems = sources?.items ?? [];
  const categoryItems = categories?.items ?? [];
  const searchRef = useRef<HTMLInputElement>(null);
  const current: TimelineQuery = { page: 1, source, category, q };

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

  const chipClass = (active: boolean) =>
    `flex flex-none items-center gap-1.5 rounded-full border px-3 py-1 text-xs transition-colors ${
      active
        ? 'border-vermilion font-medium text-vermilion'
        : 'border-stone-300 text-stone-500 hover:border-stone-400 hover:text-ink'
    }`;

  const hasFilters = Boolean(source || category || q);
  const activeSource = source ? sourceItems.find((s) => s.id === source) : undefined;
  const filterLabel = [category, activeSource?.name, q ? `“${q}”` : null].filter(Boolean).join(' · ');

  return (
    // @container:时间线的窄态切换看"内容列实际宽度"而非视口(侧栏展开会挤窄主栏)
    <div className="@container space-y-10 pt-8 pb-4">
      {categoryItems.length === 0 ? (
        /* 还没有任何已发布单集:等待榜单同步与首抓(筛选与搜索此时无意义) */
        <div className="border border-dashed border-stone-300 bg-white/50 px-6 py-14 text-center text-stone-400">
          <p className="font-serif text-lg font-semibold text-stone-500">时间线还是空的</p>
          <p className="mt-2 text-sm leading-relaxed">
            订阅由 xyzrank 中文播客榜自动同步——启动时与每天凌晨四点接入前一千名，
            <br className="hidden sm:block" />
            worker 会按源间隔自动抓取，新单集就会陆续出现在这里。
          </p>
        </div>
      ) : (
        <>
          {/* 筛选与搜索:原生 GET 表单(SSR 即可用),chips 走 Link 保留搜索词 */}
          <section aria-label="筛选与搜索">
            <form method="get" action="/" className="flex max-w-xl gap-2">
              {source ? <input type="hidden" name="source" value={source} /> : null}
              {category ? <input type="hidden" name="category" value={category} /> : null}
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

            {/* 一级分类 chips:点分类清 source 保 q;「全部」清 source+category 保 q。
                顶级不再列具体播客(千榜订阅收不拢)—— 直达靠点时间线里的播客名与搜索。 */}
            <nav className="mt-3 flex flex-wrap gap-2" aria-label="按分类筛选">
              <Link
                to={buildTimelineHref(current, { source: null, category: null })}
                className={chipClass(!source && !category)}
              >
                全部
              </Link>
              {activeSource && (
                <Link
                  to={buildTimelineHref(current, { source: null })}
                  className={chipClass(true)}
                  title="取消按播客筛选(保留分类与搜索)"
                >
                  {activeSource.name}
                  <span aria-hidden="true">✕</span>
                  <span className="sr-only">取消按播客筛选</span>
                </Link>
              )}
              {categoryItems.map((c) => (
                <Link
                  key={c.name}
                  to={buildTimelineHref(current, { source: null, category: c.name })}
                  className={chipClass(!source && category === c.name)}
                >
                  {c.name}
                  <span className="tabular-nums opacity-60">{c.episodeCount}</span>
                </Link>
              ))}
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
              key={`${source ?? 'all'}|${category ?? ''}|${q ?? ''}`}
              initialItems={items}
              initialHasMore={hasMore}
              source={source}
              category={category}
              q={q}
            />
          )}
        </>
      )}

      <BackToTop />
    </div>
  );
}
