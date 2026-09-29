/** 声读定制层公共出口：站点身份、分类、精选门槛。 */

export { SITE } from './site.ts';
export { CATEGORIES, DEFAULT_CATEGORY, categoryLabel, sectionOrderFor } from './taxonomy.ts';
export type { Category } from './taxonomy.ts';
export { SELECTION, thresholdFor } from './selection.ts';
