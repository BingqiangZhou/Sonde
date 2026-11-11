/** 站点读路由（web 进程唯一数据入口）。 */

import type { FastifyInstance } from 'fastify';

import { SITE } from '@sonde/industry';

import { listEpisodes } from '@sonde/backend';

export async function siteRoutes(app: FastifyInstance) {
  app.get('/meta', async () => ({
    name: SITE.name,
    nameEn: SITE.nameEn,
    subject: SITE.subject,
    homeTitle: SITE.homeTitle,
    description: SITE.description,
    tagline: SITE.tagline,
  }));

  // 时间线：全部单集按发布时间倒序，?page= 偏移分页（50/页）
  app.get('/episodes', async (request) => {
    const query = request.query as { page?: string };
    const page = Math.max(1, Number.parseInt(query.page ?? '1', 10) || 1);
    const { items, hasMore, pageSize } = await listEpisodes(50, (page - 1) * 50);
    return { items, page, pageSize, hasMore };
  });
}
