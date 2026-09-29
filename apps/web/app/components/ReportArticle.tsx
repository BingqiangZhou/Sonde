/** 报刊正文（日报/周报/月报共用）：报头 + 看点 + 分节条目 + 归档回链。 */

import { Link } from 'react-router';

import { FavoriteButton } from './FavoriteButton.tsx';
import { formatDuration, formatMonthKey, formatWeekRange } from '~/lib/format.ts';
import type { DailyReport, ReportKind } from '~/lib/types.ts';

const KIND_META: Record<ReportKind, {
  masthead: string;
  highlightsLabel: string;
  archiveLabel: string;
  archiveTo: string;
  keyLabel: (key: string) => string;
}> = {
  daily: {
    masthead: '声读日报 · SONDE DAILY',
    highlightsLabel: '今日看点',
    archiveLabel: '日报归档',
    archiveTo: '/daily',
    keyLabel: (key) => {
      const weekday = new Date(`${key}T12:00:00+08:00`).toLocaleDateString('zh-CN', { weekday: 'long' });
      return `${key} · ${weekday}`;
    },
  },
  weekly: {
    masthead: '声读周报 · SONDE WEEKLY',
    highlightsLabel: '一周看点',
    archiveLabel: '周报归档',
    archiveTo: '/weekly',
    keyLabel: (key) => `${formatWeekRange(key)} 这一周`,
  },
  monthly: {
    masthead: '声读月报 · SONDE MONTHLY',
    highlightsLabel: '本月看点',
    archiveLabel: '月报归档',
    archiveTo: '/monthly',
    keyLabel: (key) => formatMonthKey(key),
  },
};

export function ReportArticle({ report, kind }: { report: DailyReport; kind: ReportKind }) {
  const meta = KIND_META[kind];
  const { content } = report;

  return (
    <article className="py-6">
      {/* 报头 */}
      <header className="text-center">
        <div className="rule-double pb-3">
          <p className="font-serif text-sm tracking-[0.4em] text-stone-500">{meta.masthead}</p>
        </div>
        <p className="mt-3 text-xs tracking-widest text-stone-400">
          {meta.keyLabel(report.reportKey)}
          {report.revision > 1 && <span className="ml-2">第 {report.revision} 版</span>}
        </p>
        <h1 className="mx-auto mt-5 max-w-xl font-serif text-3xl font-bold leading-snug">
          {content.title}
        </h1>
        <p className="mx-auto mt-4 max-w-lg leading-loose text-stone-600">{content.leadParagraph}</p>
        <div className="rule-double mt-6" />
      </header>

      {/* 看点 */}
      {content.highlights.length > 0 && (
        <section className="mt-8 border border-stone-300 bg-white p-6">
          <h2 className="font-serif text-sm font-bold tracking-widest text-vermilion">{meta.highlightsLabel}</h2>
          <ol className="mt-4 space-y-2.5">
            {content.highlights.map((highlight, index) => (
              <li key={index} className="flex gap-3 text-sm leading-relaxed text-stone-700">
                <span className="flex h-6 w-6 flex-none items-center justify-center rounded-full border border-vermilion font-serif text-xs font-bold text-vermilion">
                  {index + 1}
                </span>
                {highlight}
              </li>
            ))}
          </ol>
        </section>
      )}

      {/* 分节条目 */}
      {content.sections.map((section) => (
        <section key={section.section} className="mt-12">
          <div className="flex items-center gap-3">
            <h2 className="font-serif text-xl font-bold">{section.section}</h2>
            <span className="h-px flex-1 bg-stone-300" />
            <span className="text-xs text-stone-400">{section.items.length} 集</span>
          </div>
          <ul className="mt-5 space-y-5">
            {section.items.map((item) => (
              <li
                key={item.episodeId}
                className="card-lift border border-stone-200 bg-white p-5"
              >
                <div className="flex items-center gap-2 text-xs text-stone-400">
                  <span className="rounded-sm border border-stone-300 px-1.5 py-px text-stone-500">
                    {item.categoryLabel}
                  </span>
                  <span>{item.podcast}</span>
                  {formatDuration(item.durationSeconds) && (
                    <>
                      <span aria-hidden>·</span>
                      <span>{formatDuration(item.durationSeconds)}</span>
                    </>
                  )}
                  <span className="ml-auto font-serif text-sm font-semibold text-vermilion">{item.score}</span>
                  <FavoriteButton
                    episode={{ id: item.episodeId, title: item.titleZh || item.originalTitle, podcast: item.podcast, url: item.url }}
                    variant="icon"
                  />
                </div>
                <Link
                  to={`/episodes/${item.episodeId}`}
                  className="mt-2 block font-serif text-lg font-semibold leading-snug hover:text-vermilion"
                >
                  {item.titleZh || item.originalTitle}
                </Link>
                <p className="mt-2 text-sm leading-relaxed text-stone-600">{item.summaryZh}</p>
                <p className="mt-2.5 border-t border-dashed border-stone-200 pt-2.5 text-xs text-stone-400">
                  <span className="text-vermilion">▲</span> 为什么值得听：{item.reasonZh}
                </p>
              </li>
            ))}
          </ul>
        </section>
      ))}

      <div className="rule-double mt-14 pt-4 text-center">
        <Link to={meta.archiveTo} className="text-sm text-stone-400 hover:text-vermilion">
          ← {meta.archiveLabel}
        </Link>
      </div>
    </article>
  );
}
