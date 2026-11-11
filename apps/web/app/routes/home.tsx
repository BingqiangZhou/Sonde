import { useEffect, useRef } from 'react';
import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { SITE } from '@sonde/industry';

import { BackToTop } from '~/components/BackToTop.tsx';
import { IconSearch, IconWave } from '~/components/icons.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { currentShanghaiYear, formatDateTime, formatDuration, formatTimelineStamp } from '~/lib/format.ts';
import { safeHttpUrl } from '~/lib/url.ts';
import type { EpisodesPage, EpisodeListItem, SourcesList } from '~/lib/types.ts';

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

export async function loader({ request }: { request: Request }) {
  const url = new URL(request.url);
  const page = Math.max(1, Number.parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
  const sourceParam = Number.parseInt(url.searchParams.get('source') ?? '', 10);
  const source = Number.isInteger(sourceParam) && sourceParam > 0 ? sourceParam : null;
  const q = (url.searchParams.get('q') ?? '').trim().slice(0, 100) || null;
  const episodesPath =
    `/site/episodes?page=${page}` +
    (source ? `&source=${source}` : '') +
    (q ? `&q=${encodeURIComponent(q)}` : '');
  const [sources, feed] = await Promise.all([
    apiGet<SourcesList>('/site/sources'),
    apiGet<EpisodesPage>(episodesPath),
  ]);
  return { sources, feed, page, source, q };
}

/** 单集节点:日期左槽(宽容器)+ 书脊圆点 + 封面/衬线标题(外链)/播客·时长 + RSS 简介。
 *  日期在左槽承担,标题成为节点主语;窄容器(视口窄或被侧栏挤窄)左槽隐藏,日期回落 meta 行。 */
function TimelineItem({ item, currentYear }: { item: EpisodeListItem; currentYear: string }) {
  const stamp = formatTimelineStamp(item.publishedAt);
  const duration = formatDuration(item.durationSeconds);
  const href = safeHttpUrl(item.url);
  return (
    <li className="timeline-item">
      <div className="tl-date">
        {stamp && stamp.year !== currentYear && (
          <span className="block text-xs leading-4 text-stone-400">{stamp.year}年</span>
        )}
        {stamp ? (
          <time dateTime={item.publishedAt ?? undefined} className="block text-sm leading-5 text-stone-500">
            {stamp.date}
          </time>
        ) : (
          <span className="block text-sm leading-5 text-stone-400">日期未知</span>
        )}
        {stamp && <span className="block text-xs leading-4 tabular-nums text-stone-400">{stamp.time}</span>}
      </div>
      <span className="tl-node" aria-hidden="true" />
      <div className="flex min-w-0 gap-4">
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
          {href ? (
            <a
              href={href}
              target="_blank"
              rel="noreferrer"
              className="block font-serif text-lg font-semibold leading-snug hover:text-vermilion"
            >
              {item.title}
              <span className="ml-1.5 align-middle text-xs font-normal text-stone-400" aria-hidden>
                ↗
              </span>
              <span className="sr-only">（在新窗口打开）</span>
            </a>
          ) : (
            <p className="font-serif text-lg font-semibold leading-snug">{item.title}</p>
          )}
          <p className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-stone-400">
            <span className="font-medium text-stone-500">{item.podcast}</span>
            <span className="tl-meta-datetime" aria-hidden>
              ·
            </span>
            <span className="tl-meta-datetime">{formatDateTime(item.publishedAt)}</span>
            {duration && (
              <>
                <span aria-hidden>·</span>
                <span>{duration}</span>
              </>
            )}
          </p>
          {item.shownotes && (
            <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-stone-500">{item.shownotes}</p>
          )}
        </div>
      </div>
    </li>
  );
}

export default function Timeline() {
  const { sources, feed, page, source, q } = useLoaderData<typeof loader>();
  const items = feed?.items ?? [];
  const hasMore = feed?.hasMore ?? false;
  const total = feed?.total ?? null;
  const sourceItems = sources?.items ?? [];
  const currentYear = currentShanghaiYear();
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

  /** 生成保留筛选上下文的站内链接:source/q 缺省沿用当前值,page 缺省回 1 */
  const buildHref = (next: { source?: number | null; q?: string | null; page?: number }) => {
    const nextSource = next.source !== undefined ? next.source : source;
    const nextQ = next.q !== undefined ? next.q : q;
    const nextPage = next.page ?? 1;
    const params = new URLSearchParams();
    if (nextSource) {
      params.set('source', String(nextSource));
    }
    if (nextQ) {
      params.set('q', nextQ);
    }
    if (nextPage > 1) {
      params.set('page', String(nextPage));
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

          {/* 更新时间线:左侧书脊 + 圆点节点,日期在左槽(刊头等站点信息在左侧栏) */}
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
            <ol className="timeline" aria-label="更新时间线">
              {items.map((item) => (
                <TimelineItem key={item.id} item={item} currentYear={currentYear} />
              ))}
            </ol>
          )}

          {/* 翻页:第 2 页起为更早的更新,筛选与搜索参数随行 */}
          {(page > 1 || hasMore) && (
            <nav className="tl-indent flex items-center justify-between text-sm" aria-label="翻页">
              {page > 1 ? (
                <Link to={buildHref({ page: page - 1 })} className="text-stone-500 hover:text-vermilion">
                  ← 较新
                </Link>
              ) : (
                <span className="text-stone-300">← 较新</span>
              )}
              <span className="text-xs text-stone-400">第 {page} 页</span>
              {hasMore ? (
                <Link to={buildHref({ page: page + 1 })} className="text-stone-500 hover:text-vermilion">
                  较早 →
                </Link>
              ) : (
                <span className="text-stone-300">较早 →</span>
              )}
            </nav>
          )}
        </>
      )}

      <BackToTop />
    </div>
  );
}
