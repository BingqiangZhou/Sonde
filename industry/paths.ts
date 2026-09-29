/** industry 包的文件系统定位（仅 Node 侧使用；web 客户端不要导入此模块）。 */

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

export const industryDir = here;
export const promptsDir = join(here, 'prompts');
