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
  // api 在 web/caddy 反代之后：request.ip 取 X-Forwarded-For，登录限速才能按真实客户端 IP 生效
  trustProxy: true,
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
