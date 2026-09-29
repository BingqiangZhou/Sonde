/** 站点读路由（web 进程唯一数据入口）。 */

import type { FastifyInstance } from 'fastify';

import { SITE } from '@sonde/industry';

export async function siteRoutes(app: FastifyInstance) {
  app.get('/meta', async () => ({
    name: SITE.name,
    nameEn: SITE.nameEn,
    subject: SITE.subject,
    homeTitle: SITE.homeTitle,
    description: SITE.description,
    tagline: SITE.tagline,
  }));

  // 首页精选 / 单集详情 / 日报 等 route 在后续阶段加入
  app.get('/episodes', async () => ({ items: [], total: 0 }));
  app.get('/reports/daily/latest', async () => ({ available: false }));
}
