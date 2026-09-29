/** DB 连通性检查（容器 healthcheck 用）：node scripts/health-db.mjs */
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
try {
  await pool.query('SELECT 1');
  process.exit(0);
} catch {
  process.exit(1);
} finally {
  await pool.end().catch(() => {});
}
