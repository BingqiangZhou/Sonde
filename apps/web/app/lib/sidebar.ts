/** 站点侧栏开合：open | closed，持久化在 localStorage，默认展开。
 *  实际生效通过 <html> 上的 .sb-open class（app.css 中的侧栏宽度/淡入淡出）。
 *  首屏防闪烁的初始化脚本在 root.tsx 内联执行（与主题同一个脚本）。 */

export type SidebarState = 'open' | 'closed';

const STORAGE_KEY = 'sonde-sidebar';

/** <html> 上打/移除的 class 名，root.tsx 的内联脚本与 CSS 都引用它。 */
export const SIDEBAR_OPEN_CLASS = 'sb-open';

export function getStoredSidebarState(): SidebarState {
  if (typeof window === 'undefined') {
    return 'open';
  }
  return window.localStorage.getItem(STORAGE_KEY) === 'closed' ? 'closed' : 'open';
}

/** 应用某个状态到 <html>。 */
export function applySidebarState(state: SidebarState): void {
  document.documentElement.classList.toggle(SIDEBAR_OPEN_CLASS, state === 'open');
}

export function setSidebarState(state: SidebarState): void {
  window.localStorage.setItem(STORAGE_KEY, state);
  applySidebarState(state);
}
