import { useEffect, useMemo, useRef, useState } from 'react';
import { useFetcher } from 'react-router';

import { IconWave } from '~/components/icons.tsx';
import { currentShanghaiYear, formatDuration, formatTimelineStamp } from '~/lib/format.ts';
import { groupTimelineDays } from '~/lib/timeline.ts';
import type { EpisodeListItem, EpisodesBatch } from '~/lib/types.ts';
import { safeHttpUrl } from '~/lib/url.ts';

/** 追加批的请求地址(筛选随行,q 由 URLSearchParams 编码)。 */
function batchHref(page: number, source: number | null, q: string | null): string {
  const params = new URLSearchParams();
  params.set('page', String(page));
  if (source) {
    params.set('source', String(source));
  }
  if (q) {
    params.set('q', q);
  }
  return `/resources/episodes?${params.toString()}`;
}

/** 首屏与追加批按 id 去重合并(偏移分页在 worker 插入新单集时会漂移,重复在此吸收)。 */
function mergeDeduped(base: readonly EpisodeListItem[], appended: readonly EpisodeListItem[]): EpisodeListItem[] {
  if (appended.length === 0) {
    return [...base];
  }
  const seen = new Set(base.map((item) => item.id));
  const merged = [...base];
  for (const item of appended) {
    if (!seen.has(item.id)) {
      seen.add(item.id);
      merged.push(item);
    }
  }
  return merged;
}

/** 单集节点:时间左槽(宽容器)+ 书脊圆点 + 封面/衬线标题(外链)/播客·时长 + RSS 简介。
 *  日期由所在日的通栏分隔线承担,这里只标时间;窄容器左槽隐藏,时间回落 meta 行。 */
function TimelineItem({ item }: { item: EpisodeListItem }) {
  const stamp = formatTimelineStamp(item.publishedAt);
  const duration = formatDuration(item.durationSeconds);
  const href = safeHttpUrl(item.url);
  return (
    <li className="timeline-item">
      <div className="tl-date">
        {stamp && (
          <time
            dateTime={item.publishedAt ?? undefined}
            className="block text-xs leading-4 tabular-nums text-stone-400"
          >
            {stamp.time}
          </time>
        )}
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
            {stamp && (
              <>
                <span className="tl-meta-datetime" aria-hidden>
                  ·
                </span>
                <span className="tl-meta-datetime">{stamp.time}</span>
              </>
            )}
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

/** 更新时间线:按日分组渲染 + 无限滚动。
 *  首批来自 SSR loader;追加批经 /resources/episodes 资源路由由 useFetcher 拉取,
 *  哨兵进入视口上方约 800px 即预载。筛选变更由父组件换 key 重挂载,状态整体复位。 */
export function TimelineFeed({
  initialItems,
  initialHasMore,
  source,
  q,
}: {
  initialItems: EpisodeListItem[];
  initialHasMore: boolean;
  source: number | null;
  q: string | null;
}) {
  // 仅客户端、仅 mount 后变更——服务端 HTML 与水合首帧只用 initialItems
  const [appended, setAppended] = useState<EpisodeListItem[]>([]);
  const [loadedPages, setLoadedPages] = useState(0); // 已并入批数;下一批 = loadedPages + 2
  const [hasMore, setHasMore] = useState(initialHasMore);
  const [failed, setFailed] = useState(false);
  const [intersecting, setIntersecting] = useState(false);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const fetcher = useFetcher<EpisodesBatch>();
  const currentYear = currentShanghaiYear();

  const items = useMemo(() => mergeDeduped(initialItems, appended), [initialItems, appended]);
  const days = useMemo(() => groupTimelineDays(items), [items]);
  const nextPage = loadedPages + 2;

  // 观察:哨兵进入视口上方 800px 即预载;每次重新进入视口都重新武装重试
  // (IO 只在跨越时触发——失败后哨兵不动,不会形成重试风暴)
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) {
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (!entry) {
          return;
        }
        setIntersecting(entry.isIntersecting);
        if (entry.isIntersecting) {
          setFailed(false);
        }
      },
      { rootMargin: '800px 0px 0px 0px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  // 触发:视口内 + 未失败 + 还有更多 + 无在飞请求 + 本页未在飞/未并入
  useEffect(() => {
    if (!intersecting || failed || !hasMore) {
      return;
    }
    if (fetcher.state !== 'idle') {
      return;
    }
    const data = fetcher.data;
    if (data && !data.error && data.page === nextPage) {
      return;
    }
    fetcher.load(batchHref(nextPage, source, q));
  }, [intersecting, failed, hasMore, fetcher, nextPage, source, q]);

  // 并入:只认页号(loadedPages + 2)——陈旧/重复解析天然丢弃,不可能双并入或漏并
  useEffect(() => {
    const data = fetcher.data;
    if (!data || fetcher.state !== 'idle') {
      return;
    }
    if (data.page !== loadedPages + 2) {
      return;
    }
    if (data.error) {
      setFailed(true);
      return;
    }
    setAppended((prev) => prev.concat(data.items));
    setLoadedPages((n) => n + 1);
    setHasMore(data.hasMore);
  }, [fetcher.data, fetcher.state, loadedPages]);

  return (
    <>
      <ol className="timeline" aria-label="更新时间线">
        {days.map((day) => (
          <li key={day.key} className="tl-day">
            <div className="tl-day-head">
              <h2 className="font-serif text-xl font-bold leading-snug">
                {day.year && day.year !== currentYear && (
                  <span className="mr-1 align-middle text-xs font-normal text-stone-400">{day.year}年</span>
                )}
                <time dateTime={day.isoDate ?? undefined}>{day.label}</time>
                {day.weekday && (
                  <span className="ml-2 align-middle text-xs font-normal text-stone-400">· {day.weekday}</span>
                )}
              </h2>
            </div>
            <ol className="tl-items">
              {day.items.map((item) => (
                <TimelineItem key={item.id} item={item} />
              ))}
            </ol>
          </li>
        ))}
      </ol>

      {/* 状态区:加载/失败可重试/到底收尾;均与内容列对齐 */}
      {fetcher.state === 'loading' && (
        <p role="status" className="tl-indent pt-6 text-sm text-stone-400">
          正在载入更早的更新…
        </p>
      )}
      {failed && (
        <p role="status" className="tl-indent pt-6 text-sm text-stone-400">
          载入失败,稍后再试
          <button
            type="button"
            onClick={() => setFailed(false)}
            className="ml-2 underline underline-offset-2 hover:text-vermilion"
          >
            重试
          </button>
        </p>
      )}
      {!hasMore && items.length > 0 && (
        <p className="tl-end mt-8 pt-2 text-center font-serif text-sm text-stone-400">
          <span className="sr-only">已显示全部更新</span>· 完 ·
        </p>
      )}

      {/* 哨兵:始终渲染,进入视口上方 800px 触发预载 */}
      <div ref={sentinelRef} aria-hidden="true" />
    </>
  );
}
