/** 源服务：到期扫描派发 + 单源抓取入库。 */

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

/** 扫描全部到期源并逐源派发 `sources.fetch`（cron 每分钟触发）。
 *  纯派发器：不在此进程内抓取，避免一个长任务顺序抓上百个 feed 超过队列 expire。
 *  返回真正入队的源数（singletonKey 去重掉的计为未入队）。 */
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
  let sent = 0;
  for (const { id } of due) {
    if (await dispatchSourceFetch(id)) {
      sent++;
    }
  }
  return sent;
}

/** 派发单源抓取任务（stately 策略下 singletonKey `src:<id>` 防同源堆叠）。
 *  返回 false 表示同源任务尚在途、本次被去重。 */
export async function dispatchSourceFetch(sourceId: number): Promise<boolean> {
  const jobId = await sendJob('sources.fetch', { sourceId }, { singletonKey: `src:${sourceId}` });
  return jobId !== null;
}

/** 抓取一个源：解析 feed → 新单集入库 → 更新 cursor/health/封面。 */
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

    // 条件头随成功响应整体覆盖（服务端不再返回时存 null，与旧行为一致）
    await persistRun(sourceId, {
      ok: true,
      error: null,
      cursor: { etag: feed.etag, lastModified: feed.lastModified },
      imageUrl: feed.feedImageUrl,
    });

    return { fetched: feed.episodes.length, inserted };
  } catch (error) {
    if (error instanceof FeedNotModifiedError) {
      // 304：只推进 lastFetchedAt，etag/lastModified 必须原样保留（否则条件 GET 退化）
      await persistRun(sourceId, { ok: true, error: null, cursor: {} });
      return { fetched: 0, inserted: 0 };
    }
    const message = error instanceof Error ? error.message : String(error);
    // 失败：只写 health、不动 cursor —— lastFetchedAt 不前进，源保持"到期"由 cron 重派
    await persistRun(sourceId, { ok: false, error: message, cursor: null });
    throw error;
  }

  /** DO NOTHING 下冲突行不返回：有 RETURNING 行即新插入。 */
  async function insertEpisodeIfNew(sid: number, ep: RssEpisodeInput): Promise<boolean> {
    const result = await row<{ id: number }>(sql`
      INSERT INTO episodes
        (source_id, guid, title, url, author, published_at, shownotes,
         duration_seconds, enclosure_url, enclosure_bytes)
      VALUES
        (${sid}, ${ep.guid}, ${ep.title}, ${ep.url}, ${ep.author}, ${ep.publishedAt},
         ${ep.shownotes}, ${ep.durationSeconds}, ${ep.enclosureUrl}, ${ep.enclosureBytes})
      ON CONFLICT (source_id, guid) DO NOTHING
      RETURNING id
    `);
    return result !== null;
  }

  /** cursor + health 落库合并为单条 UPDATE（原子，P1-7）。
   *  cursor 语义：
   *  - null：失败，cursor 整体不动（lastFetchedAt 不前进）
   *  - {}：304，只并入 lastFetchedAt，etag/lastModified 保留
   *  - {etag, lastModified}：成功，整体覆盖条件头
   *  imageUrl：成功（非 304）时传 feed 封面（feed 无图为 null）——COALESCE 下
   *  有图则覆盖、无图或 304/失败（null）一律保留旧值，单条语句覆盖全部分支。 */
  async function persistRun(
    sid: number,
    run: {
      ok: boolean;
      error: string | null;
      cursor: Record<string, string | null> | null;
      imageUrl?: string | null;
    },
  ): Promise<void> {
    const failures = run.ok ? 0 : (src.health?.consecutiveFailures ?? 0) + 1;
    const patch = run.cursor === null ? null : JSON.stringify(run.cursor);
    await rows(sql`
      UPDATE sources
      SET cursor = CASE
            WHEN ${patch}::jsonb IS NULL THEN cursor
            ELSE cursor
                 || jsonb_build_object('lastFetchedAt', now()::timestamptz::text)
                 || ${patch}::jsonb
          END,
          health = jsonb_build_object(
            'lastStatus', ${run.ok ? 'ok' : 'error'}::text,
            'lastError', ${run.error}::text,
            'consecutiveFailures', ${failures}::int,
            'lastRunAt', now()::timestamptz::text
          ),
          updated_at = now(),
          image_url = COALESCE(${run.imageUrl ?? null}::text, image_url)
      WHERE id = ${sid}
    `);
  }
}
