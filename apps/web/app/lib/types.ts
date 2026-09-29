/** 站点 API 返回类型（与 apps/api site 路由对齐）。 */

export interface SiteMeta {
  name: string;
  nameEn: string;
  subject: string;
  homeTitle: string;
  description: string;
  tagline: string;
}

export interface EpisodeItem {
  id: number;
  podcast: string;
  originalTitle: string;
  titleZh: string;
  summaryZh: string;
  reasonZh: string;
  category: string;
  categoryLabel: string;
  score: number;
  url: string | null;
  publishedAt: string | null;
  durationSeconds: number | null;
}

/** 全部动态条目：在 EpisodeItem 之上附带评分理由与入选状态 */
export interface AnalyzedEpisodeItem extends EpisodeItem {
  reason: string;
  selected: boolean;
}

export interface ReportItem {
  episodeId: number;
  podcast: string;
  originalTitle: string;
  titleZh: string;
  summaryZh: string;
  reasonZh: string;
  category: string;
  categoryLabel: string;
  score: number;
  url: string | null;
  publishedAt: string | null;
  durationSeconds: number | null;
}

export interface ReportSection {
  section: string;
  items: ReportItem[];
}

export interface DailyReportContent {
  title: string;
  leadParagraph: string;
  highlights: string[];
  sections: ReportSection[];
  stats: { selected: number; maxItems: number };
}

export interface DailyReport {
  reportKey: string;
  generatedAt: string;
  revision: number;
  content: DailyReportContent;
}

/** 报刊种类：daily | weekly | monthly（正文结构与 DailyReport 一致） */
export type ReportKind = 'daily' | 'weekly' | 'monthly';
export type PeriodicReport = DailyReport;
