/** 站点图标（线性描边，currentColor，lucide 风格）。 */

import type { ReactNode } from 'react';

export interface IconProps {
  size?: number;
}

function svg(size: number | undefined, children: ReactNode) {
  return (
    <svg
      width={size ?? 18}
      height={size ?? 18}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {children}
    </svg>
  );
}

/** 首页：声波 */
export function IconWave({ size }: IconProps) {
  return svg(
    size,
    <>
      <circle cx="12" cy="12" r="2" />
      <path d="M7.8 16.2a6 6 0 0 1 0-8.4M16.2 7.8a6 6 0 0 1 0 8.4" />
      <path d="M4.9 19.1a10 10 0 0 1 0-14.2M19.1 4.9a10 10 0 0 1 0 14.2" />
    </>,
  );
}

/** 日报：报纸 */
export function IconNews({ size }: IconProps) {
  return svg(
    size,
    <>
      <path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-4 0V9" />
      <path d="M18 14h-8M15 18h-5M10 6h8v4h-8V6Z" />
    </>,
  );
}

/** 全部精选：列表 */
export function IconList({ size }: IconProps) {
  return svg(
    size,
    <>
      <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" />
    </>,
  );
}

/** 关于：心 */
export function IconHeart({ size }: IconProps) {
  return svg(
    size,
    <path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" />,
  );
}

/** 后台：钥匙 */
export function IconKey({ size }: IconProps) {
  return svg(
    size,
    <>
      <circle cx="7.5" cy="15.5" r="5.5" />
      <path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3" />
    </>,
  );
}

/** admin 仪表盘：四格 */
export function IconGrid({ size }: IconProps) {
  return svg(
    size,
    <>
      <rect width="7" height="7" x="3" y="3" rx="1" />
      <rect width="7" height="7" x="14" y="3" rx="1" />
      <rect width="7" height="7" x="14" y="14" rx="1" />
      <rect width="7" height="7" x="3" y="14" rx="1" />
    </>,
  );
}

/** admin 订阅源：电台 */
export function IconRadio({ size }: IconProps) {
  return svg(
    size,
    <>
      <circle cx="12" cy="12" r="2" />
      <path d="M4.9 19.1a10 10 0 0 1 0-14.2M7.8 16.2a6 6 0 0 1 0-8.4M16.2 7.8a6 6 0 0 1 0 8.4M19.1 4.9a10 10 0 0 1 0 14.2" />
    </>,
  );
}

/** admin 单集：唱片 */
export function IconDisc({ size }: IconProps) {
  return svg(
    size,
    <>
      <circle cx="12" cy="12" r="10" />
      <circle cx="12" cy="12" r="4" />
    </>,
  );
}

/** admin 成本：硬币 */
export function IconCoins({ size }: IconProps) {
  return svg(
    size,
    <>
      <circle cx="8" cy="8" r="6" />
      <path d="M18.09 10.37A6 6 0 1 1 10.34 18M7 6h1v4M16.71 13.88l.7.71-2.82 2.82" />
    </>,
  );
}
