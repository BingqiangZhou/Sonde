/** 资源路由:无限滚动的追加批接口(仅 loader,无 UI;客户端 useFetcher().load 调用)。
 *  铁律:loader 绝不抛错——fetcher.load 命中的 loader 错误会写入最近 ErrorBoundary,
 *  一次后台分页失败会顶掉整页;失败以 200 JSON(error: true) 交回客户端状态机。 */
import { apiGet } from '~/lib/api.server.ts';
import { episodesApiPath, parseTimelineQuery } from '~/lib/timeline.ts';
import type { EpisodesBatch, EpisodesPage } from '~/lib/types.ts';

export async function loader({ request }: { request: Request }): Promise<EpisodesBatch> {
  const query = parseTimelineQuery(new URL(request.url));
  try {
    const feed = await apiGet<EpisodesPage>(episodesApiPath(query));
    // apiGet 的 404 类空态(→ null)在这里等价于"没有更多",静默到头。
    if (!feed) {
      return { items: [], page: query.page, hasMore: false };
    }
    return { items: feed.items, page: feed.page, hasMore: feed.hasMore };
  } catch {
    return { items: [], page: query.page, hasMore: false, error: true };
  }
}

// 偏移分页:worker 持续插入新单集,浏览器绝不能拿缓存的旧偏移页当第 N 页。
export const headers = () => ({ 'Cache-Control': 'no-store' });
