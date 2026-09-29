/** 「我的」页：移动端入口聚合 —— 主题设置、收藏、关于、更新日志、后台。 */

import type { MetaFunction } from 'react-router';
import { Link } from 'react-router';

import { IconHeart, IconKey, IconScroll, IconStar, IconUser } from '~/components/icons.tsx';
import { ThemeModeSelector, useThemeSync } from '~/components/ThemeControls.tsx';
import { SITE } from '@sonde/industry';

export const meta: MetaFunction = () => [{ title: '我的 — 声读' }];

const LINKS = [
  { to: '/favorites', label: '我的收藏', desc: '保存在本浏览器的星标单集', Icon: IconStar },
  { to: '/about', label: '关于声读', desc: `${SITE.name} 是什么`, Icon: IconHeart },
  { to: '/changelog', label: '更新日志', desc: '每个版本的新增与修复', Icon: IconScroll },
];

export default function Me() {
  useThemeSync();

  return (
    <section className="py-8">
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">我的</h1>
        <p className="mt-2 text-xs tracking-widest text-stone-400">主题、收藏与站点信息</p>
      </header>

      <div className="mt-8 border border-stone-300 bg-white p-5">
        <h2 className="font-serif text-sm font-bold tracking-widest text-vermilion">外观</h2>
        <p className="mt-1.5 text-xs text-stone-400">深浅主题与跟随系统；选择只保存在本浏览器。</p>
        <div className="mt-4">
          <ThemeModeSelector />
        </div>
      </div>

      <ul className="mt-6 divide-y divide-stone-200 border-y border-stone-300">
        {LINKS.map(({ to, label, desc, Icon }) => (
          <li key={to}>
            <Link to={to} className="group flex items-center gap-3 px-2 py-4 hover:bg-white">
              <span className="flex w-6 justify-center text-stone-400 group-hover:text-vermilion">
                <Icon size={18} />
              </span>
              <span className="flex-1">
                <span className="block font-serif text-lg font-semibold leading-snug group-hover:text-vermilion">
                  {label}
                </span>
                <span className="mt-0.5 block text-xs text-stone-400">{desc}</span>
              </span>
              <span aria-hidden className="text-stone-300">
                →
              </span>
            </Link>
          </li>
        ))}
      </ul>

      <div className="mt-6 text-center">
        <a href="/admin" className="inline-flex items-center gap-2 text-xs text-stone-400 hover:text-vermilion">
          <IconKey size={14} />
          进入后台
        </a>
      </div>

      <div className="mt-10 flex items-center justify-center gap-2 text-[11px] text-stone-400">
        <IconUser size={13} />
        {SITE.name} · {SITE.nameEn}
      </div>
    </section>
  );
}
