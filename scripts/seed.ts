#!/usr/bin/env node
/** 将 industry/sources.json 种子进数据库（已存在的 feedUrl 跳过）。
 *  sources.json 条目格式：
 *  { "name": "播客名", "feedUrl": "https://example.com/rss.xml", "tier": "T1", "intervalMinutes": 60 }
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import pg from 'pg';

const root = dirname(dirname(fileURLToPath(import.meta.url)));

interface SeedSource {
  name: string;
  feedUrl: string;
  tier?: string;
  intervalMinutes?: number;
}

async function main() {
  const connectionString = process.env.DATABASE_URL ?? 'postgres://sonde:sonde@localhost:5432/sonde';
  const pool = new pg.Pool({ connectionString });

  const raw = JSON.parse(readFileSync(join(root, 'industry', 'sources.json'), 'utf8')) as SeedSource[];
  if (!Array.isArray(raw)) {
    throw new Error('industry/sources.json 必须是数组');
  }

  let inserted = 0;
  for (const entry of raw) {
    if (!entry.name || !entry.feedUrl) {
      console.warn('跳过缺少 name/feedUrl 的条目');
      continue;
    }
    const existing = await pool.query(
      'SELECT id FROM sources WHERE lower(config->>\'feedUrl\') = lower($1) LIMIT 1',
      [entry.feedUrl],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      continue;
    }
    await pool.query(
      `INSERT INTO sources (name, config, tier, interval_minutes)
       VALUES ($1, jsonb_build_object('feedUrl', $2), $3, $4)`,
      [entry.name, entry.feedUrl, entry.tier ?? 'T2', entry.intervalMinutes ?? 60],
    );
    inserted++;
    console.log(`added source: ${entry.name} (${entry.feedUrl})`);
  }

  console.log(`seeded ${inserted} source(s), total entries: ${raw.length}`);
  await pool.end();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
