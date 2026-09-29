/** 桌面左侧边栏（lg 以上）：品牌 + 分组导航 + 底部后台入口与版权。 */

import { Link, useLocation } from 'react-router';

import { SITE } from '@sonde/industry';

import { IconKey } from '../icons.tsx';
import { SIDEBAR, tabIsActive, type NavItem } from './nav.ts';

function SideLink({ item }: { item: NavItem }) {
  const { pathname } = useLocation();
  const isActive = tabIsActive(item, pathname);
  const Icon = item.icon;
  return (
    <Link
      to={item.to}
      prefetch="intent"
      aria-current={isActive ? 'page' : undefined}
      className={`flex h-10 items-center gap-2.5 rounded-md px-2.5 text-sm transition-colors duration-150 ${
        isActive
          ? 'bg-vermilion/10 font-semibold text-ink'
          : 'font-medium text-stone-500 hover:bg-stone-100 hover:text-ink'
      }`}
    >
      <span className={`flex w-[22px] shrink-0 justify-center ${isActive ? 'text-vermilion' : ''}`}>
        <Icon size={17} />
      </span>
      <span className="min-w-0 truncate">{item.label}</span>
    </Link>
  );
}

export function Sidebar() {
  return (
    <aside className="sticky top-0 hidden h-dvh w-60 shrink-0 flex-col border-r border-stone-300/70 bg-white px-3 pb-4 pt-6 lg:flex">
      <Link to="/" className="mb-5 flex h-11 items-center gap-2.5 px-1.5" aria-label={`${SITE.name} 首页`}>
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-ink font-serif text-base font-bold text-paper">
          声
        </span>
        <span className="flex flex-col leading-none">
          <span className="font-serif text-lg font-bold tracking-wide">{SITE.name}</span>
          <span className="mt-1 text-[10px] font-medium tracking-[0.28em] text-stone-400">SONDE</span>
        </span>
      </Link>

      <nav aria-label="主导航" className="-mx-1 flex-1 overflow-y-auto px-1">
        {SIDEBAR.map((section) => (
          <div key={section.title}>
            <div className="px-2.5 pb-1 pt-4 text-[11px] tracking-wider text-stone-400">{section.title}</div>
            <div className="flex flex-col gap-1">
              {section.items.map((item) => (
                <SideLink key={item.to} item={item} />
              ))}
            </div>
          </div>
        ))}
      </nav>

      <div className="mt-2 space-y-2 border-t border-stone-200 px-1 pt-3">
        <a
          href="/admin"
          className="flex h-9 items-center gap-2.5 rounded-md px-2.5 text-[13px] text-stone-400 transition-colors hover:bg-stone-100 hover:text-ink"
        >
          <span className="flex w-[22px] justify-center">
            <IconKey size={16} />
          </span>
          后台
        </a>
        <p className="px-2.5 text-[10px] leading-relaxed text-stone-400">
          {SITE.name} · 个人播客知识库
          <br />
          内容版权归原作者所有
        </p>
      </div>
    </aside>
  );
}
