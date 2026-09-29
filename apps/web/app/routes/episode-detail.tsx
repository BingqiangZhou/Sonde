import type { MetaFunction } from 'react-router';

export const meta: MetaFunction = () => [{ title: '单集 — 声读' }];

export default function EpisodeDetail() {
  return (
    <section className="py-12 text-center text-stone-500">
      <p>单集详情搭建中。</p>
    </section>
  );
}
