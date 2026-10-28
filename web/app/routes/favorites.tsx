/** 收藏页：数据全部来自本浏览器 localStorage（不经过服务端）。 */

import type { MetaFunction } from 'react-router';
import { Link } from 'react-router';
import { useEffect, useState } from 'react';

import { IconStar } from '~/components/icons.tsx';
import { listFavorites, removeFavorite, subscribeFavorites, type FavoriteEntry } from '~/lib/favorites.ts';
import { formatDate } from '~/lib/format.ts';

export const meta: MetaFunction = () => [
  { title: '我的收藏 — 声读' },
  { name: 'description', content: '收藏在本浏览器中的单集。' },
];

export default function Favorites() {
  // null = 尚未挂载（SSR 首帧为空态骨架，避免闪烁错误内容）
  const [entries, setEntries] = useState<FavoriteEntry[] | null>(null);

  useEffect(() => {
    const sync = () => setEntries(listFavorites());
    sync();
    return subscribeFavorites(sync);
  }, []);

  return (
    <section className="py-8">
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">我的收藏</h1>
        <p className="mt-2 text-xs tracking-widest text-stone-400">
          仅保存在本浏览器 · {entries?.length ?? 0} 集
        </p>
      </header>

      {entries === null ? (
        <p className="mt-12 py-6 text-center text-sm text-stone-400">读取中…</p>
      ) : entries.length === 0 ? (
        <div className="mt-12 border border-dashed border-stone-300 bg-white/50 py-14 text-center">
          <p className="text-stone-400">还没有收藏任何单集。</p>
          <p className="mt-2 text-xs text-stone-400">
            在单集详情或列表中点击
            <IconStar size={12} className="mx-1 inline align-[-1px] text-vermilion" filled />
            星标即可收藏（只保存在本浏览器，不上传）。
          </p>
          <Link to="/all" className="mt-6 inline-block text-sm text-stone-500 hover:text-vermilion">
            去全部动态逛逛 →
          </Link>
        </div>
      ) : (
        <ul className="mt-8 divide-y divide-stone-200 border-y border-stone-300">
          {entries.map((entry) => (
            <li key={entry.id} className="group flex items-start gap-3 py-4 hover:bg-white">
              <span className="mt-0.5 shrink-0 text-vermilion">
                <IconStar size={16} filled />
              </span>
              <div className="min-w-0 flex-1">
                <Link
                  to={`/episodes/${entry.id}`}
                  className="block font-serif text-lg font-semibold leading-snug hover:text-vermilion"
                >
                  {entry.title}
                </Link>
                <p className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-stone-400">
                  <span>{entry.podcast}</span>
                  <span aria-hidden>·</span>
                  <span>收藏于 {formatDate(entry.savedAt)}</span>
                  {entry.url && (
                    <a
                      href={entry.url}
                      target="_blank"
                      rel="noreferrer"
                      className="text-stone-400 hover:text-vermilion"
                    >
                      原始单集 ↗
                    </a>
                  )}
                </p>
              </div>
              <button
                type="button"
                onClick={() => removeFavorite(entry.id)}
                className="mt-1 shrink-0 text-xs text-stone-300 transition-colors hover:text-vermilion"
                aria-label={`取消收藏：${entry.title}`}
              >
                取消
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
