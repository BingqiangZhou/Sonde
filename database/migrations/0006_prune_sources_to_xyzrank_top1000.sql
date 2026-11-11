-- 手工订阅(industry/sources.json + seed)已整体废弃:订阅全部由 xyzrank 每日同步管理。
-- 破坏性迁移(已确认):删除当前所有非 top-1000 的源——
--   origin 不是 'xyzrank' 的行(手工订阅残留),以及 is_active=false 的行(掉榜停用者)。
-- episodes 经 ON DELETE CASCADE 级联删除,不可逆(需保留数据请先 pg_dump)。
-- 今后掉榜仍只停用不删除;被删 feed 若在当期 top-1000 内,下次同步会重新收录并重归并分类。
DELETE FROM sources
 WHERE coalesce(config->>'origin', '') <> 'xyzrank'
    OR NOT is_active;
