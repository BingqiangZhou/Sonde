/** admin API：登录会话（签名 cookie）+ 源管理 + 单集诊断 + 日报触发 + 成本汇总。 */

import { timingSafeEqual } from 'node:crypto';

import type { FastifyInstance, FastifyRequest } from 'fastify';

import {
  isReportKind,
  loadConfig,
  receiptsSummary,
  rows,
  sendJob,
  sql,
  ValidationError,
} from '@sonde/backend';

const COOKIE_NAME = 'sonde_admin';

export async function adminRoutes(app: FastifyInstance) {
  // ── 登录 / 会话 ────────────────────────────────────────────
  app.post('/login', async (request, reply) => {
    const { password } = (request.body ?? {}) as { password?: string };
    const config = loadConfig();
    if (!config.adminPassword) {
      reply.code(503);
      return { error: '未配置 ADMIN_PASSWORD' };
    }
    if (!password || !safeEqual(password, config.adminPassword)) {
      reply.code(401);
      return { error: '密码错误' };
    }
    reply.setCookie(COOKIE_NAME, 'ok', {
      path: '/',
      httpOnly: true,
      sameSite: 'lax',
      signed: true,
      maxAge: 7 * 24 * 60 * 60,
    });
    return { ok: true };
  });

  app.post('/logout', async (_request, reply) => {
    reply.clearCookie(COOKIE_NAME, { path: '/' });
    return { ok: true };
  });

  app.get('/session', async (request, reply) => {
    if (!isAdmin(request)) {
      reply.code(401);
      return { authenticated: false };
    }
    return { authenticated: true };
  });

  // ── 以下全部要求登录（login/logout/session 除外）─────────
  app.addHook('preHandler', async (request, reply) => {
    // 注意：插件内 request.url 是带 /api/admin 前缀的完整路径
    const url = request.url.split('?')[0] ?? '';
    const exempt =
      url.endsWith('/login') || url.endsWith('/logout') || url.endsWith('/session');
    if (exempt) {
      return;
    }
    if (!isAdmin(request)) {
      return reply.code(401).send({ error: '未登录' });
    }
  });

  // ── 仪表盘 ────────────────────────────────────────────────
  app.get('/stats', async () => {
    const [sources, episodeStatuses, reports, latest] = await Promise.all([
      rows<{ total: number; active: number }>(sql`
        SELECT count(*)::int AS total, count(*) FILTER (WHERE is_active)::int AS active FROM sources
      `),
      rows<{ transcribe_status: string; count: number }>(sql`
        SELECT transcribe_status, count(*)::int AS count FROM episodes GROUP BY 1
      `),
      rows<{ count: number }>(sql`SELECT count(*)::int AS count FROM daily_reports`),
      rows<{ report_key: string }>(sql`
        SELECT report_key::text FROM daily_reports ORDER BY report_key DESC LIMIT 1
      `),
    ]);
    return {
      sources: sources[0] ?? { total: 0, active: 0 },
      episodes: Object.fromEntries(episodeStatuses.map((r) => [r.transcribe_status, r.count])),
      reports: reports[0]?.count ?? 0,
      latestReportKey: latest[0]?.report_key ?? null,
    };
  });

  // ── 源管理 ────────────────────────────────────────────────
  app.get('/sources', async () => {
    return {
      sources: await rows(sql`
        SELECT id, name, config->>'feedUrl' AS "feedUrl", tier, interval_minutes AS "intervalMinutes",
               is_active AS "isActive", cursor->>'lastFetchedAt' AS "lastFetchedAt",
               health, updated_at AS "updatedAt"
        FROM sources ORDER BY created_at ASC
      `),
    };
  });

  app.post('/sources', async (request) => {
    const body = (request.body ?? {}) as {
      name?: string;
      feedUrl?: string;
      tier?: string;
      intervalMinutes?: number;
    };
    if (!body.name || !body.feedUrl) {
      throw new ValidationError('name 与 feedUrl 必填');
    }
    const tier = body.tier === 'T1' ? 'T1' : 'T2';
    const interval = clampInt(body.intervalMinutes, 5, 1440, 60);
    await rows(sql`
      INSERT INTO sources (name, config, tier, interval_minutes)
      VALUES (${body.name}, jsonb_build_object('feedUrl', ${body.feedUrl}::text), ${tier}, ${interval})
    `);
    return { ok: true };
  });

  app.patch('/sources/:id', async (request) => {
    const { id } = request.params as { id: string };
    const body = (request.body ?? {}) as {
      name?: string;
      tier?: string;
      intervalMinutes?: number;
      isActive?: boolean;
    };
    const sourceId = parseId(id);
    const sets: string[] = ['updated_at = now()'];
    const values: unknown[] = [sourceId];
    if (body.name !== undefined) {
      values.push(body.name);
      sets.push(`name = $${values.length}`);
    }
    if (body.tier === 'T1' || body.tier === 'T2') {
      values.push(body.tier);
      sets.push(`tier = $${values.length}`);
    }
    if (body.intervalMinutes !== undefined) {
      values.push(clampInt(body.intervalMinutes, 5, 1440, 60));
      sets.push(`interval_minutes = $${values.length}`);
    }
    if (body.isActive !== undefined) {
      values.push(body.isActive);
      sets.push(`is_active = $${values.length}`);
    }
    await rows(`UPDATE sources SET ${sets.join(', ')} WHERE id = $1`, values);
    return { ok: true };
  });

  app.delete('/sources/:id', async (request) => {
    const { id } = request.params as { id: string };
    await rows(sql`DELETE FROM sources WHERE id = ${parseId(id)}`);
    return { ok: true };
  });

  app.post('/sources/:id/fetch-now', async (request) => {
    const { id } = request.params as { id: string };
    const sourceId = parseId(id);
    await sendJob('sources.fetch', { sourceId });
    return { ok: true };
  });

  // ── 单集诊断 ──────────────────────────────────────────────
  app.get('/episodes', async (request) => {
    const query = request.query as { status?: string; limit?: string };
    const limit = clampInt(Number.parseInt(query.limit ?? '50', 10), 1, 200, 50);
    const status = query.status && query.status !== 'all' ? query.status : null;
    return {
      episodes: await rows(sql`
        SELECT e.id, e.title, s.name AS podcast, e.published_at AS "publishedAt",
               e.duration_seconds AS "durationSeconds",
               e.transcribe_status AS "transcribeStatus", e.transcribe_error AS "transcribeError",
               a.score, a.selected, a.category
        FROM episodes e
        JOIN sources s ON s.id = e.source_id
        LEFT JOIN analyses a ON a.episode_id = e.id AND a.is_current
        WHERE (${status}::text IS NULL OR e.transcribe_status = ${status}::text)
        ORDER BY e.created_at DESC
        LIMIT ${limit}
      `),
    };
  });

  // ── 报刊 ──────────────────────────────────────────────────
  app.post('/reports/generate', async (request) => {
    const body = (request.body ?? {}) as { kind?: string; reportKey?: string };
    const kind = body.kind ?? 'daily';
    if (!isReportKind(kind)) {
      throw new ValidationError('kind 应为 daily | weekly | monthly');
    }
    const keyRe = kind === 'monthly' ? /^\d{4}-\d{2}$/ : /^\d{4}-\d{2}-\d{2}$/;
    if (body.reportKey && !keyRe.test(body.reportKey)) {
      throw new ValidationError(
        kind === 'monthly' ? '月报 reportKey 格式应为 YYYY-MM' : 'reportKey 格式应为 YYYY-MM-DD',
      );
    }
    await sendJob(`reports.${kind}`, body.reportKey ? { reportKey: body.reportKey } : {});
    return { ok: true };
  });

  // ── 成本 ──────────────────────────────────────────────────
  app.get('/costs', async () => {
    const [summary, recent] = await Promise.all([
      receiptsSummary(30),
      rows(sql`
        SELECT service, operation, model, input_tokens AS "inputTokens",
               output_tokens AS "outputTokens", audio_seconds AS "audioSeconds",
               ok, error, duration_ms AS "durationMs", created_at AS "createdAt"
        FROM receipts ORDER BY created_at DESC LIMIT 50
      `),
    ]);
    return { summary, recent };
  });
}

function isAdmin(request: FastifyRequest): boolean {
  const raw = request.cookies[COOKIE_NAME];
  if (!raw) {
    return false;
  }
  const unsigned = request.unsignCookie(raw);
  return unsigned.valid && unsigned.value === 'ok';
}

function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    return false;
  }
  return timingSafeEqual(bufA, bufB);
}

function parseId(value: string): number {
  const id = Number.parseInt(value, 10);
  if (!Number.isFinite(id)) {
    throw new ValidationError('invalid id');
  }
  return id;
}

function clampInt(value: number | undefined, min: number, max: number, fallback: number): number {
  if (value === undefined || !Number.isFinite(value)) {
    return fallback;
  }
  return Math.min(Math.max(Math.round(value), min), max);
}
