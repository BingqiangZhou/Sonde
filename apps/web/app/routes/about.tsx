import type { MetaFunction } from 'react-router';

import { SITE } from '@sonde/industry';

export const meta: MetaFunction = () => [{ title: `关于 — ${SITE.name}` }];

export default function About() {
  return (
    <article className="prose-stone max-w-none text-stone-700">
      <h1 className="text-2xl font-bold text-stone-900">关于{SITE.name}</h1>
      <p className="mt-4">{SITE.description}</p>
      <ul className="mt-6 list-disc space-y-1 pl-6 text-sm">
        <li>采集：定时抓取订阅的播客 RSS，发现新单集</li>
        <li>转写：下载音频并转写为全文</li>
        <li>筛选：AI 为每集打注意力价值分，过门槛才入选</li>
        <li>成刊：每天 08:00（北京时间）生成一份可读的日报</li>
      </ul>
      <p className="mt-6 text-sm text-stone-500">{SITE.footerNote}</p>
    </article>
  );
}
