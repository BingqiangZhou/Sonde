import type { MetaFunction } from 'react-router';
import { Link, useLoaderData } from 'react-router';

import { ReportArticle } from '~/components/ReportArticle.tsx';
import { apiGet } from '~/lib/api.server.ts';
import { formatDate } from '~/lib/format.ts';
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
      <section className="py-20 text-center text-stone-500">
        <p className="font-serif text-xl">{formatDate(key)} 的日报尚未生成。</p>
        <Link to="/daily" className="mt-4 inline-block text-sm text-stone-400 hover:text-vermilion">
          ← 查看日报归档
        </Link>
      </section>
    );
  }

  return <ReportArticle report={report} kind="daily" />;
}
