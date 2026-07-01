/**
 * 简易正文提取：剥离 script/style/nav，优先 article/main，否则取 body。
 * 不追求完美 readability，提供可摘要的文本即可。
 */
export function extractMainContent(html: string): string {
  let doc = html.replace(/<(script|style|nav|header|footer|noscript)[\s\S]*?<\/\1>/gi, "");
  doc = doc.replace(/<!--[\s\S]*?-->/g, "");

  const block = doc.match(/<(article|main)[\s\S]*?<\/\1>/i);
  const target = block ? block[0] : doc;

  const textParts: string[] = [];
  const tagRegex = /<(h[1-6]|p|li|blockquote|pre)[^>]*>([\s\S]*?)<\/\1>/gi;
  let m: RegExpExecArray | null;
  while ((m = tagRegex.exec(target)) !== null) {
    const text = m[2]
      .replace(/<[^>]+>/g, "")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/\s+/g, " ")
      .trim();
    if (text) textParts.push(text);
  }

  if (textParts.length === 0) {
    const fallback = target.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
    if (fallback.length > 100) return fallback.slice(0, 8000);
  }

  return textParts.join("\n\n").slice(0, 8000);
}
