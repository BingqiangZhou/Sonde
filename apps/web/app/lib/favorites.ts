/** 浏览器本地收藏：仅存放在本机 localStorage（不上传、不跨设备同步）。
 *  数据足够离线渲染列表；点击进入 /episodes/:id 时若单集仍在则显示详情。 */

export interface FavoriteEntry {
  id: number;
  title: string;
  podcast: string;
  url: string | null;
  savedAt: string; // ISO 时间
}

export interface FavoriteInput {
  id: number;
  title: string;
  podcast: string;
  url: string | null;
}

const STORAGE_KEY = 'sonde-favorites';
export const FAVORITES_CHANGE_EVENT = 'sonde-favorites-changed';

function read(): FavoriteEntry[] {
  if (typeof window === 'undefined') {
    return [];
  }
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    const parsed = raw ? (JSON.parse(raw) as FavoriteEntry[]) : [];
    if (!Array.isArray(parsed)) {
      return [];
    }
    // id 统一归一为 number：报表/列表里的 id 可能来自 Postgres BIGINT 字符串（如 "371"）
    return parsed
      .filter((e) => e != null && Number.isFinite(Number(e?.id)))
      .map((e) => ({ ...e, id: Number(e.id) }));
  } catch {
    return [];
  }
}

function write(entries: FavoriteEntry[]): void {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(entries));
  window.dispatchEvent(new CustomEvent(FAVORITES_CHANGE_EVENT));
}

/** 收藏列表（新收藏在前）。 */
export function listFavorites(): FavoriteEntry[] {
  return read().sort((a, b) => (a.savedAt < b.savedAt ? 1 : -1));
}

export function isFavorite(id: number): boolean {
  const key = Number(id);
  return read().some((e) => e.id === key);
}

/** 收藏/取消收藏；返回操作后的收藏状态。 */
export function toggleFavorite(input: FavoriteInput): boolean {
  const id = Number(input.id);
  const entries = read();
  const index = entries.findIndex((e) => e.id === id);
  if (index >= 0) {
    entries.splice(index, 1);
    write(entries);
    return false;
  }
  entries.unshift({ ...input, id, savedAt: new Date().toISOString() });
  write(entries);
  return true;
}

export function removeFavorite(id: number): void {
  const key = Number(id);
  write(read().filter((e) => e.id !== key));
}

/** 订阅收藏变化（本页内事件 + 其他标签页的 storage 事件）。 */
export function subscribeFavorites(onChange: () => void): () => void {
  const onStorage = (event: StorageEvent) => {
    if (event.key === STORAGE_KEY || event.key === null) {
      onChange();
    }
  };
  window.addEventListener(FAVORITES_CHANGE_EVENT, onChange);
  window.addEventListener('storage', onStorage);
  return () => {
    window.removeEventListener(FAVORITES_CHANGE_EVENT, onChange);
    window.removeEventListener('storage', onStorage);
  };
}
