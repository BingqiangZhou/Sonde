import { fetchJson } from "@podcastinsight/shared";
import type { RankingPodcast } from "@podcastinsight/shared";

const BASE_URL = "https://xyzrank.com/api/podcasts";

interface RawItem {
  id: string;
  name: string;
  rank: number;
  logoURL?: string;
  primaryGenreName?: string;
  authorsText?: string;
  links?: { name: string; url: string }[];
}

function mapItem(raw: RawItem): RankingPodcast {
  const rssLink = raw.links?.find((l) => l.name === "rss");
  return {
    id: raw.id,
    name: raw.name,
    rank: raw.rank,
    logo_url: raw.logoURL ?? "",
    category: raw.primaryGenreName ?? "",
    author: raw.authorsText ?? "",
    rss_feed_url: rssLink?.url ?? "",
  };
}

export async function fetchRankingsPage(
  offset = 0,
  limit = 50
): Promise<{ podcasts: RankingPodcast[]; total: number }> {
  const json = await fetchJson<{ items?: RawItem[]; total?: number }>(
    `${BASE_URL}?offset=${offset}&limit=${limit}`
  );
  const items = json.items ?? [];
  const total = json.total ?? items.length;
  return { podcasts: items.map(mapItem), total };
}

export async function fetchAllRankings(batchSize = 50): Promise<RankingPodcast[]> {
  const all: RankingPodcast[] = [];
  const first = await fetchRankingsPage(0, batchSize);
  all.push(...first.podcasts);
  let offset = batchSize;
  while (all.length < first.total) {
    const batch = await fetchRankingsPage(offset, batchSize);
    all.push(...batch.podcasts);
    offset += batchSize;
  }
  return all;
}
