#!/usr/bin/env node
/** 生成 .env：基于 .env.example，为空缺的密钥填入随机值。
 *  用法：node scripts/init-env.ts [--force] */

import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(dirname(fileURLToPath(import.meta.url)));

function parseArgs(argv: string[]): Set<string> {
  return new Set(argv.filter((arg) => arg === '--force'));
}

const args = parseArgs(process.argv.slice(2));
const envPath = join(root, '.env');
const examplePath = join(root, '.env.example');

if (!existsSync(examplePath)) {
  console.error('缺少 .env.example');
  process.exit(1);
}
if (existsSync(envPath) && !args.has('force')) {
  console.log('.env 已存在，跳过（用 --force 覆盖重建）');
  process.exit(0);
}

const postgresPassword = randomBytes(24).toString('hex').slice(0, 16);

let out = readFileSync(examplePath, 'utf8');
out = out.replace(/^POSTGRES_PASSWORD=.*$/m, `POSTGRES_PASSWORD=${postgresPassword}`);
// 本地 DATABASE_URL 与生成的 POSTGRES_PASSWORD 保持一致
out = out.replace(
  /^DATABASE_URL=.*$/m,
  `DATABASE_URL=postgres://sonde:${postgresPassword}@localhost:5432/sonde`,
);

writeFileSync(envPath, out);
console.log(`已生成 ${envPath}`);
