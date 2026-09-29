/** 深浅色主题：light | dark | system（跟随系统），持久化在 localStorage。
 *  实际生效通过 <html> 上的 .dark class（app.css 中的调色板变量覆盖）。
 *  首屏防闪炼的初始化脚本在 root.tsx 内联执行。 */

export type ThemeMode = 'light' | 'dark' | 'system';

const STORAGE_KEY = 'sonde-theme';
export const THEME_CHANGE_EVENT = 'sonde-theme-changed';

export function systemPrefersDark(): boolean {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches;
}

export function getStoredMode(): ThemeMode {
  if (typeof window === 'undefined') {
    return 'system';
  }
  const value = window.localStorage.getItem(STORAGE_KEY);
  return value === 'light' || value === 'dark' ? value : 'system';
}

/** 应用某个模式到 <html>；返回实际是否为深色。 */
export function applyMode(mode: ThemeMode): boolean {
  const dark = mode === 'dark' || (mode === 'system' && systemPrefersDark());
  document.documentElement.classList.toggle('dark', dark);
  return dark;
}

export function setMode(mode: ThemeMode): void {
  window.localStorage.setItem(STORAGE_KEY, mode);
  applyMode(mode);
  window.dispatchEvent(new CustomEvent<ThemeMode>(THEME_CHANGE_EVENT, { detail: mode }));
}

/** system 模式下监听系统偏好变化（light/dark 模式下调用无效）。 */
export function watchSystemPreference(onChange: () => void): () => void {
  const query = window.matchMedia('(prefers-color-scheme: dark)');
  const listener = () => {
    if (getStoredMode() === 'system') {
      applyMode('system');
      onChange();
    }
  };
  query.addEventListener('change', listener);
  return () => query.removeEventListener('change', listener);
}
