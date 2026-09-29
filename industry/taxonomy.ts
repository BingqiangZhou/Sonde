/** 日报分节与分类（声读定制层）。
 *  评分/写作阶段为单集选择一个 category key；日报按 section 分节呈现。 */

export interface Category {
  /** URL/存储 用的 key */
  key: string;
  /** 中文标签 */
  label: string;
  /** 日报中的分节（同一 section 的分类归到一节） */
  section: string;
}

export const CATEGORIES: Category[] = [
  { key: 'tech-ai', label: '科技与 AI', section: '科技' },
  { key: 'business', label: '商业与财经', section: '商业' },
  { key: 'society-culture', label: '文化与社会', section: '文化与生活' },
  { key: 'life-growth', label: '生活与成长', section: '文化与生活' },
  { key: 'general', label: '综合', section: '其他' },
];

export const DEFAULT_CATEGORY = 'general';

export function categoryLabel(key: string | null | undefined): string {
  return CATEGORIES.find((c) => c.key === key)?.label ?? '综合';
}

/** 日报分节顺序：先配置的 section 在前，未匹配的归入“其他”。 */
export function sectionOrderFor(categoryKeys: Iterable<string>): { section: string; categories: string[] }[] {
  const sections = new Map<string, string[]>();
  for (const key of categoryKeys) {
    const section = CATEGORIES.find((c) => c.key === key)?.section ?? '其他';
    const list = sections.get(section) ?? [];
    if (!list.includes(key)) {
      list.push(key);
    }
    sections.set(section, list);
  }
  const ordered = CATEGORIES.map((c) => c.section).filter((s, i, arr) => arr.indexOf(s) === i);
  return [...sections.keys()]
    .sort((a, b) => {
      const ia = ordered.indexOf(a);
      const ib = ordered.indexOf(b);
      return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib);
    })
    .map((section) => ({ section, categories: sections.get(section) ?? [] }));
}
