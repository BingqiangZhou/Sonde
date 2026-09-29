import type { MetaFunction } from 'react-router';

import { SITE } from '@sonde/industry';

export const meta: MetaFunction = () => [{ title: `关于 — ${SITE.name}` }];

const STEPS = [
  { title: '采集', text: '定时抓取订阅的播客 RSS，发现新单集' },
  { title: '转写', text: '下载音频，转码后逐块转写为全文' },
  { title: '筛选', text: 'AI 为每集打注意力价值分，过门槛才入选' },
  { title: '成刊', text: '每天 08:00（北京时间）编成一份可读的日报' },
];

export default function About() {
  return (
    <article className="py-8">
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">关于{SITE.name}</h1>
      </header>
      <p className="mt-8 leading-loose text-stone-600">{SITE.description}</p>

      <ol className="mt-10 grid gap-4 sm:grid-cols-2">
        {STEPS.map((step, index) => (
          <li key={step.title} className="card-lift border border-stone-200 bg-white p-5">
            <div className="flex items-baseline gap-2.5">
              <span className="font-serif text-2xl font-bold text-vermilion">{index + 1}</span>
              <h2 className="font-serif text-base font-bold">{step.title}</h2>
            </div>
            <p className="mt-2 text-sm leading-relaxed text-stone-500">{step.text}</p>
          </li>
        ))}
      </ol>

      <p className="mt-10 text-center text-xs text-stone-400">{SITE.footerNote}</p>
    </article>
  );
}
