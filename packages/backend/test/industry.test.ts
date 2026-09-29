import { describe, expect, it } from 'vitest';

import {
  CATEGORIES,
  DEFAULT_CATEGORY,
  SELECTION,
  categoryLabel,
  sectionOrderFor,
  thresholdFor,
} from '@sonde/industry';

describe('thresholdFor', () => {
  it('resolves per-tier thresholds with a default fallback', () => {
    expect(thresholdFor('T1')).toBe(SELECTION.thresholds['T1']);
    expect(thresholdFor('T2')).toBe(SELECTION.thresholds['T2']);
    expect(thresholdFor('T9')).toBe(SELECTION.defaultThreshold);
    expect(thresholdFor(null)).toBe(SELECTION.defaultThreshold);
  });
});

describe('categoryLabel', () => {
  it('maps known keys and falls back for unknown', () => {
    expect(categoryLabel('tech-ai')).toBe(CATEGORIES.find((c) => c.key === 'tech-ai')?.label);
    expect(categoryLabel('nonexistent')).toBe('综合');
    expect(categoryLabel(null)).toBe('综合');
    expect(DEFAULT_CATEGORY).toBe('general');
  });
});

describe('sectionOrderFor', () => {
  it('groups categories into sections in taxonomy order', () => {
    const sections = sectionOrderFor(['life-growth', 'tech-ai', 'business']);
    expect(sections.map((s) => s.section)).toEqual(['科技', '商业', '文化与生活']);
    expect(sections[0]?.categories).toEqual(['tech-ai']);
  });

  it('dedupes and merges same-section categories', () => {
    const sections = sectionOrderFor(['society-culture', 'life-growth']);
    expect(sections).toHaveLength(1);
    expect(sections[0]?.section).toBe('文化与生活');
    expect(sections[0]?.categories).toEqual(['society-culture', 'life-growth']);
  });

  it('puts unknown categories into a trailing section', () => {
    const sections = sectionOrderFor(['weird', 'general']);
    const names = sections.map((s) => s.section);
    expect(names[names.length - 1]).toBe('其他');
  });

  it('returns empty for empty input', () => {
    expect(sectionOrderFor([])).toEqual([]);
  });
});
