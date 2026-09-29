import type { MetaFunction } from 'react-router';
import { useLoaderData } from 'react-router';

import { apiGet } from '~/lib/api.server.ts';

import { SITE } from '@sonde/industry';

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

interface SiteMeta {
  name: string;
  tagline: string;
}

export async function loader() {
  const meta = await apiGet<SiteMeta>('/site/meta');
  return { meta };
}

export default function Home() {
  const { meta } = useLoaderData<typeof loader>();
  return (
    <section className="py-16 text-center">
      <h1 className="text-4xl font-bold tracking-wide">{meta?.name ?? SITE.name}</h1>
      <p className="mt-4 text-lg text-stone-500">{meta?.tagline ?? SITE.tagline}</p>
      <div className="mt-10 flex justify-center gap-4">
        <a
          href="/daily"
          className="rounded-md bg-stone-900 px-5 py-2.5 text-sm font-medium text-white hover:bg-stone-700"
        >
          读今天的日报
        </a>
        <a
          href="/about"
          className="rounded-md border border-stone-300 px-5 py-2.5 text-sm font-medium text-stone-700 hover:bg-stone-100"
        >
          了解声读
        </a>
      </div>
      <p className="mt-12 text-xs text-stone-400">流水线搭建中：采集 · 转写 · 评分 · 成刊</p>
    </section>
  );
}
