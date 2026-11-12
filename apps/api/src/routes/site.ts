/** 站点读路由（web 进程唯一数据入口）。 */

import { createHash } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import { SITE } from '@sonde/industry';

import { listCategoriesWithCounts, listEpisodes, listSourcesWithCounts, type EpisodeFilters } from '@sonde/backend';

/** 动态内容(时间线)60 秒;稳定内容(源/分类/站点信息)300 秒。
 *  max-age 浏览器本地、s-maxage 将来套 CDN 时生效;must-revalidate 过期即校验。 */
const cacheControl = (maxAge: number) => `public, max-age=${maxAge}, s-maxage=${maxAge}, must-revalidate`;

/** 统一读响应:弱 ETag(响应体+query 的指纹)+ 条件 GET。
 *  If-None-Match 命中回 304 空体(头保留)——aihot 公开 API 同款分层。 */
function sendCached(request: FastifyRequest, reply: FastifyReply, body: unknown, maxAge: number) {
  const etag = `W/"${createHash('sha1').update(JSON.stringify(body) + request.url).digest('hex').slice(0, 16)}"`;
  reply.header('Cache-Control', cacheControl(maxAge));
  reply.header('ETag', etag);
  if (request.headers['if-none-match'] === etag) {
    return reply.code(304).send();
  }
  return reply.send(body);
}

export async function siteRoutes(app: FastifyInstance) {
  app.get('/meta', async (request, reply) =>
    sendCached(
      request,
      reply,
      {
        name: SITE.name,
        nameEn: SITE.nameEn,
        subject: SITE.subject,
        homeTitle: SITE.homeTitle,
        description: SITE.description,
        tagline: SITE.tagline,
      },
      300,
    ),
  );

  // 时间线：全部单集按发布时间倒序，?page= 偏移分页（50/页）；
  // ?source= 按源筛选、?category= 一级分类筛选、?q= 标题/简介/播客名关键词
  // (垃圾值一律忽略，回落全量)
  app.get('/episodes', async (request, reply) => {
    const query = request.query as { page?: string; source?: string; category?: string; q?: string };
    const page = Math.max(1, Number.parseInt(query.page ?? '1', 10) || 1);
    const filters: EpisodeFilters = {};
    const sourceId = Number.parseInt(query.source ?? '', 10);
    if (Number.isInteger(sourceId) && sourceId > 0) {
      filters.sourceId = sourceId;
    }
    const category = (query.category ?? '').trim().slice(0, 30);
    if (category) {
      filters.category = category;
    }
    const q = (query.q ?? '').trim();
    if (q) {
      filters.q = q;
    }
    const { items, hasMore, pageSize, total } = await listEpisodes(50, (page - 1) * 50, filters);
    return sendCached(request, reply, { items, page, pageSize, hasMore, total }, 60);
  });

  // 订阅源列表(含各自单集数):按源筛选时查播客名等场景用
  app.get('/sources', async (request, reply) =>
    sendCached(request, reply, { items: await listSourcesWithCounts() }, 300),
  );

  // 分类列表(含单集数/源数,「其他」恒排末尾):时间线分类 chips 的数据源
  app.get('/categories', async (request, reply) =>
    sendCached(request, reply, { items: await listCategoriesWithCounts() }, 300),
  );
}
