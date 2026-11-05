/** 声读 api 进程：站点读 API + admin API + 健康检查。 */

import Fastify from 'fastify';
import cookie from '@fastify/cookie';

import { AppError, closeDb, loadConfig, ping } from '@sonde/backend';

import { adminRoutes } from './routes/admin.ts';
import { siteRoutes } from './routes/site.ts';

const config = loadConfig();

if (!config.sessionSecret) {
  // 不再回退弱默认密钥：cookie 签名密钥缺失应拒止启动（init-env 会生成）
  throw new Error('SESSION_SECRET 未配置：请运行 node scripts/init-env.ts 生成 .env，或手动设置 SESSION_SECRET');
}

const app = Fastify({
  logger: { level: process.env.LOG_LEVEL ?? 'info' },
  // 只信任一跳（web 反代，它在 XFF 链尾追加真实来源地址）：
  // request.ip 取链尾条目，客户端伪造的 XFF 无法旋转登录限速桶。
  // Fastify 5 类型不接受数字，用 proxy-addr 的等价字符串形式 '1'（= 1 跳）。
  // 注意：若启用 Caddy（https profile），浏览器→caddy→web→api 共两跳代理，
  // 所有请求会落在 caddy 容器 IP 一个桶里（无法绕过，但共享锁定窗口）；
  // 如需按真实客户端分桶，可改为 '2'。
  trustProxy: '1',
});

await app.register(cookie, {
  secret: config.sessionSecret,
});

app.get('/api/health', async () => ({ status: 'ok', service: 'sonde-api' }));

app.get('/api/health/ready', async (_request, reply) => {
  try {
    const ok = await ping();
    if (!ok) {
      throw new Error('db ping returned false');
    }
    return { status: 'ready', database: 'up' };
  } catch (error) {
    app.log.warn(error, 'readiness check failed');
    reply.code(503);
    return { status: 'unavailable', database: 'down' };
  }
});

await app.register(siteRoutes, { prefix: '/api/site' });
await app.register(adminRoutes, { prefix: '/api/admin' });

app.setErrorHandler((error, request, reply) => {
  if (error instanceof AppError) {
    reply.code(error.statusCode).send({ error: error.message });
    return;
  }
  request.log.error(error);
  reply.code(500).send({ error: '服务器内部错误' });
});

const start = async () => {
  await app.listen({ port: config.apiPort, host: '0.0.0.0' });
  app.log.info(`sonde-api listening on :${config.apiPort}`);
};

const shutdown = async (signal: string) => {
  app.log.info({ signal }, 'shutting down');
  await app.close();
  await closeDb();
  process.exit(0);
};

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

start().catch((error) => {
  app.log.error(error, 'failed to start');
  process.exit(1);
});
