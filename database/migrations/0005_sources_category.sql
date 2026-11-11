-- 时间线筛选升级为分类 chips:sources 记录一级分类(xyzrank primaryGenreName 经 GENRE_ROLLUP 归并,
-- 或手工 sources.json 条目的 category)。
-- 可空:无分类的源在前端归入「其他」chip;存量行由 worker 启动时的 xyzrank 同步回填(见 schedules.ts 启动触发)。
ALTER TABLE sources ADD COLUMN category TEXT;
