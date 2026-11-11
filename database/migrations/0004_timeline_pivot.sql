-- 声读 Sonde 转向纯"播客更新时间线"：删除 AI 时代数据模型（破坏性，已确认）
-- 保留 sources / episodes 的 RSS 侧数据，历史单集继续在时间线可见。

-- 1. AI 时代三张表（索引随表删除）
DROP TABLE IF EXISTS analyses;
DROP TABLE IF EXISTS daily_reports;
DROP TABLE IF EXISTS receipts;

-- 2. episodes：转写相关列（列上的 CHECK 与 idx_episodes_pending 随列自动删除，显式 DROP 仅为清晰）
DROP INDEX IF EXISTS idx_episodes_pending;
ALTER TABLE episodes
  DROP COLUMN IF EXISTS body_text,
  DROP COLUMN IF EXISTS body_status,
  DROP COLUMN IF EXISTS transcribe_status,
  DROP COLUMN IF EXISTS transcribe_error,
  DROP COLUMN IF EXISTS transcribed_at;

-- 3. sources：tier（AI 精选门槛分级）废弃；新增频道封面
--    （sources_tier_check 随 tier 列自动删除）
ALTER TABLE sources DROP COLUMN IF EXISTS tier;
ALTER TABLE sources ADD COLUMN image_url TEXT;

-- 保留：sources(kind/config/interval_minutes/is_active/cursor/health)、
--       episodes(guid/title/url/author/published_at/shownotes/duration_seconds/
--                enclosure_*/raw)、uq_sources_feed_url、idx_episodes_published。
