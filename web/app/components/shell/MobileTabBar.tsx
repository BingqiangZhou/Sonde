/** 移动端底部标签栏（lg 以下）。 */

import { Link, useLocation } from 'react-router';

import { TABBAR, tabIsActive } from './nav.ts';

export function MobileTabBar() {
  const { pathname } = useLocation();
  return (
    <nav
      aria-label="底部导航"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-stone-200 bg-white/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden"
    >
      <div className="mx-auto grid h-14 max-w-md grid-cols-5">
        {TABBAR.map((item) => {
          const active = tabIsActive(item, pathname);
          const Icon = item.icon;
          return (
            <Link
              key={item.to}
              to={item.to}
              prefetch="intent"
              aria-current={active ? 'page' : undefined}
              className={`relative flex flex-col items-center justify-center gap-0.5 text-[11px] transition-colors ${
                active ? 'font-semibold text-vermilion' : 'text-stone-500 active:text-ink'
              }`}
            >
              <Icon size={20} />
              <span>{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
