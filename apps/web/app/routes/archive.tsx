import type { MetaFunction } from 'react-router';

export const meta: MetaFunction = () => [{ title: '全部精选 — 声读' }];

export default function Archive() {
  return (
    <section className="py-12 text-center text-stone-500">
      <h1 className="text-2xl font-bold text-stone-900">全部精选</h1>
      <p className="mt-3">还没有入选的单集。</p>
    </section>
  );
}
