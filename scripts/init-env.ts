#!/usr/bin/env node
/** 生成 .env：基于 .env.example，为空缺的密钥填入随机值。
 *  用法：node scripts/init-env.ts [--llm-key <key>] [--force] */

import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(dirname(fileURLToPath(import.meta.url)));

function parseArgs(argv: string[]): Map<string, string | boolean> {
  const args = new Map<string, string | boolean>();
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]!;
    if (arg === '--force') {
      args.set('force', true);
    } else if (arg === '--llm-key') {
      args.set('llm-key', argv[++i] ?? '');
    }
  }
  return args;
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

const secret = () => randomBytes(24).toString('hex');
const generated: Record<string, string> = {
  POSTGRES_PASSWORD: secret().slice(0, 16),
  ADMIN_PASSWORD: secret().slice(0, 16),
  SESSION_SECRET: secret(),
  ...(typeof args.get('llm-key') === 'string' && args.get('llm-key')
    ? { LLM_API_KEY: args.get('llm-key') as string }
    : {}),
};

let out = readFileSync(examplePath, 'utf8');
for (const [key, value] of Object.entries(generated)) {
  out = out.replace(new RegExp(`^${key}=.*$`, 'm'), `${key}=${value}`);
}
// 本地 DATABASE_URL 与生成的 POSTGRES_PASSWORD 保持一致
out = out.replace(/^DATABASE_URL=.*$/m, `DATABASE_URL=postgres://sonde:${generated['POSTGRES_PASSWORD']}@localhost:5432/sonde`);

writeFileSync(envPath, out);
console.log(`已生成 ${envPath}`);
console.log(`  ADMIN_PASSWORD = ${generated['ADMIN_PASSWORD']}`);
if (!args.has('llm-key')) {
  console.log('  提示：LLM_API_KEY 未设置，可稍后编辑 .env 或运行：node scripts/init-env.ts --llm-key <key> --force');
}
