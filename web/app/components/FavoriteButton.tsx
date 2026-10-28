/** 收藏按钮（浏览器本地）：列表行用 icon 变体，详情页用 full 变体。 */

import { useEffect, useState } from 'react';

import { isFavorite, toggleFavorite } from '~/lib/favorites.ts';

import { IconStar } from './icons.tsx';

export interface FavoriteTarget {
  id: number;
  title: string;
  podcast: string;
  url: string | null;
}

export function FavoriteButton({
  episode,
  variant = 'icon',
  className = '',
}: {
  episode: FavoriteTarget;
  variant?: 'icon' | 'full';
  className?: string;
}) {
  // SSR 渲染为未收藏状态，挂载后从 localStorage 校正
  const [favorited, setFavorited] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setFavorited(isFavorite(episode.id));
    setReady(true);
  }, [episode.id]);

  const onToggle = (event: React.MouseEvent) => {
    event.preventDefault();
    event.stopPropagation();
    setFavorited(toggleFavorite(episode));
  };

  if (variant === 'icon') {
    return (
      <button
        type="button"
        onClick={onToggle}
        aria-pressed={favorited}
        aria-label={favorited ? '取消收藏' : '收藏'}
        title={favorited ? '取消收藏' : '收藏到本浏览器'}
        className={`shrink-0 transition-colors ${
          ready && favorited ? 'text-vermilion' : 'text-stone-300 hover:text-vermilion'
        } ${className}`}
      >
        <IconStar size={15} filled={ready && favorited} />
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={favorited}
      className={`inline-flex items-center gap-2 rounded-md border px-4 py-2 text-xs font-medium transition-colors ${
        ready && favorited
          ? 'border-vermilion bg-vermilion/10 text-vermilion'
          : 'border-stone-300 text-stone-500 hover:border-vermilion hover:text-vermilion'
      } ${className}`}
    >
      <IconStar size={15} filled={ready && favorited} />
      {ready && favorited ? '已收藏（本浏览器）' : '收藏到本浏览器'}
    </button>
  );
}
