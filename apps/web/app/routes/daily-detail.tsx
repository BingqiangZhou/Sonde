import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { apiGet } from '~/lib/api.server.ts';
import { formatDate, formatDuration } from '~/lib/format.ts';
import type { DailyReport } from '~/lib/types.ts';

export const meta: MetaFunction = ({ params }) => [
  { title: `日报 ${params.key ?? ''} — 声读` },
];

export async function loader({ params }: { params: { key: string } }) {
  const report = await apiGet<DailyReport>(`/site/reports/daily/${params.key}`);
  return { report, key: params.key };
}

export default function DailyDetail() {
  const { report, key } = useLoaderData<typeof loader>();

  if (!report) {
    return (
      <section className="py-16 text-center text-stone-500">
        <p>{formatDate(key)} 的日报尚未生成。</p>
        <Link to="/daily" className="mt-3 inline-block text-sm text-stone-400 hover:text-stone-600">
          ← 查看日报归档
        </Link>
      </section>
    );
  }

  const { content } = report;
  return (
    <article className="py-8">
      <div className="text-center">
        <p className="text-xs tracking-widest text-stone-400">声读日报 · {formatDate(report.reportKey)}</p>
        <h1 className="mt-3 text-3xl font-bold leading-snug text-stone-900">{content.title}</h1>
        <p className="mx-auto mt-4 max-w-xl leading-relaxed text-stone-600">{content.leadParagraph}</p>
      </div>

      {content.highlights.length > 0 && (
        <section className="mt-8 rounded-lg border border-stone-200 bg-white p-5">
          <h2 className="text-sm font-semibold text-stone-500">今日看点</h2>
          <ol className="mt-3 space-y-2">
            {content.highlights.map((highlight, index) => (
              <li key={index} className="flex gap-2.5 text-sm leading-relaxed text-stone-700">
                <span className="mt-0.5 flex h-5 w-5 flex-none items-center justify-center rounded-full bg-stone-100 text-xs font-medium text-stone-500">
                  {index + 1}
                </span>
                {highlight}
              </li>
            ))}
          </ol>
        </section>
      )}

      {content.sections.map((section) => (
        <section key={section.section} className="mt-10">
          <h2 className="border-l-4 border-stone-800 pl-3 text-lg font-bold text-stone-900">
            {section.section}
          </h2>
          <ul className="mt-4 space-y-4">
            {section.items.map((item) => (
              <li key={item.episodeId} className="rounded-lg border border-stone-200 bg-white p-5">
                <div className="flex items-center gap-2 text-xs text-stone-400">
                  <span className="rounded bg-stone-100 px-1.5 py-0.5 text-stone-500">{item.categoryLabel}</span>
                  <span>{item.podcast}</span>
                  {formatDuration(item.durationSeconds) && <span>{formatDuration(item.durationSeconds)}</span>}
                </div>
                <Link
                  to={`/episodes/${item.episodeId}`}
                  className="mt-2 block text-base font-semibold leading-snug text-stone-900 hover:underline"
                >
                  {item.titleZh || item.originalTitle}
                </Link>
                <p className="mt-2 text-sm leading-relaxed text-stone-600">{item.summaryZh}</p>
                <p className="mt-2 text-xs text-stone-400">为什么值得听：{item.reasonZh}</p>
              </li>
            ))}
          </ul>
        </section>
      ))}

      <div className="mt-12 text-center">
        <Link to="/daily" className="text-sm text-stone-400 hover:text-stone-600">
          ← 日报归档
        </Link>
      </div>
    </article>
  );
}
