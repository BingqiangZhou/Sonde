const locks = new Map<string, Promise<unknown>>();

/**
 * 串行化对同一 key 的异步操作。CI 单进程内避免并发写冲突。
 * （非跨进程锁；跨进程场景需用 OS 文件锁，本项目暂不需要。）
 */
export async function withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
  const prev = locks.get(key) ?? Promise.resolve();
  let release!: () => void;
  const next = new Promise<void>((resolve) => {
    release = resolve;
  });
  locks.set(key, prev.then(() => next));
  await prev;
  try {
    return await fn();
  } finally {
    release();
    if (locks.get(key) === next) locks.delete(key);
  }
}
