/** web 进程入口：/api/* 反代到 api 服务，其余交给 React Router SSR handler。
 *  使浏览器端（admin 表单等）可以同源访问 API。 */

import { createServer } from 'node:http';

import { createRequestHandler } from 'react-router';

const build = await import('./build/server/index.js');
const handler = createRequestHandler(build);

const API_URL = process.env.API_URL ?? 'http://localhost:3001';
const PORT = Number.parseInt(process.argv[2] ?? process.env.PORT ?? '3000', 10);

const server = createServer(async (req, res) => {
  try {
    if (req.url?.startsWith('/api/')) {
      await proxyToApi(req, res);
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
      body: method === 'GET' || method === 'HEAD' ? undefined : req,
      // @ts-expect-error Node fetch 支持双向流
      duplex: 'half',
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

async function proxyToApi(req, res) {
  const target = `${API_URL}${req.url}`;
  const headers = { ...req.headers };
  delete headers.host;
  try {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
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
