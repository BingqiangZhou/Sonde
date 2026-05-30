import type { XyzrankPodcast } from "@/types";

const BASE_URL = "https://xyzrank.com/api/podcasts";

/** Map raw xyzrank item to XyzrankPodcast */
function mapItem(raw: Record<string, unknown>): XyzrankPodcast {
  const links = Array.isArray(raw.links) ? raw.links : [];
  const rssLink = links.find(
    (l: Record<string, unknown>) => l.name === "rss"
  ) as Record<string, unknown> | undefined;

  return {
    id: raw.id as string,
    name: raw.name as string,
    rank: raw.rank as number,
    logo_url: raw.logoURL as string,
    category: raw.primaryGenreName as string,
    author: raw.authorsText as string,
    rss_feed_url: rssLink?.url as string ?? "",
    track_count: raw.trackCount as number ?? 0,
    avg_duration: raw.avgDuration as number ?? 0,
    avg_play_count: raw.avgPlayCount as number ?? 0,
  };
}

export async function fetchRankings(
  offset = 0,
  limit = 50
): Promise<{ podcasts: XyzrankPodcast[]; total: number }> {
  const res = await fetch(`${BASE_URL}?offset=${offset}&limit=${limit}`);
  if (!res.ok) throw new Error(`xyzrank API error: ${res.status}`);
  const json = await res.json();
  const rawItems: Record<string, unknown>[] = json?.items ?? json?.data?.items ?? [];
  const total: number = json?.total ?? json?.data?.total ?? rawItems.length;
  const podcasts = rawItems.map(mapItem);
  return { podcasts, total };
}

export async function fetchAllRankings(): Promise<XyzrankPodcast[]> {
  const all: XyzrankPodcast[] = [];
  const batchSize = 50;
  let offset = 0;

  const first = await fetchRankings(offset, batchSize);
  all.push(...first.podcasts);
  const total = first.total;

  while (all.length < total) {
    offset += batchSize;
    const batch = await fetchRankings(offset, batchSize);
    all.push(...batch.podcasts);
  }

  return all;
}
