import { NextRequest, NextResponse } from "next/server";
import { XMLParser } from "fast-xml-parser";

/** Block SSRF: reject private / internal / non-HTTPS URLs */
function validateFeedUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error("无效的 URL 格式");
  }

  if (url.protocol !== "https:" && !(url.protocol === "http:" && url.hostname === "localhost")) {
    throw new Error("仅支持 https:// 协议的 RSS feed 地址");
  }

  const hostname = url.hostname.toLowerCase();

  if (
    hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "0.0.0.0" ||
    hostname === "::1" ||
    hostname.endsWith(".local") ||
    hostname.endsWith(".internal") ||
    hostname.endsWith(".localhost")
  ) {
    throw new Error("不允许访问内网地址");
  }

  if (/^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)/.test(hostname)) {
    throw new Error("不允许访问内网地址");
  }

  return url;
}

/** Parse HH:MM:SS or MM:SS or plain seconds into total seconds */
function parseDuration(raw: string | undefined): number {
  if (!raw) return 0;
  const trimmed = raw.trim();
  // Already a number (seconds)
  if (/^\d+$/.test(trimmed)) return parseInt(trimmed, 10);
  // HH:MM:SS or MM:SS
  const parts = trimmed.split(":").map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return 0;
}

export async function POST(req: NextRequest) {
  try {
    const { url: rawUrl } = await req.json();
    if (!rawUrl) {
      return NextResponse.json(
        { success: false, error: { message: "缺少 RSS feed URL" } },
        { status: 400 }
      );
    }

    const validatedUrl = validateFeedUrl(rawUrl);

    const res = await fetch(validatedUrl, {
      headers: { Accept: "application/xml, text/xml, application/rss+xml" },
    });
    if (!res.ok) throw new Error(`Failed to fetch RSS: ${res.status}`);

    const text = await res.text();

    const parser = new XMLParser({
      ignoreAttributes: false,
      attributeNamePrefix: "@_",
      isArray: (name) => name === "item",
    });
    const xml = parser.parse(text);

    const channel = xml?.rss?.channel ?? xml?.channel;
    if (!channel) throw new Error("无法解析 RSS feed");

    const feedTitle = typeof channel.title === "string" ? channel.title : "";
    const feedDescription = typeof channel.description === "string" ? channel.description : "";

    const rawItems: Record<string, unknown>[] = Array.isArray(channel.item) ? channel.item : [];

    const episodes = rawItems.map((item) => {
      const enclosure = item.enclosure as Record<string, unknown> | undefined;
      const audioUrl = enclosure?.["@_url"] as string ?? "";
      const audioType = enclosure?.["@_type"] as string ?? "";

      // Skip non-audio items
      if (!audioUrl || (audioType && !audioType.startsWith("audio/"))) return null;

      return {
        title: (item.title as string ?? "").trim(),
        link: (item.link as string ?? "").trim(),
        description: (item.description as string ?? "").trim(),
        audio_url: audioUrl,
        duration: parseDuration(item["itunes:duration"] as string | undefined),
        published_at: item.pubDate as string ?? "",
      };
    }).filter((ep): ep is NonNullable<typeof ep> => ep !== null);

    return NextResponse.json({
      success: true,
      data: {
        title: feedTitle,
        description: feedDescription,
        episodes,
      },
    });
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return NextResponse.json(
      { success: false, error: { message } },
      { status: 500 }
    );
  }
}
