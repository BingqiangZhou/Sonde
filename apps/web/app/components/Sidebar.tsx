/** 站点侧栏:收纳时间线以外的全部内容(刊头/主题切换/版权)。
 *  收起态 = 左缘细轨(朱印 + 竖排站名 + 展开钮);展开态 = 刊头面板。
 *  窄视口两者都不适用:改由常驻精简顶栏(.sb-top,朱印+站名+主题切换)承担,
 *  CSS 按视口宽度切换显隐。开合实际由 <html> 上的 .sb-open class 驱动(app.css),
 *  此处只管状态、持久化(sonde-sidebar)与 aria —— DOM 恒定,SSR 无水合错配。 */

import { useEffect, useState } from 'react';

import { SITE } from '@sonde/industry';

import { ThemeModeSelector } from './ThemeControls.tsx';
import { IconChevronLeft, IconChevronRight } from './icons.tsx';
import { applySidebarState, getStoredSidebarState, setSidebarState, type SidebarState } from '~/lib/sidebar.ts';

export function Sidebar() {
  const [state, setState] = useState<SidebarState>('open');

  useEffect(() => {
    // 水合会剥掉内联脚本加在 <html> 上的 .sb-open,按存储值重新应用(同 useThemeSync)
    const stored = getStoredSidebarState();
    applySidebarState(stored);
    setState(stored);
  }, []);

  const toggle = () => {
    const next: SidebarState = state === 'open' ? 'closed' : 'open';
    setSidebarState(next);
    setState(next);
  };

  const today = new Date().toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
    timeZone: 'Asia/Shanghai',
  });

  const sealChar = Array.from(SITE.name.trim())[0] ?? '声';

  return (
    <aside className="sidebar" aria-label="站点信息">
      {/* 窄视口:常驻精简顶栏(朱印+站名+主题切换),不吸顶、不参与开合 */}
      <div className="sb-top">
        <span className="sb-seal" aria-hidden="true">
          {sealChar}
        </span>
        <span className="sb-top-name">{SITE.name}</span>
        <div className="ml-auto">
          <ThemeModeSelector variant="compact" />
        </div>
      </div>

      {/* 收起态:细轨(朱印 + 竖排站名 + 展开钮) */}
      <div className="sb-rail">
        <span className="sb-seal" aria-hidden="true">
          {sealChar}
        </span>
        <span className="sb-rail-name" aria-hidden="true">
          {SITE.name}
        </span>
        <button
          type="button"
          onClick={toggle}
          aria-expanded={state === 'open'}
          aria-controls="sb-panel"
          className="sb-toggle flex h-7 w-7 items-center justify-center rounded-md text-stone-400 hover:bg-stone-100 hover:text-ink"
        >
          <IconChevronRight size={15} />
          <span className="sr-only">展开站点信息</span>
        </button>
      </div>

      {/* 展开态:刊头面板 */}
      <div className="sb-panel" id="sb-panel">
        <div className="sb-panel-inner">
          <div>
            <p className="text-xs tracking-[0.25em] text-stone-400">{today}</p>
            <div className="rule-double mt-3 pt-4">
              <p className="font-serif text-3xl font-bold tracking-[0.15em]">{SITE.name}</p>
              <p className="mt-2 text-xs leading-relaxed tracking-widest text-stone-500">{SITE.tagline}</p>
            </div>
          </div>

          <div className="mt-auto pt-6">
            <ThemeModeSelector variant="compact" />
            <p className="mt-4 text-xs leading-relaxed text-stone-400">{SITE.footerNote}</p>
            <button
              type="button"
              onClick={toggle}
              aria-expanded={state === 'open'}
              aria-controls="sb-panel"
              className="sb-toggle mt-4 flex w-full items-center justify-center gap-1.5 rounded-md border border-stone-300 py-1.5 text-xs text-stone-500 hover:border-vermilion hover:text-vermilion"
            >
              收起
              <IconChevronLeft size={14} />
              <span className="sr-only">站点信息</span>
            </button>
          </div>
        </div>
      </div>
    </aside>
  );
}
