/** 回到顶部:滚过一屏后右下角浮出(SSR 不渲染,纯客户端小岛,参考 AIHOT 的同名按钮)。 */

import { useEffect, useState } from 'react';

import { IconArrowUp } from './icons.tsx';

export function BackToTop() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const onScroll = () => setVisible(window.scrollY > 600);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  if (!visible) {
    return null;
  }

  return (
    <button
      type="button"
      onClick={() => window.scrollTo({ top: 0 })}
      aria-label="回到顶部"
      title="回到顶部"
      className="fixed bottom-5 right-5 z-20 flex h-10 w-10 items-center justify-center rounded-full border border-stone-300 bg-paper/90 text-stone-500 shadow-sm backdrop-blur hover:border-vermilion hover:text-vermilion"
    >
      <IconArrowUp size={17} />
    </button>
  );
}
