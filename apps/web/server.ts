/** web 进程入口：/api/* 反代到 api、静态文件（build/client）、其余交给 React Router SSR handler。 */

import { createServer } from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

import { createRequestHandler, type ServerBuild } from 'react-router';

const build = (await import('./build/server/index.js')) as unknown as ServerBuild;
const handler = createRequestHandler(build);

const API_URL = process.env.API_URL ?? 'http://localhost:3001';
const PORT = Number.parseInt(process.argv[2] ?? process.env.PORT ?? '3000', 10);
const CLIENT_DIR = fileURLToPath(new URL('./build/client/', import.meta.url));

const MIME_TYPES: Record<string, string> = {
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.map': 'application/json',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
};

const server = createServer(async (req, res) => {
  try {
    if (req.url?.startsWith('/api/')) {
      await proxyToApi(req, res);
      return;
    }
    if ((req.method === 'GET' || req.method === 'HEAD') && serveStatic(req, res)) {
      return;
    }
    // Node req → 标准 Request → React Router handler → 标准 Response → Node res
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
    const headers = new Headers();
    for (const [key, value] of Object.entries(req.headers)) {
      if (value !== undefined) {
        headers.set(key, Array.isArray(value) ? value.join(', ') : value);
      }
    }
    const method = req.method ?? 'GET';
    const request = new Request(url, {
      method,
      headers,
      body: method === 'GET' || method === 'HEAD' ? undefined : (req as unknown as BodyInit),
      // Node fetch 需要 duplex 提示以支持请求体流；DOM 类型里没有该字段
      ...({ duplex: 'half' } as RequestInit),
    });
    const response = await handler(request);
    res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
    if (response.body) {
      const reader = response.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
    }
    res.end();
  } catch (error) {
    console.error('[web] request failed:', error);
    res.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('服务器内部错误');
  }
});

/** 静态文件：命中 build/client 下的真实文件则直接返回，否则交回 SSR。
 *  /assets/* 为带哈希的不可变资源，可长缓存。 */
function serveStatic(req: InstanceType<typeof import('node:http').IncomingMessage>, res: InstanceType<typeof import('node:http').ServerResponse>): boolean {
  const path = (req.url ?? '/').split('?')[0] as string;
  if (path.includes('..')) {
    return false;
  }
  const filePath = normalize(join(CLIENT_DIR, path));
  if (!filePath.startsWith(normalize(CLIENT_DIR))) {
    return false;
  }
  let stats;
  try {
    stats = statSync(filePath);
  } catch {
    return false;
  }
  if (!stats.isFile()) {
    return false;
  }

  const type = MIME_TYPES[extname(filePath).toLowerCase()] ?? 'application/octet-stream';
  const immutable = path.startsWith('/assets/');
  res.writeHead(200, {
    'content-type': type,
    'content-length': stats.size,
    'cache-control': immutable ? 'public, max-age=31536000, immutable' : 'no-cache',
  });
  if (req.method === 'HEAD') {
    res.end();
    return true;
  }
  createReadStream(filePath).pipe(res);
  return true;
}

async function proxyToApi(req: InstanceType<typeof import('node:http').IncomingMessage>, res: InstanceType<typeof import('node:http').ServerResponse>) {
  const target = `${API_URL}${req.url}`;
  const headers = { ...req.headers } as Record<string, string>;
  delete headers.host;
  try {
    const chunks: Buffer[] = [];
    for await (const chunk of req) {
      chunks.push(chunk as Buffer);
    }
    const response = await fetch(target, {
      method: req.method,
      headers,
      body: chunks.length > 0 ? Buffer.concat(chunks) : undefined,
      redirect: 'manual',
    });
    res.writeHead(response.status, Object.fromEntries(response.headers.entries()));
    const buffer = Buffer.from(await response.arrayBuffer());
    res.end(buffer);
  } catch (error) {
    console.error('[web] api proxy failed:', error);
    res.writeHead(502, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ error: 'API 服务不可用' }));
  }
}

server.listen(PORT, () => {
  console.log(`[sonde-web] listening on :${PORT} (api proxy → ${API_URL})`);
});
