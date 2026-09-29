-- 声读 Sonde 初始 schema
-- 源、单集（含转录）、分析判定、日报、成本台账

CREATE TABLE sources (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name             TEXT NOT NULL,
  kind             TEXT NOT NULL DEFAULT 'podcast_rss',
  config           JSONB NOT NULL DEFAULT '{}',   -- { feedUrl, ... }
  tier             TEXT NOT NULL DEFAULT 'T2',    -- T1 | T2（精选门槛分级）
  interval_minutes INT NOT NULL DEFAULT 60,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  cursor           JSONB NOT NULL DEFAULT '{}',   -- { lastFetchedAt, etag, latestGuid }
  health           JSONB NOT NULL DEFAULT '{}',   -- { lastStatus, lastError, consecutiveFailures }
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT sources_kind_check CHECK (kind IN ('podcast_rss')),
  CONSTRAINT sources_tier_check CHECK (tier IN ('T1', 'T2'))
);

-- 同一 feedUrl 不允许重复订阅（不区分大小写）
CREATE UNIQUE INDEX uq_sources_feed_url ON sources (lower(config->>'feedUrl'))
  WHERE config->>'feedUrl' IS NOT NULL;

CREATE TABLE episodes (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_id         BIGINT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  guid              TEXT NOT NULL,                -- RSS item guid（或 enclosure URL 兜底）
  title             TEXT NOT NULL,
  url               TEXT,
  author            TEXT,
  published_at      TIMESTAMPTZ,
  shownotes         TEXT,
  duration_seconds  INT,
  enclosure_url     TEXT,
  enclosure_bytes   BIGINT,
  body_text         TEXT,                          -- 转录全文
  body_status       TEXT NOT NULL DEFAULT 'none', -- none | ok | failed
  transcribe_status TEXT NOT NULL DEFAULT 'pending',
    -- pending | downloading | converting | transcribing | analyzing | done | failed | skipped
  transcribe_error  TEXT,
  transcribed_at    TIMESTAMPTZ,
  raw               JSONB NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT episodes_unique_guid UNIQUE (source_id, guid),
  CONSTRAINT episodes_body_status_check CHECK (body_status IN ('none', 'ok', 'failed'))
);

CREATE INDEX idx_episodes_published ON episodes (published_at DESC);
CREATE INDEX idx_episodes_source ON episodes (source_id, published_at DESC);
-- 待处理扫描：只看未完成的
CREATE INDEX idx_episodes_pending ON episodes (transcribe_status, created_at)
  WHERE transcribe_status NOT IN ('done', 'skipped');

CREATE TABLE analyses (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  episode_id     BIGINT NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  score          INT NOT NULL,                    -- 0-100 注意力价值分
  selected       BOOLEAN NOT NULL,
  reason         TEXT,                            -- 评分理由（入选/落选均写）
  tags           JSONB NOT NULL DEFAULT '[]',
  category       TEXT,                            -- taxonomy category key
  title_zh       TEXT,                            -- 以下三项仅入选时生成
  summary_zh     TEXT,
  reason_zh      TEXT,
  model          TEXT NOT NULL,
  prompt_version TEXT,
  is_current     BOOLEAN NOT NULL DEFAULT TRUE,   -- 每集最新一条为 TRUE（应用层维护）
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT analyses_score_check CHECK (score >= 0 AND score <= 100)
);

CREATE INDEX idx_analyses_episode ON analyses (episode_id, created_at DESC);
CREATE INDEX idx_analyses_current ON analyses (is_current, selected, created_at DESC);

CREATE TABLE daily_reports (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind         TEXT NOT NULL DEFAULT 'daily',
  report_key   TEXT NOT NULL,                     -- 'YYYY-MM-DD'（REPORT_TIMEZONE 日历）
  window_start TIMESTAMPTZ NOT NULL,
  window_end   TIMESTAMPTZ NOT NULL,
  content      JSONB NOT NULL,                    -- { title, leadParagraph, highlights, sections[] }
  model        TEXT,
  revision     INT NOT NULL DEFAULT 1,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT daily_reports_unique UNIQUE (kind, report_key)
);

CREATE TABLE receipts (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  service       TEXT NOT NULL,                    -- 'llm' | 'transcription'
  operation     TEXT NOT NULL,                    -- 'score' | 'write' | 'report' | 'transcribe'
  model         TEXT,
  input_tokens  INT,
  output_tokens INT,
  audio_seconds INT,
  ok            BOOLEAN NOT NULL,
  error         TEXT,
  duration_ms   INT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_receipts_created ON receipts (created_at DESC);
CREATE INDEX idx_receipts_service_time ON receipts (service, created_at DESC);
