/** 无限滚动哨兵的观察器构造(纯浏览器 API 封装,便于单测钉住几何参数)。 */

/** 预载提前量:哨兵进入视口下方该距离内即开始拉下一批(未触底先取数)。
 *  必须落在 rootMargin 的下边距槽——槽序是 上/右/下/左,写进上槽只会把根矩形
 *  向上扩,而哨兵是文档最后一个元素、永远在视口下方,等于提前量归零(触底才加载)。 */
export const PRELOAD_LEAD_PX = 800;

/** 观察哨兵对预载余量的跨越:进入 → onCrossing(true),离开 → onCrossing(false)。
 *  依赖 IO 只在跨越时触发的语义——失败后哨兵不动就不会形成重试风暴,
 *  调用方靠每次「重新进入」重挂重试。无 IntersectionObserver 环境返回 null。 */
export function createSentinelObserver(onCrossing: (intersecting: boolean) => void): IntersectionObserver | null {
  if (typeof IntersectionObserver === 'undefined') {
    return null;
  }
  return new IntersectionObserver(
    (entries) => {
      const entry = entries[0];
      if (!entry) {
        return;
      }
      onCrossing(entry.isIntersecting);
    },
    { rootMargin: `0px 0px ${PRELOAD_LEAD_PX}px 0px` },
  );
}
