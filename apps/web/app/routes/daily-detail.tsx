import type { MetaFunction } from 'react-router';

export const meta: MetaFunction = () => [{ title: '日报 — 声读' }];

export default function DailyDetail() {
  return (
    <section className="py-12 text-center text-stone-500">
      <p>该日期的日报尚未生成。</p>
    </section>
  );
}
