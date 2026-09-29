import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { ReportArticle } from '~/components/ReportArticle.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { formatMonthKey } from '~/lib/format.ts';
import type { DailyReport } from '~/lib/types.ts';

export const meta: MetaFunction = ({ params }) => [
  { title: `月报 ${params.key ? formatMonthKey(params.key) : ''} — 声读` },
];

export async function loader({ params }: { params: { key: string } }) {
  const report = await apiGet<DailyReport>(`/site/reports/monthly/${params.key}`);
  return { report, key: params.key };
}

export default function MonthlyDetail() {
  const { report, key } = useLoaderData<typeof loader>();

  if (!report) {
    return (
      <section className="py-20 text-center text-stone-500">
        <p className="font-serif text-xl">{formatMonthKey(key)} 的月报尚未生成。</p>
        <Link to="/monthly" className="mt-4 inline-block text-sm text-stone-400 hover:text-vermilion">
          ← 查看月报归档
        </Link>
      </section>
    );
  }

  return <ReportArticle report={report} kind="monthly" />;
}
