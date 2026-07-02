import { marked } from "marked";
import type { EpisodeContent, EpisodeMeta, SummaryStatus } from "@/types";

/** 解析 episode .md：分离 frontmatter、摘要、正文。 */
export function parseEpisodeMarkdown(md: string, meta: EpisodeMeta): EpisodeContent {
  let fmRaw = "";
  let body = md;
  const fmMatch = md.match(/^---\n([\s\S]*?)\n---\n/);
  if (fmMatch) {
    fmRaw = fmMatch[1];
    body = md.slice(fmMatch[0].length);
  }

  const fm: Record<string, string> = {};
  for (const line of fmRaw.split("\n")) {
    const m = line.match(/^(\w+):\s*(.*)$/);
    if (m) {
      fm[m[1]] = m[2].replace(/^"|"$/g, "");
    }
  }

  const summaryMatch = body.match(/##\s*AI\s*摘要[\s\S]*?(?=\n##\s|$)/i);
  let summary = "";
  if (summaryMatch) {
    summary = summaryMatch[0].replace(/^##\s*AI\s*摘要\s*/i, "").trim();
  }

  const tagsMatch = body.match(/##\s*标签[\s\S]*?(?=\n##\s|$)/i);
  let tags: string[] = [];
  if (tagsMatch) {
    tags = tagsMatch[0]
      .replace(/^##\s*标签\s*/i, "")
      .split(/[#\s]+/)
      .map((t) => t.trim())
      .filter(Boolean);
  }

  const bodyMatch = body.match(/##\s*正文[\s\S]*$/i);
  const bodyText = bodyMatch ? bodyMatch[0].replace(/^##\s*正文\s*/i, "").trim() : "";

  return {
    frontmatter: {
      episode_id: fm.episode_id ?? meta.id,
      title: fm.title ?? meta.title,
      summary_status: (fm.summary_status as SummaryStatus) ?? meta.summary_status,
      generated_at: fm.generated_at || undefined,
      model: fm.model || undefined,
    },
    summary,
    tags: tags.length > 0 ? tags : meta.tags,
    body: bodyText,
  };
}

/** 把 markdown 文本渲染为 HTML。 */
export function renderMarkdown(md: string): string {
  return marked.parse(md, { async: false }) as string;
}
