/** HTTP 健康检查（容器 healthcheck 用）：node scripts/health-http.mjs <url> */
const url = process.argv[2] ?? 'http://localhost:3001/api/health';
try {
  const res = await fetch(url);
  process.exit(res.ok ? 0 : 1);
} catch {
  process.exit(1);
}
