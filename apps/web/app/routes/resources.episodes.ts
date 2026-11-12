/** 资源路由:无限滚动的追加批接口(仅 loader,无 UI;客户端 useFetcher().load 调用)。
 *  铁律:loader 绝不抛错——fetcher.load 命中的 loader 错误会写入最近 ErrorBoundary,
 *  一次后台分页失败会顶掉整页;失败以 200 JSON(error: true) 交回客户端状态机。
 *  头随体走,loader 一律返回 Response:成功批透传 api 的弱 ETag + 60s 缓存,
 *  If-None-Match 命中回 304(浏览器缓存接管,省传输);错误批 no-store(错误态不吃缓存)。 */
import { apiGetWithHeaders } from '~/lib/api.server.ts';
import { episodesApiPath, parseTimelineQuery } from '~/lib/timeline.ts';
import type { EpisodesBatch, EpisodesPage } from '~/lib/types.ts';

const CC_60 = 'public, max-age=60, s-maxage=60, must-revalidate';

function jsonBatch(batch: EpisodesBatch, cacheControl: string): Response {
  return new Response(JSON.stringify(batch), {
    headers: { 'content-type': 'application/json', 'cache-control': cacheControl },
  });
}

export async function loader({ request }: { request: Request }): Promise<Response> {
  const query = parseTimelineQuery(new URL(request.url));
  try {
    const feed = await apiGetWithHeaders<EpisodesPage>(episodesApiPath(query));
    // apiGetWithHeaders 的 404 类空态(→ null)在这里等价于"没有更多",静默到头。
    if (!feed) {
      return jsonBatch({ items: [], page: query.page, hasMore: false }, 'no-store');
    }
    const batch: EpisodesBatch = { items: feed.data.items, page: feed.data.page, hasMore: feed.data.hasMore };
    const etag = feed.etag;
    if (etag && request.headers.get('if-none-match') === etag) {
      return new Response(null, { status: 304, headers: { etag, 'cache-control': CC_60 } });
    }
    return new Response(JSON.stringify(batch), {
      headers: etag
        ? { 'content-type': 'application/json', 'cache-control': CC_60, etag }
        : { 'content-type': 'application/json', 'cache-control': CC_60 },
    });
  } catch {
    return jsonBatch({ items: [], page: query.page, hasMore: false, error: true }, 'no-store');
  }
}
