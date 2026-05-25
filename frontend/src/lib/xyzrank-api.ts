import type { XyzrankPodcast } from "@/types";

const BASE_URL = "https://xyzrank.com/api/podcasts";

export async function fetchRankings(
  offset = 0,
  limit = 50
): Promise<{ podcasts: XyzrankPodcast[]; total: number }> {
  const res = await fetch(`${BASE_URL}?offset=${offset}&limit=${limit}`);
  if (!res.ok) throw new Error(`xyzrank API error: ${res.status}`);
  return res.json();
}

export async function fetchAllRankings(): Promise<XyzrankPodcast[]> {
  const all: XyzrankPodcast[] = [];
  const batchSize = 50;
  let offset = 0;

  const first = await fetchRankings(offset, batchSize);
  all.push(...(first.podcasts ?? []));
  const total = first.total ?? 0;

  while (all.length < total) {
    offset += batchSize;
    const batch = await fetchRankings(offset, batchSize);
    all.push(...(batch.podcasts ?? []));
  }

  return all;
}
