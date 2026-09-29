/** 站点导航配置：桌面侧栏、移动底栏共用一处定义。 */

import type { ReactNode } from 'react';

import { IconHeart, IconList, IconNews, IconWave } from '../icons.tsx';

export interface NavItem {
  to: string;
  label: string;
  icon: (props: { size?: number }) => ReactNode;
  /** 精确匹配（首页） */
  end?: boolean;
}

export const SIDEBAR: Array<{ title: string; items: NavItem[] }> = [
  {
    title: '内容',
    items: [
      { to: '/', label: '首页', icon: IconWave, end: true },
      { to: '/daily', label: '日报', icon: IconNews },
      { to: '/archive', label: '全部精选', icon: IconList },
    ],
  },
  {
    title: '更多',
    items: [{ to: '/about', label: '关于', icon: IconHeart }],
  },
];

export const TABBAR: NavItem[] = [
  { to: '/', label: '首页', icon: IconWave, end: true },
  { to: '/daily', label: '日报', icon: IconNews },
  { to: '/archive', label: '全部', icon: IconList },
  { to: '/about', label: '关于', icon: IconHeart },
];

export function tabIsActive(item: NavItem, pathname: string): boolean {
  if (item.end) {
    return pathname === item.to;
  }
  return pathname === item.to || pathname.startsWith(`${item.to}/`);
}
