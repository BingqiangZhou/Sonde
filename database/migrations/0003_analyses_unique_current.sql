-- analyses.is_current 收紧为数据库约束：每集最多一条当前判定。
-- 0001 中"应用层维护"的假设在并发下不成立（事件驱动分析 + 30 分钟 sweep 可并发分析同一单集）。

-- 1) 清理历史脏数据：同一单集多条 is_current 时只保留最新一条
WITH ranked AS (
  SELECT id,
         row_number() OVER (PARTITION BY episode_id ORDER BY created_at DESC, id DESC) AS rn
  FROM analyses
  WHERE is_current
)
UPDATE analyses SET is_current = false
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- 2) 部分唯一索引：此后不变式由数据库保证
CREATE UNIQUE INDEX uq_analyses_episode_current ON analyses (episode_id) WHERE is_current;
