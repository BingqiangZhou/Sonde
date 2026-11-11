/** feed 是唯一注入面:仅放行 http(s) 链接,javascript:/data: 等协议一律拒绝。 */

export function safeHttpUrl(value: string | null | undefined): string | null {
  if (!value) {
    return null;
  }
  const trimmed = value.trim();
  return /^https?:\/\//i.test(trimmed) ? trimmed : null;
}
