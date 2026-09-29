/** 站点读路由（web 进程唯一数据入口）。 */

import type { FastifyInstance } from 'fastify';

import { SITE } from '@sonde/industry';

import {
  getLatestReport,
  getReport,
  isReportKind,
  listAllAnalyzedEpisodes,
  listReportKeys,
} from '@sonde/backend';
import { getSelectedEpisode, listSelectedEpisodes } from '@sonde/backend';

export async function siteRoutes(app: FastifyInstance) {
  app.get('/meta', async () => ({
    name: SITE.name,
    nameEn: SITE.nameEn,
    subject: SITE.subject,
    homeTitle: SITE.homeTitle,
    description: SITE.description,
    tagline: SITE.tagline,
  }));

  app.get('/episodes', async (request) => {
    const query = request.query as { limit?: string };
    const limit = Number.parseInt(query.limit ?? '20', 10);
    const items = await listSelectedEpisodes(Number.isFinite(limit) ? limit : 20);
    return { items };
  });

  // 全部动态：所有已分析单集（含未入选），?page= 偏移分页
  app.get('/episodes/all', async (request) => {
    const query = request.query as { page?: string };
    const page = Math.max(1, Number.parseInt(query.page ?? '1', 10) || 1);
    const { items, total } = await listAllAnalyzedEpisodes(50, (page - 1) * 50);
    return {
      items,
      total,
      page,
      pages: Math.max(1, Math.ceil(total / 50)),
    };
  });

  app.get('/episodes/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const episodeId = Number.parseInt(id, 10);
    if (!Number.isFinite(episodeId)) {
      reply.code(400);
      return { error: 'invalid episode id' };
    }
    const item = await getSelectedEpisode(episodeId);
    if (!item) {
      reply.code(404);
      return { error: 'episode not found' };
    }
    return { episode: item };
  });

  // ── 报刊：daily | weekly | monthly ────────────────────────
  const KEY_RE: Record<string, RegExp> = {
    daily: /^\d{4}-\d{2}-\d{2}$/,
    weekly: /^\d{4}-\d{2}-\d{2}$/,
    monthly: /^\d{4}-\d{2}$/,
  };

  app.get('/reports/:kind/latest', async (request, reply) => {
    const { kind } = request.params as { kind: string };
    if (!isReportKind(kind)) {
      reply.code(400);
      return { error: 'invalid report kind' };
    }
    const report = await getLatestReport(kind);
    if (!report) {
      reply.code(404);
      return { error: 'no report yet' };
    }
    return report;
  });

  app.get('/reports/:kind/:key', async (request, reply) => {
    const { kind, key } = request.params as { kind: string; key: string };
    if (!isReportKind(kind)) {
      reply.code(400);
      return { error: 'invalid report kind' };
    }
    if (!(KEY_RE[kind] as RegExp).test(key)) {
      reply.code(400);
      return { error: 'invalid report key' };
    }
    const report = await getReport(kind, key);
    if (!report) {
      reply.code(404);
      return { error: 'report not found' };
    }
    return report;
  });

  app.get('/reports/:kind', async (request) => {
    const { kind } = request.params as { kind: string };
    const query = request.query as { page?: string; size?: string };
    const page = Number.parseInt(query.page ?? '1', 10);
    const size = Number.parseInt(query.size ?? '30', 10);
    if (!isReportKind(kind)) {
      return { keys: [], total: 0 };
    }
    return listReportKeys(
      kind,
      Number.isFinite(page) ? page : 1,
      Number.isFinite(size) ? size : 30,
    );
  });
}
