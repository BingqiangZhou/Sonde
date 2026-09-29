import type { MetaFunction } from 'react-router';

export const meta: MetaFunction = () => [{ title: '日报 — 声读' }];

export default function Daily() {
  return (
    <section className="py-12 text-center text-stone-500">
      <h1 className="text-2xl font-bold text-stone-900">播客日报</h1>
      <p className="mt-3">每天 08:00（北京时间）自动成刊，敬请期待。</p>
    </section>
  );
}
