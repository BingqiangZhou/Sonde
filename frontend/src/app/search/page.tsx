import { loadSearchIndex } from '@/lib/loaders';
import { SearchClient } from './search-client';

export default async function SearchPage() {
  let entries: { episode_id: string; podcast_id: string; podcast_name: string; title: string; summary: string; published_at: string }[] = [];
  try {
    const idx = await loadSearchIndex();
    entries = idx.entries;
  } catch {
    entries = [];
  }
  return <SearchClient entries={entries} />;
}
