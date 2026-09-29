/** 从 industry/prompts 目录加载全部 .md 文件（无缓存：改 prompt 文件即刻生效，无需重启）。 */

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** 返回 { 'scoring': '...', 'rules-x': '...' }（key 为去扩展名文件名）。 */
export function loadPromptFiles(dir: string): Record<string, string> {
  const files: Record<string, string> = {};
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.md')) {
      files[entry.name.slice(0, -3)] = readFileSync(join(dir, entry.name), 'utf8');
    }
  }
  return files;
}
