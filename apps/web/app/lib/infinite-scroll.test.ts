import { afterEach, describe, expect, it, vi } from 'vitest';

import { PRELOAD_LEAD_PX, createSentinelObserver } from './infinite-scroll.ts';

interface FakeInstance {
  callback: IntersectionObserverCallback;
  options: IntersectionObserverInit | undefined;
  observe: ReturnType<typeof vi.fn>;
  disconnect: ReturnType<typeof vi.fn>;
}

let instances: FakeInstance[] = [];

class FakeIntersectionObserver {
  callback: IntersectionObserverCallback;
  options: IntersectionObserverInit | undefined;
  observe = vi.fn();
  disconnect = vi.fn();
  constructor(callback: IntersectionObserverCallback, options?: IntersectionObserverInit) {
    this.callback = callback;
    this.options = options;
    instances.push(this);
  }
}

function entry(isIntersecting: boolean): IntersectionObserverEntry {
  return { isIntersecting } as IntersectionObserverEntry;
}

afterEach(() => {
  vi.unstubAllGlobals();
  instances = [];
});

/** 预载提前量必须写在 rootMargin 的**下**边距槽(槽序:上/右/下/左)。
 *  写到上槽只把根矩形向上扩——哨兵是文档最后一个元素、永远在视口下方,
 *  实际提前量会变成 0(触底才加载),页面每批边界都会顿一下。曾真实发生。 */
describe('createSentinelObserver', () => {
  it(`提前量 ${PRELOAD_LEAD_PX}px 写在下边距槽`, () => {
    vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver);
    createSentinelObserver(() => {});
    expect(instances).toHaveLength(1);
    expect(instances[0]?.options?.rootMargin).toBe(`0px 0px ${PRELOAD_LEAD_PX}px 0px`);
  });

  it('跨越回调:进入余量 → true,离开 → false(重试重挂靠它)', () => {
    vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver);
    const onCrossing = vi.fn();
    createSentinelObserver(onCrossing);
    const io = instances[0];
    if (!io) throw new Error('observer 未构造');
    io.callback([entry(true)], {} as IntersectionObserver);
    expect(onCrossing).toHaveBeenLastCalledWith(true);
    io.callback([entry(false)], {} as IntersectionObserver);
    expect(onCrossing).toHaveBeenLastCalledWith(false);
  });

  it('空 entries 不触发回调(防御)', () => {
    vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver);
    const onCrossing = vi.fn();
    createSentinelObserver(onCrossing);
    instances[0]?.callback([], {} as IntersectionObserver);
    expect(onCrossing).not.toHaveBeenCalled();
  });

  it('无 IntersectionObserver 环境(如 SSR 工具调用)返回 null 不炸', () => {
    vi.stubGlobal('IntersectionObserver', undefined);
    expect(createSentinelObserver(() => {})).toBeNull();
  });
});
