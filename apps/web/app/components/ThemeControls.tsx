/** 主题模式切换器：浅色 / 深色 / 跟随系统。侧栏底部（紧凑）与「我的」页（完整）共用。 */

import { useEffect, useState } from 'react';

import {
  applyMode,
  getStoredMode,
  setMode,
  watchSystemPreference,
  type ThemeMode,
} from '~/lib/theme.ts';

import { IconMonitor, IconMoon, IconSun } from './icons.tsx';

const MODES: Array<{ value: ThemeMode; label: string; Icon: (props: { size?: number }) => React.ReactNode }> = [
  { value: 'light', label: '浅色', Icon: IconSun },
  { value: 'dark', label: '深色', Icon: IconMoon },
  { value: 'system', label: '跟随系统', Icon: IconMonitor },
];

export function ThemeModeSelector({ variant = 'full' }: { variant?: 'full' | 'compact' }) {
  const [mode, setLocalMode] = useState<ThemeMode>('system');

  useEffect(() => {
    const sync = () => setLocalMode(getStoredMode());
    sync();
    // system 模式下系统偏好变化时同步高亮
    return watchSystemPreference(sync);
  }, []);

  const select = (next: ThemeMode) => {
    setMode(next);
    setLocalMode(next);
  };

  if (variant === 'compact') {
    return (
      <div className="flex items-center gap-1" role="group" aria-label="主题模式">
        {MODES.map(({ value, label, Icon }) => (
          <button
            key={value}
            type="button"
            onClick={() => select(value)}
            aria-pressed={mode === value}
            aria-label={label}
            title={label}
            className={`flex h-7 w-7 items-center justify-center rounded-md transition-colors ${
              mode === value ? 'bg-vermilion/10 text-vermilion' : 'text-stone-400 hover:bg-stone-100 hover:text-ink'
            }`}
          >
            <Icon size={15} />
          </button>
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-3 gap-2" role="group" aria-label="主题模式">
      {MODES.map(({ value, label, Icon }) => (
        <button
          key={value}
          type="button"
          onClick={() => select(value)}
          aria-pressed={mode === value}
          className={`flex flex-col items-center gap-1.5 rounded-lg border px-3 py-4 text-xs transition-colors ${
            mode === value
              ? 'border-vermilion bg-vermilion/10 font-semibold text-vermilion'
              : 'border-stone-300 text-stone-500 hover:border-vermilion hover:text-vermilion'
          }`}
        >
          <Icon size={20} />
          {label}
        </button>
      ))}
    </div>
  );
}

/** 主题同步：挂载后按存储值重新应用（水合会剥掉内联脚本的 .dark class），并跟踪系统偏好变化。 */
export function useThemeSync(): void {
  useEffect(() => {
    applyMode(getStoredMode());
    return watchSystemPreference(() => {});
  }, []);
}
