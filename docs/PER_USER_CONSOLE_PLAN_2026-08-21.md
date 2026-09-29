# 面板账号化改造方案：从"管理员面板"到"人人平权的个人中心"

- 日期：2026-08-21
- 状态：**已搁置（2026-08-21 产品定夺：不做平台、个人自用）**
- 背景：参照 Dify 的 console 即用户账号体系，结合"没有管理员、只有个人页面、可注册多用户"的产品定夺，重新设计 Sonde 的 Web 面板认证与数据隔离。
- 搁置原因：产品方向改为"本地模式 + 云端模式"双形态、单用户自用。多用户隔离（阶段 2/3）失去场景；面板账号化（阶段 1）在自用场景下 API_KEY 登录已够用。若将来重启多用户，本方案仍可参考。

## 一、现状盘点

### 利好（改造基础比预期好）

1. **数据层天然多用户**：
   - per-user 表：`user_subscriptions`、`podcast_playback_states`、`podcast_queues`、`podcast_daily_reports(+items)` 均带 `user_id`；
   - 全局共享目录：`subscriptions`（RSS 源）、`podcast_episodes`（剧集）——多用户订阅同一播餐不重复抓取；
   - `users.api_key` 列现成（String(255), unique, nullable，全代码零引用）——个人 API key 载体已备好。
2. **admin 服务层已按 user_id 编程**：五个 admin service（apikeys/dashboard/settings/subscriptions/opml）方法签名均带 `user_id` 并用于过滤，当前由 `admin_required` 恒返回 1（虚拟单用户）。换真实 uid 后订阅/设置/仪表盘自动隔离，服务层几乎不动。
3. 面板登录限流（5/min）、Origin=Host CSRF 检查、logout 已存在，可整体保留。

### 缺口

1. **`ai_model_configs` 无 user_id**：AI 模型 key（OpenAI/转写）全局一份，所有人共用一份账单。
2. **面板认证是部署密钥**（`app/admin/auth.py`）：
   - `admin_session` cookie = `HMAC(secret, api_key)`——**静态值**：过期时间不参与签名、无用户绑定、无吊销语义，cookie 值被复制则永久有效（30min max_age 只是浏览器侧约束）；
   - 守卫返回值恒为 `user_id=1`，无"谁"的概念；API_KEY 泄露同时打穿 app 单用户模式与面板；
   - header 直传 API_KEY 通道并存。

## 二、目标架构

```
注册（开放）──→ 每个用户完全平权，无 owner / 无管理员概念
                    │
     ┌──────────────┴──────────────┐
     ▼                             ▼
Flutter app                    Web 个人中心（现 admin 面板改造）
JWT 登录                        账号密码登录 → 签名会话 cookie
                               管理自己的：订阅、设置、仪表盘、
                                           AI 模型 key、（可选）个人 API key
     └──────────数据边界：user_id──────────┘
              RSS 源目录 + 剧集 + 转写文本 = 全局共享
```

## 三、分阶段改动

### 阶段 1：面板认证账号化（~6 文件）

- `app/admin/auth.py` 重写：
  - cookie 载荷 `{uid}.{exp_ms}.{nonce}.{hmac}`——过期时间戳进签名（修静态 cookie 弱点），每次登录值不同；
  - `AdminAuthRequired`：验签 + 过期 → 按 uid 查库核对 `is_active`（即时踢出被禁用账号）→ **返回真实 uid**；
  - 删除 header API_KEY 通道；Origin=Host CSRF 检查保留。
- `app/admin/routes/setup_auth.py`：
  - 登录表单 = `email_or_username` + `password`，直接调 `AuthService.login()`（dummy_verify 时序防护、bcrypt、双语错误、last_login_at 全部复用）；
  - **任何注册用户都可登录**，无 owner/403 检查；5/min 限流保留；logout 不变。
- `app/admin/templates/login.html`：表单字段与文案。
- `.env.example`：API_KEY 注释更新（app 部署密钥，不再用于面板登录）。
- 测试重写：任意用户登录成功设 cookie；错误密码 401；被禁用账号 401；伪造/过期/旧式静态 cookie 401；Origin 不匹配 403。

### 阶段 2：AI 模型 key 按用户隔离（~8 文件，唯一 schema 改动）

- `ai_model_configs` 加 `user_id` 列（nullable）——**NULL = 全局共享 key**；
- 迁移 028：存量行保持 NULL（operator 零操作，升级后照常可用）；
- key 解析顺序（`key_resolver`）：当前用户自己的 key → 全局共享 key（NULL 行）→ 报错；
  - 家庭部署一份 key 全家用（NULL 行），公网各自配各自的——对应 Dify per-workspace model provider；
- 面板 apikeys 页按登录用户过滤：自己的 key 可管；共享 key（NULL）标注只读展示，不设管理入口（避免变相恢复"管理员"）。

### 阶段 2b：Celery 任务 key 归属（与阶段 2 同轮）

- 转写/摘要/日报任务入队时**记录发起者 user_id**，执行时按上述顺序解析 key——"谁触发谁付费"；
- beat 订阅刷新不用 AI key，不受影响；
- **转写文本与剧集保持全局共享**（transcripts 无 user_id，谁先触发用谁的 key 生成一份共用）——避免每用户重复转写同一集。

### 阶段 3（可选）：个人 API key

- `users.api_key` 存 SHA-256 哈希（创建时明文只显示一次）；
- `require_api_key` 解析顺序：JWT → 个人 key（哈希匹配 → 该用户 id）→ `.env API_KEY`（遗留兼容，user 1）→ 无配置时 dev 放行；
  - 不推翻"API_KEY 保留为部署密钥"的既定决策，只是把个人 key 插在它前面；
- 个人中心加"我的 API Key"卡片：生成/轮换/吊销。

### 阶段 4（文案收尾，并入阶段 1）

- 模板从"管理台"改"个人中心"（title/导航/登录页）；
- 路由路径 `/api/v1/admin/*` **不动**（避免破坏书签与前端引用），语义在文案层消化。

## 四、边界决策与理由

| 决策 | 理由 |
|------|------|
| 不设 owner/管理员/ADMIN_EMAIL/首用户特权 | 需求明确定夺：人人平权 |
| AI key NULL=共享而非归 user 1 | 现有部署 users 表未必有 id=1 真实行（虚拟单用户）；NULL 语义对家庭/公网两种部署都自洽 |
| 转写/剧集全局共享 | 避免每用户重复转写同一集；代价是"先触发者付费"，家庭场景可接受 |
| .env API_KEY 保留 | 遵守"API_KEY 保留为部署密钥"既定决策；仅在解析顺序中排后 |
| 每请求查库核对 is_active | 面板流量极小，换取即时吊销语义 |

## 五、明确不做

- 多租户管理页、RBAC、邮箱验证（无 SMTP）、密码找回；
- 不动 Flutter app 的 JWT 流程与 `require_api_key` 的 .env 模式；
- 存量 `user_id=1` 旧数据归属：既有问题非本方案引入；可选一次性搬迁（users 表恰好只有一行真实用户时把 1 的行归他），做不做另行定夺。

## 六、验证计划

- 每阶段：`uv run pytest` 全绿 + `uv run ruff check .`；
- Docker 端到端（模板打进镜像须 `--build`）：注册两个账号 → 各自登录面板 → 互看不到对方订阅/设置 → 各配各的 AI key → 转写任务用各自的 key；
- 阶段 1 附带安全用例：旧式静态 cookie 失效、被禁用账号即时踢出。
