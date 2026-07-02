import { describe, it, expect, vi, afterEach } from "vitest";
import { fetchText, fetchJson } from "../http";

afterEach(() => vi.restoreAllMocks());

describe("http", () => {
  it("fetchText 成功返回文本", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => "<rss>hi</rss>",
    })));
    const text = await fetchText("http://example.com/feed");
    expect(text).toBe("<rss>hi</rss>");
  });

  it("fetchText 非 2xx 抛错含状态码", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: false, status: 503, text: async () => "" })));
    await expect(fetchText("http://example.com")).rejects.toThrow(/503/);
  });

  it("fetchJson 解析 JSON", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({
      ok: true, status: 200, json: async () => ({ a: 1 }),
    })));
    const data = await fetchJson<{ a: number }>("http://example.com");
    expect(data).toEqual({ a: 1 });
  });
});
