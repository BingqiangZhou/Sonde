/** 站点读路由（web 进程唯一数据入口）。 */

import type { FastifyInstance } from 'fastify';

import { SITE } from '@sonde/industry';

import { listEpisodes, listSourcesWithCounts, type EpisodeFilters } from '@sonde/backend';

export async function siteRoutes(app: FastifyInstance) {
  app.get('/meta', async () => ({
    name: SITE.name,
    nameEn: SITE.nameEn,
    subject: SITE.subject,
    homeTitle: SITE.homeTitle,
    description: SITE.description,
    tagline: SITE.tagline,
  }));

  // 时间线：全部单集按发布时间倒序，?page= 偏移分页（50/页）；
  // ?source= 按源筛选、?q= 标题/简介关键词（垃圾值一律忽略，回落全量）
  app.get('/episodes', async (request) => {
    const query = request.query as { page?: string; source?: string; q?: string };
    const page = Math.max(1, Number.parseInt(query.page ?? '1', 10) || 1);
    const filters: EpisodeFilters = {};
    const sourceId = Number.parseInt(query.source ?? '', 10);
    if (Number.isInteger(sourceId) && sourceId > 0) {
      filters.sourceId = sourceId;
    }
    const q = (query.q ?? '').trim();
    if (q) {
      filters.q = q;
    }
    const { items, hasMore, pageSize, total } = await listEpisodes(50, (page - 1) * 50, filters);
    return { items, page, pageSize, hasMore, total };
  });

  // 订阅源列表(含各自单集数):时间线上方筛选 chips 的数据源
  app.get('/sources', async () => {
    const items = await listSourcesWithCounts();
    return { items };
  });
}
