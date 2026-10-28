# Phase B · 多用户认证恢复

> 状态：⬜ 未开始　|　前置：Phase A　|　下一步：Phase C

## 目标

恢复多用户：邮箱注册（默认关闭）+ JWT 登录/刷新，`/api/v1/podcasts/*` 全部按真实用户鉴权；新增收藏同步；管理面板可建号/重置密码。Flutter 登录流程联调通过。

## 实施路径：git 考古恢复

被删代码在 v0 分支历史中（2026-04 "后端简化"系列提交删除了 `app/domains/user/`）。恢复方法：

```
git log --diff-filter=D --oneline -- backend/app/domains/user   # 定位删除提交
git show <删除前的父提交>:backend/app/domains/user/...           # 逐文件取回
```

**验收契约以 `backend/docs/AUTHENTICATION.md` 为准**：register / login（email_or_username+password）/ refresh / me / logout / logout-all；bcrypt；access 30min / refresh 7d；user_sessions 设备管理。历史代码取回后必须逐文件比对适配（简化后的 core/config、数据库、依赖注入已变化，不能盲拷）。

## 任务清单

### B1 users 域恢复与适配

- [ ] 定位并取出历史 `app/domains/user/`（models/routes/services/security）
- [ ] `users` ORM 模型补回并对齐现库列（024 已删 2FA 列；含 settings/preferences/api_key）
- [ ] alembic 迁移 025：重建 `user_sessions`（含 device_info/ip/ua/expires_at/is_active）
- [ ] 依赖注入适配：新 `core/auth.py` 增加 `require_user`（JWT Bearer → user_id）；保留 `require_api_key`（映射 is_superuser 运维用户）
- [ ] JWT 工具恢复（HS256 + SECRET_KEY；access 30min / refresh 7d）
- [ ] 注册开关：`REGISTRATION_OPEN`（默认 false）→ 关闭时 register 403；超管不受限
- [ ] forgot/reset-password：首版返回 501（文案：请联系管理员重置）
- [ ] auth 路由挂 slowapi 限流；登录失败恒时比较
- [ ] 启动引导脚本/CLI：`uv run python -m app.scripts.create_user email password [--superuser]`（面板之外的最小建号路径）

### B2 业务路由切换鉴权

- [ ] `domains/podcast/routes/dependencies.py` 的 `require_api_key` 依赖替换为 `require_user`（user_id 注入真实值，删 SINGLE_USER_ID 硬编码）
- [ ] 全量 grep `user_id=1` / `SINGLE_USER_ID` 残留并清理
- [ ] 回归：episodes/queue/playback/stats/subscriptions 等端点在无 token 时 401

### B3 收藏同步

- [ ] alembic 迁移（并入 025）：`user_favorites` 表（UNIQUE(user_id, episode_id)）
- [ ] `GET /api/v1/favorites`、`PUT/DELETE /api/v1/favorites/{episode_id}`（挂 require_user）

### B4 管理面板用户管理

- [ ] Jinja2 面板新增用户页：建号（邮箱+初始密码+超管勾选）、重置密码、停用/启用
- [ ] 面板鉴权沿用 API Key（运维通道）

### B5 测试与联调

- [ ] pytest：注册开关、登录/刷新/登出、token 过期、限流、require_user 401、favorites CRUD（用 httpx AsyncClient + 测试库）
- [ ] Flutter 联调：server_config 填本机后端 → 注册（临时开 REGISTRATION_OPEN）→ 登录 → me → 刷新 → 登出；401 自动刷新链路
- [ ] 更新 `tool/backend_contract_smoke.ps1` 覆盖 auth

## 验收标准

1. pytest 全绿（含新增 auth/favorites 用例）。
2. Flutter 真机/模拟器完成注册→登录→自动刷新→登出闭环。
3. `REGISTRATION_OPEN=false` 时注册被拒；CLI 建号可登录。
4. 原 /podcasts/* 功能（订阅列表、feed、播放状态）以真实用户身份工作，跨用户数据隔离（A 用户看不到 B 的播放状态/收藏）。

## 注意事项

- 历史代码与现库漂移点：024 迁移后的 users 列、简化后的 config/依赖注入体系——逐文件比对，不整目录盲拷。
- `API_KEY` 运维通道必须保留（Jinja2 面板、CI 冒烟、脚本都靠它）。
- user_sessions 过期清理：挂到现有 Celery 清理任务或登录时惰性清理，避免表膨胀。
