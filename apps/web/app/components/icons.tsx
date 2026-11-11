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

/** 站点品牌 / 单集封面占位：声波 */
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

/** 主题：太阳（浅色） */
export function IconSun({ size }: IconProps) {
  return svg(
    size,
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </>,
  );
}

/** 主题：月亮（深色） */
export function IconMoon({ size }: IconProps) {
  return svg(size, <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" />);
}

/** 主题：显示器（跟随系统） */
export function IconMonitor({ size }: IconProps) {
  return svg(
    size,
    <>
      <rect width="20" height="14" x="2" y="3" rx="2" />
      <path d="M8 21h8M12 17v4" />
    </>,
  );
}
