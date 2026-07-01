import type {
  RankingsSnapshot,
  PodcastMeta,
  EpisodeMeta,
  ScrapeStatus,
  SummaryStatus,
} from "./types.js";

const SCRAPE_STATUSES: ScrapeStatus[] = ["pending", "done", "failed"];
const SUMMARY_STATUSES: SummaryStatus[] = ["pending", "done", "skipped"];

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function requireFields(obj: Record<string, unknown>, fields: string[], ctx: string): void {
  for (const f of fields) {
    if (!(f in obj) || obj[f] === undefined || obj[f] === null) {
      throw new ValidationError(`${ctx}: 缺少必填字段 "${f}"`);
    }
  }
}

export function validateRankingsSnapshot(data: unknown): asserts data is RankingsSnapshot {
  if (!isObject(data)) throw new ValidationError("rankings: 期望对象");
  requireFields(data, ["fetched_at", "source", "podcasts"], "rankings");
  if (typeof data.fetched_at !== "string") throw new ValidationError('rankings: "fetched_at" 须为字符串');
  if (typeof data.source !== "string") throw new ValidationError('rankings: "source" 须为字符串');
  if (!Array.isArray(data.podcasts)) throw new ValidationError('rankings: "podcasts" 须为数组');
  for (const p of data.podcasts) {
    if (!isObject(p)) throw new ValidationError("rankings.podcasts[]: 期望对象");
    requireFields(p, ["id", "name", "rank", "category", "logo_url", "rss_feed_url", "author"], "rankings.podcasts[]");
  }
}

export function validatePodcastMeta(data: unknown): asserts data is PodcastMeta {
  if (!isObject(data)) throw new ValidationError("meta: 期望对象");
  requireFields(
    data,
    ["id", "name", "author", "category", "logo_url", "rss_feed_url", "xyzrank_rank", "subscribed"],
    "meta"
  );
  if (typeof data.xyzrank_rank !== "number") throw new ValidationError('meta: "xyzrank_rank" 须为数字');
  if (typeof data.subscribed !== "boolean") throw new ValidationError('meta: "subscribed" 须为布尔');
}

export function validateEpisodeMeta(data: unknown): asserts data is EpisodeMeta {
  if (!isObject(data)) throw new ValidationError("episode: 期望对象");
  requireFields(
    data,
    ["id", "podcast_id", "title", "audio_url", "duration", "published_at", "link", "scraped_content_path", "scrape_status", "summary_status", "tags"],
    "episode"
  );
  if (typeof data.duration !== "number") throw new ValidationError('episode: "duration" 须为数字');
  if (!SCRAPE_STATUSES.includes(data.scrape_status as ScrapeStatus)) {
    throw new ValidationError(`episode: "scrape_status" 非法，允许 ${SCRAPE_STATUSES.join("/")}`);
  }
  if (!SUMMARY_STATUSES.includes(data.summary_status as SummaryStatus)) {
    throw new ValidationError(`episode: "summary_status" 非法，允许 ${SUMMARY_STATUSES.join("/")}`);
  }
  if (!Array.isArray(data.tags)) throw new ValidationError('episode: "tags" 须为数组');
}
