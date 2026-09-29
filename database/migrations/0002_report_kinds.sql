-- 周报与月报：daily_reports.kind 收紧为 daily | weekly | monthly
-- 周报 report_key = 覆盖周的周一 'YYYY-MM-DD'，月报 report_key = 'YYYY-MM'

ALTER TABLE daily_reports
  ADD CONSTRAINT daily_reports_kind_check CHECK (kind IN ('daily', 'weekly', 'monthly'));
