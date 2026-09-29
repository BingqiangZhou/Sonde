/** 源服务：到期扫描 + 单源抓取入库 + 派发转写。 */

import { row, rows, sql } from '../db/db.ts';
import { sendJob } from '../queue/boss.ts';
import { FeedNotModifiedError, fetchPodcastFeed } from './rss.ts';
import type { RssEpisodeInput } from './rss.ts';

interface SourceRow {
  id: number;
  name: string;
  config: { feedUrl?: string };
  cursor: { lastFetchedAt?: string; etag?: string; lastModified?: string };
  health: { lastStatus?: string; lastError?: string | null; consecutiveFailures?: number };
  interval_minutes: number;
}

/** 扫描全部到期源，逐个抓取（cron 每分钟触发）。返回处理的源数。 */
export async function scanDueSources(): Promise<number> {
  const due = await rows<{ id: number }>(sql`
    SELECT id FROM sources
    WHERE is_active
      AND (
        cursor->>'lastFetchedAt' IS NULL
        OR (cursor->>'lastFetchedAt')::timestamptz < now() - (interval_minutes || ' minutes')::interval
      )
    ORDER BY (cursor->>'lastFetchedAt')::timestamptz NULLS FIRST
    LIMIT 100
  `);
  let processed = 0;
  for (const { id } of due) {
    try {
      await fetchSource(id);
      processed++;
    } catch (error) {
      console.warn(`[sources] fetch failed source=${id}:`, error instanceof Error ? error.message : error);
    }
  }
  return processed;
}

/** 抓取一个源：解析 feed → 新单集入库 → 派发转写 → 更新 cursor/health。 */
export async function fetchSource(sourceId: number): Promise<{ fetched: number; inserted: number }> {
  const source = await row<SourceRow>(sql`
    SELECT id, name, config, cursor, health, interval_minutes
    FROM sources WHERE id = ${sourceId}
  `);
  if (!source || !source.config?.feedUrl) {
    throw new Error(`source ${sourceId} not found or missing feedUrl`);
  }
  const src: SourceRow = source;
  const firstImport = src.cursor?.lastFetchedAt == null;
  try {
    const feed = await fetchPodcastFeed(src.config.feedUrl as string, {
      etag: src.cursor?.etag ?? null,
      lastModified: src.cursor?.lastModified ?? null,
      firstImport,
    });

    let inserted = 0;
    for (const ep of feed.episodes) {
      const created = await insertEpisodeIfNew(sourceId, ep);
      if (created) {
        inserted++;
      }
    }

    await updateCursor(sourceId, {
      etag: feed.etag,
      lastModified: feed.lastModified,
    });
    await updateHealth(sourceId, true, null);

    return { fetched: feed.episodes.length, inserted };
  } catch (error) {
    if (error instanceof FeedNotModifiedError) {
      await updateCursor(sourceId, {});
      await updateHealth(sourceId, true, null);
      return { fetched: 0, inserted: 0 };
    }
    const message = error instanceof Error ? error.message : String(error);
    await updateHealth(sourceId, false, message);
    throw error;
  }

  async function insertEpisodeIfNew(sid: number, ep: RssEpisodeInput): Promise<boolean> {
    const result = await row<{ id: number; inserted: boolean }>(sql`
      INSERT INTO episodes
        (source_id, guid, title, url, author, published_at, shownotes,
         duration_seconds, enclosure_url, enclosure_bytes)
      VALUES
        (${sid}, ${ep.guid}, ${ep.title}, ${ep.url}, ${ep.author}, ${ep.publishedAt},
         ${ep.shownotes}, ${ep.durationSeconds}, ${ep.enclosureUrl}, ${ep.enclosureBytes})
      ON CONFLICT (source_id, guid) DO NOTHING
      RETURNING id, (xmax = 0) AS inserted
    `);
    if (!result?.inserted) {
      return false;
    }
    await sendJob('episodes.transcribe', { episodeId: result.id }, { singletonKey: `ep:${result.id}` });
    return true;
  }

  async function updateCursor(
    sid: number,
    values: { etag?: string | null; lastModified?: string | null },
  ): Promise<void> {
    await rows(sql`
      UPDATE sources
      SET cursor = jsonb_set(
            jsonb_set(cursor, '{lastFetchedAt}', to_jsonb(now()::timestamptz::text)),
            '{etag}', ${JSON.stringify(values.etag ?? null)}::jsonb
          ),
          updated_at = now()
      WHERE id = ${sid}
    `);
    if (values.lastModified !== undefined) {
      await rows(sql`
        UPDATE sources
        SET cursor = jsonb_set(cursor, '{lastModified}', ${JSON.stringify(values.lastModified)}::jsonb)
        WHERE id = ${sid}
      `);
    }
  }

  async function updateHealth(sid: number, ok: boolean, error: string | null): Promise<void> {
    const failures = ok ? 0 : (src.health?.consecutiveFailures ?? 0) + 1;
    await rows(sql`
      UPDATE sources
      SET health = jsonb_build_object(
            'lastStatus', ${ok ? 'ok' : 'error'}::text,
            'lastError', ${error}::text,
            'consecutiveFailures', ${failures}::int,
            'lastRunAt', now()::timestamptz::text
          ),
          updated_at = now()
      WHERE id = ${sid}
    `);
  }
}

