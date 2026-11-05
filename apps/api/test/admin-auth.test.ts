import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import Fastify from 'fastify';
import cookie from '@fastify/cookie';

import { adminRoutes } from '../src/routes/admin.ts';

const SECRET = 'test-secret-for-admin-auth';

/** 只挂 login/logout/session 相关能力；DB 路由不触达。
 *  /__sign 借助 @fastify/cookie 的 reply.signCookie 构造测试用签名 cookie。 */
async function makeApp() {
  const app = Fastify();
  await app.register(cookie, { secret: SECRET });
  app.get('/api/__sign', async (request, reply) => {
    const { value } = (request.query ?? {}) as { value?: string };
    return reply.signCookie(value ?? '') as string;
  });
  await app.register(adminRoutes, { prefix: '/api/admin' });
  return app;
}

/** 限速状态是模块级 Map——每个用例用独立 IP 隔离。 */
const IP_A = '10.0.0.1';
const IP_B = '10.0.0.2';
const IP_C = '10.0.0.3';
const IP_D = '10.0.0.4';

function setAdminPassword(value: string | undefined) {
  if (value === undefined) {
    delete process.env.ADMIN_PASSWORD;
  } else {
    process.env.ADMIN_PASSWORD = value;
  }
}

beforeEach(() => {
  setAdminPassword('correct-password');
});

afterEach(() => {
  setAdminPassword(undefined);
  vi.useRealTimers();
});

describe('POST /api/admin/login 限速', () => {
  it('密码错误 → 401；连续 5 次错误后锁定，正确密码也 429（带 Retry-After）', async () => {
    const app = await makeApp();
    for (let i = 0; i < 5; i++) {
      const res = await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'wrong' }, remoteAddress: IP_A });
      expect(res.statusCode).toBe(401);
    }
    const locked = await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'correct-password' }, remoteAddress: IP_A });
    expect(locked.statusCode).toBe(429);
    expect(locked.json()).toMatchObject({ error: expect.stringContaining('尝试次数过多') });
    const retryAfter = Number(locked.headers['retry-after']);
    expect(Number.isFinite(retryAfter)).toBe(true);
    expect(retryAfter).toBeGreaterThan(0);
    expect(retryAfter).toBeLessThanOrEqual(15 * 60);
  });

  it('限速按 IP 隔离：A 锁定不影响 B', async () => {
    const app = await makeApp();
    for (let i = 0; i < 5; i++) {
      await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'wrong' }, remoteAddress: IP_A });
    }
    const res = await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'correct-password' }, remoteAddress: IP_B });
    expect(res.statusCode).toBe(200);
  });

  it('锁定 15 分钟后自动解除；登录成功清除计数', async () => {
    const app = await makeApp();
    // 只伪造 Date：锁的过期判定用 Date.now，不能冻结真实定时器（inject 会挂起）
    vi.useFakeTimers({ toFake: ['Date'] });
    for (let i = 0; i < 5; i++) {
      await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'wrong' }, remoteAddress: IP_A });
    }
    vi.setSystemTime(Date.now() + 15 * 60 * 1000 + 1000);
    const res = await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'correct-password' }, remoteAddress: IP_A });
    expect(res.statusCode).toBe(200);
  });

  it('未配置 ADMIN_PASSWORD → 503', async () => {
    setAdminPassword(undefined);
    const app = await makeApp();
    const res = await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'x' }, remoteAddress: IP_A });
    expect(res.statusCode).toBe(503);
  });
});

describe('会话 cookie（带过期语义的签名载荷）', () => {
  it('登录成功 → cookie 载荷是 {v:1, exp} JSON，/session 认证通过', async () => {
    const app = await makeApp();
    const login = await app.inject({ method: 'POST', url: '/api/admin/login', payload: { password: 'correct-password' }, remoteAddress: IP_C });
    expect(login.statusCode).toBe(200);

    const setCookie = login.headers['set-cookie'];
    const raw = (Array.isArray(setCookie) ? setCookie[0] : setCookie) ?? '';
    const cookieValue = raw.split(';')[0]?.slice('sonde_admin='.length) ?? '';
    const unsigned = decodeURIComponent(cookieValue.split('.')[0] ?? '');
    const payload = JSON.parse(unsigned) as { v?: number; exp?: number };
    expect(payload.v).toBe(1);
    expect(payload.exp).toBeGreaterThan(Date.now());

    const session = await app.inject({ method: 'GET', url: '/api/admin/session', headers: { cookie: `sonde_admin=${cookieValue}` } });
    expect(session.json()).toMatchObject({ authenticated: true });
  });

  it('过期载荷（exp 已过）→ /session 401', async () => {
    const app = await makeApp();
    const expired = JSON.stringify({ v: 1, exp: Date.now() - 1000 });
    const signed = (await app.inject({ method: 'GET', url: `/api/__sign?value=${encodeURIComponent(expired)}` })).body;
    const session = await app.inject({ method: 'GET', url: '/api/admin/session', headers: { cookie: `sonde_admin=${signed}` } });
    expect(session.statusCode).toBe(401);
    expect(session.json()).toMatchObject({ authenticated: false });
  });

  it('旧版常量载荷 "ok"（已签名）→ 拒绝', async () => {
    const app = await makeApp();
    const legacy = (await app.inject({ method: 'GET', url: `/api/__sign?value=${encodeURIComponent('ok')}` })).body;
    const session = await app.inject({ method: 'GET', url: '/api/admin/session', headers: { cookie: `sonde_admin=${legacy}` } });
    expect(session.statusCode).toBe(401);
  });

  it('篡改载荷 → 拒绝', async () => {
    const app = await makeApp();
    const session = await app.inject({
      method: 'GET',
      url: '/api/admin/session',
      headers: { cookie: `sonde_admin=${JSON.stringify({ v: 1, exp: Date.now() + 1000 })}.deadbeef` },
    });
    expect(session.statusCode).toBe(401);
  });
});
