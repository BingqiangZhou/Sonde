import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { ReportArticle } from '~/components/ReportArticle.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { formatWeekRange } from '~/lib/format.ts';
import type { DailyReport } from '~/lib/types.ts';

export const meta: MetaFunction = ({ params }) => [
  { title: `周报 ${params.key ? formatWeekRange(params.key) : ''} — 声读` },
];

export async function loader({ params }: { params: { key: string } }) {
  const report = await apiGet<DailyReport>(`/site/reports/weekly/${params.key}`);
  return { report, key: params.key };
}

export default function WeeklyDetail() {
  const { report, key } = useLoaderData<typeof loader>();

  if (!report) {
    return (
      <section className="py-20 text-center text-stone-500">
        <p className="font-serif text-xl">{formatWeekRange(key)} 这一周的周报尚未生成。</p>
        <Link to="/weekly" className="mt-4 inline-block text-sm text-stone-400 hover:text-vermilion">
          ← 查看周报归档
        </Link>
      </section>
    );
  }

  return <ReportArticle report={report} kind="weekly" />;
}
