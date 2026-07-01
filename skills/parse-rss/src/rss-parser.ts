import { XMLParser } from "fast-xml-parser";
import { fetchText } from "@podcastinsight/shared";

export interface ParsedEpisode {
  title: string;
  link: string;
  guid?: string;
  description: string;
  audio_url: string;
  duration: number;
  published_at: string;
}

export interface ParsedFeed {
  title: string;
  description: string;
  episodes: ParsedEpisode[];
}

function toArray(v: unknown): unknown[] {
  if (v === undefined || v === null) return [];
  return Array.isArray(v) ? v : [v];
}

function toText(v: unknown): string {
  if (typeof v === "string") return v.trim();
  if (typeof v === "number") return String(v);
  if (v && typeof v === "object" && "#text" in (v as Record<string, unknown>)) {
    return String((v as Record<string, unknown>)["#text"]).trim();
  }
  return "";
}

function normalizeDate(raw: string): string {
  const d = new Date(raw);
  return isNaN(d.getTime()) ? raw : d.toISOString();
}

export async function parseRssFeed(feedUrl: string): Promise<ParsedFeed> {
  const xml = await fetchText(feedUrl, { accept: "application/xml, text/xml, application/rss+xml" });
  const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: "@_" });
  const doc = parser.parse(xml) as Record<string, unknown>;
  const rss = (doc.rss ?? {}) as Record<string, unknown>;
  const channel = (rss.channel ?? doc.channel ?? {}) as Record<string, unknown>;

  const title = toText(channel.title);
  const description = toText(channel.description);
  const rawItems = toArray(channel.item) as Record<string, unknown>[];

  const episodes: ParsedEpisode[] = [];
  for (const item of rawItems) {
    const enclosures = toArray(item.enclosure) as Record<string, unknown>[];
    const audioEnc = enclosures.find(
      (e) => typeof e["@_type"] === "string" && e["@_type"].startsWith("audio/")
    );
    const audio_url = String(audioEnc?.["@_url"] ?? "");
    if (!audio_url) continue;

    const durationRaw = toText(item["itunes:duration"] ?? item.duration);
    let duration = 0;
    const parsed = parseInt(durationRaw, 10);
    if (!isNaN(parsed)) duration = parsed;

    episodes.push({
      title: toText(item.title) || "(无标题)",
      link: toText(item.link),
      guid: toText(item.guid) || undefined,
      description: toText(item.description),
      audio_url,
      duration,
      published_at: normalizeDate(toText(item.pubDate)),
    });
  }

  return { title, description, episodes };
}
