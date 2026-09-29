/** 轻量 Markdown 渲染：只覆盖本仓库 CHANGELOG 的子集
 *  （标题/引用块/无序列表/分隔线/段落 + 链接/行内代码/粗斜体）。
 *  输入是仓库自己的 CHANGELOG.md（受信内容，非用户输入），直接生成 HTML。 */

export function renderMarkdown(source: string): string {
  const lines = source.replace(/\r\n/g, '\n').split('\n');
  const out: string[] = [];
  let listBuffer: string[] = [];
  let quoteBuffer: string[] = [];

  const flushList = () => {
    if (listBuffer.length > 0) {
      out.push(`<ul>${listBuffer.map((item) => `<li>${item}</li>`).join('')}</ul>`);
      listBuffer = [];
    }
  };
  const flushQuote = () => {
    if (quoteBuffer.length > 0) {
      out.push(`<blockquote>${quoteBuffer.map((p) => `<p>${p}</p>`).join('')}</blockquote>`);
      quoteBuffer = [];
    }
  };

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();
    if (/^\s*-\s+/.test(line)) {
      flushQuote();
      listBuffer.push(inline(line.replace(/^\s*-\s+/, '')));
      continue;
    }
    flushList();
    if (line.startsWith('>')) {
      quoteBuffer.push(inline(line.replace(/^>\s?/, '')));
      continue;
    }
    flushQuote();
    if (line === '') {
      continue;
    }
    if (/^---+$/.test(line)) {
      out.push('<hr />');
      continue;
    }
    const heading = /^(#{1,4})\s+(.*)$/.exec(line);
    if (heading) {
      const level = (heading[1] as string).length;
      out.push(`<h${level}>${inline(heading[2] as string)}</h${level}>`);
      continue;
    }
    out.push(`<p>${inline(line)}</p>`);
  }
  flushList();
  flushQuote();
  return out.join('\n');
}

/** 行内元素：先抽出行内代码避免内部再被解析，再依次处理链接/粗体/斜体。 */
function inline(text: string): string {
  const escaped = escapeHtml(text);
  const codes: string[] = [];
  let result = escaped.replace(/`([^`]+)`/g, (_match, code: string) => {
    codes.push(code);
    return `\u0000${codes.length - 1}\u0000`;
  });
  result = result.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_m, label: string, href: string) => {
    return `<a href="${href}" target="_blank" rel="noreferrer">${label}</a>`;
  });
  result = result.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  result = result.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  result = result.replace(/\u0000(\d+)\u0000/g, (_m, index: string) => `<code>${codes[Number(index)]}</code>`);
  return result;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
