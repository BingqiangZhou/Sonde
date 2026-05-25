import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const { url } = await req.json();
    if (!url) {
      return NextResponse.json(
        { success: false, error: { message: "缺少 RSS feed URL" } },
        { status: 400 }
      );
    }

    const res = await fetch(url, {
      headers: { Accept: "application/xml, text/xml, application/rss+xml" },
    });
    if (!res.ok) throw new Error(`Failed to fetch RSS: ${res.status}`);

    const text = await res.text();

    const titleMatch = text.match(/<title>(?:<![CDATA[)?(.*?)(?:]]>)?<\/title>/s);
    const descMatch = text.match(/<description>(?:<![CDATA[)?(.*?)(?:]]>)?<\/description>/s);

    const episodeRegex = /<item>([\s\S]*?)<\/item>/g;
    const episodes: {
      title: string;
      link: string;
      description: string;
      audio_url: string;
      duration: number;
      published_at: string;
    }[] = [];

    let match;
    while ((match = episodeRegex.exec(text)) !== null) {
      const item = match[1];
      const enclosureMatch = item.match(/<enclosure[^>]*url="([^"]*)"[^>]*type="([^"]*)"/);
      if (!enclosureMatch || !enclosureMatch[2].startsWith("audio/")) continue;

      const itemTitle = item.match(/<title>(?:<![CDATA[)?(.*?)(?:]]>)?<\/title>/s);
      const itemLink = item.match(/<link>(?:<![CDATA[)?(.*?)(?:]]>)?<\/link>/s);
      const itemDesc = item.match(/<description>(?:<![CDATA[)?(.*?)(?:]]>)?<\/description>/s);
      const itemPubDate = item.match(/<pubDate>(.*?)<\/pubDate>/);
      const itemDuration =
        item.match(/<itunes:duration>(.*?)<\/itunes:duration>/) ??
        item.match(/<duration>(.*?)<\/duration>/);

      let duration = 0;
      if (itemDuration) {
        const d = parseInt(itemDuration[1], 10);
        if (!isNaN(d)) duration = d;
      }

      episodes.push({
        title: itemTitle?.[1]?.trim() ?? "",
        link: itemLink?.[1]?.trim() ?? "",
        description: itemDesc?.[1]?.trim() ?? "",
        audio_url: enclosureMatch[1],
        duration,
        published_at: itemPubDate?.[1]?.trim() ?? "",
      });
    }

    return NextResponse.json({
      success: true,
      data: {
        title: titleMatch?.[1]?.trim() ?? "",
        description: descMatch?.[1]?.trim() ?? "",
        episodes,
      },
    });
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: { message: e.message } },
      { status: 500 }
    );
  }
}
