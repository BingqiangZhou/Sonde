/** 站点导航配置：桌面侧栏、移动底栏共用一处定义。 */

import type { ReactNode } from 'react';

import {
  IconCalendar,
  IconCalendarDays,
  IconHeart,
  IconList,
  IconNews,
  IconScroll,
  IconStar,
  IconUser,
  IconWave,
} from '../icons.tsx';

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
      { to: '/weekly', label: '周报', icon: IconCalendar },
      { to: '/monthly', label: '月报', icon: IconCalendarDays },
      { to: '/all', label: '全部动态', icon: IconList },
    ],
  },
  {
    title: '个人',
    items: [{ to: '/favorites', label: '收藏', icon: IconStar }],
  },
  {
    title: '更多',
    items: [
      { to: '/changelog', label: '更新日志', icon: IconScroll },
      { to: '/about', label: '关于', icon: IconHeart },
    ],
  },
];

export const TABBAR: NavItem[] = [
  { to: '/', label: '首页', icon: IconWave, end: true },
  { to: '/daily', label: '日报', icon: IconNews },
  { to: '/all', label: '全部', icon: IconList },
  { to: '/favorites', label: '收藏', icon: IconStar },
  { to: '/me', label: '我的', icon: IconUser },
];

export function tabIsActive(item: NavItem, pathname: string): boolean {
  if (item.end) {
    return pathname === item.to;
  }
  // /archive 已并入 /all
  if (item.to === '/all') {
    return /^\/(all|archive)(\/|$)/.test(pathname);
  }
  // 日报标签同时高亮周报/月报（同为「报刊」入口）
  if (item.to === '/daily') {
    return /^\/(daily|weekly|monthly)(\/|$)/.test(pathname);
  }
  return pathname === item.to || pathname.startsWith(`${item.to}/`);
}
