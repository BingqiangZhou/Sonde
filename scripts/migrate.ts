#!/usr/bin/env node
/** 依序应用 database/migrations/*.sql（事务内），已应用的记录在 schema_migrations。 */

import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import pg from 'pg';

const root = dirname(dirname(fileURLToPath(import.meta.url)));

async function main() {
  const connectionString = process.env.DATABASE_URL ?? 'postgres://sonde:sonde@localhost:5432/sonde';
  const pool = new pg.Pool({ connectionString });

  const migrationsDir = join(root, 'database', 'migrations');
  const files = readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  const applied = new Set(
    (await pool.query<{ name: string }>('SELECT name FROM schema_migrations')).rows.map((r) => r.name),
  );

  let count = 0;
  for (const file of files) {
    if (applied.has(file)) {
      continue;
    }
    const sqlText = readFileSync(join(migrationsDir, file), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sqlText);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`applied ${file}`);
      count++;
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      console.error(`failed ${file}:`, error instanceof Error ? error.message : error);
      process.exitCode = 1;
      break;
    } finally {
      client.release();
    }
  }

  if (count === 0 && !process.exitCode) {
    console.log('database already up to date');
  }
  await pool.end();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
