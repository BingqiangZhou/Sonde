/** 站点身份常量（自 ts-era `industry/site.ts` 内联，解 workspace 耦合）。
 *  权威定义在 `backend/app/industry/site.py`（v2 定制层）；两处保持同步。 */

export const SITE = {
  /** 站名（中文） */
  name: '声读',
  /** 站名（拉丁） */
  nameEn: 'Sonde',
  /** 内容主题词 */
  subject: '播客',
  /** 首页 title */
  homeTitle: '声读 — 每天一份值得读的播客日报',
  /** 站点描述（SEO） */
  description: '声读自动订阅播客、转写音频、AI 评分筛选，每天早晨生成一份可读的中文播客日报。',
  /** 一句话标语 */
  tagline: '把一天的播客，读成一份日报',
  locale: 'zh-CN',
  contactEmail: '',
  footerNote: '声读 · 个人播客知识库 · 内容版权归原作者所有',
} as const;
