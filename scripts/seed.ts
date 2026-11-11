#!/usr/bin/env node
/** 将 industry/sources.json 同步进数据库（订阅的唯一事实来源）。
 *  条目格式：{ "name": "播客名", "feedUrl": "https://example.com/rss.xml", "intervalMinutes": 60 }
 *  语义：列表内增/改并重新激活；列表外停抓（is_active=false，历史单集保留）。 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { closeDb, normalizeSeedEntries, syncSources } from '@sonde/backend';

const root = dirname(dirname(fileURLToPath(import.meta.url)));

async function main() {
  const raw = JSON.parse(readFileSync(join(root, 'industry', 'sources.json'), 'utf8'));
  const entries = normalizeSeedEntries(raw);

  const result = await syncSources(entries);
  console.log(
    `sources 同步完成：新增 ${result.added}、更新 ${result.updated}、停用 ${result.deactivated}（列表共 ${entries.length} 条）`,
  );
  await closeDb();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
