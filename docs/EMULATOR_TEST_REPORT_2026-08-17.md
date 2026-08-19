# Sonde 前端模拟器全功能摸底报告（2026-08-17）

> 测试方式：在 Android 模拟器上安装 debug APK，以真实用户路径逐功能操作，结合后端日志、数据库记录与网络抓取交叉验证。
> 本文只记录问题，不做修复。

## 测试环境

| 项 | 值 |
|---|---|
| 应用 | `com.opc.sonde` debug APK，v0.52.0+35 |
| 模拟器 | Medium_Phone_API_36.1（Android 16，emulator-5554） |
| 后端 | Docker 五件套（postgres / redis / backend / celery_worker / nginx），监听 `localhost:8000` |
| App 服务器配置 | `http://10.0.2.2:8000`（模拟器访问宿主机），App 内配置页显示 Connected ✓ |
| 测试账号 | `test-20260817@sonde.local` / `TestPass123`（user id=3，自动昵称 `user_0817mxb2`） |
| 初始数据 | 空库（0 用户、0 订阅），从注册流程开始完整走通 |

## ❌ 不能正常使用的功能

### P0-1 订阅功能失效

- **现象**：Discover 搜索结果行的 SUBSCRIBE / ⊕ 按钮点击大多无反应；约 1/5 次点击弹出“已订阅”成功 toast。
- **证据链**（成功 toast 出现时逐一核对）：
  - `/proc/net/tcp` 轮询抓不到 App 任何对外连接（订阅请求根本没发出）；
  - 后端无 `POST /podcasts/subscriptions` 日志（成功必有 `User X added podcast` INFO 日志，失败必有 4xx WARNING，均无）；
  - 数据库 `subscriptions` / `user_subscriptions` 表 0 行；
  - Profile 页统计与 `GET /api/v1/podcasts/subscriptions` 均为 0。
- **结论**：UI 成功反馈与服务端状态完全脱节；订阅从未真正落库，Feed / 日报 / 高亮整条价值链路因此空转。
- **排查线索**：
  - `podcast_search_result_card.dart:72-73`：卡片行 `onTap` 与 `onSubscribe` 都接到 `subscribeFromSearch`；
  - `base_episode_card.dart` 的订阅按钮实际是 30×30dp 的小 `IconButton(Icons.add_circle_outline)`（描边小图标，不是文字按钮），命中区域小；
  - 同坐标点击时灵时不灵，怀疑存在手势/命中测试或状态被意外重置的问题。

### P0-2 忘记密码 / 重置密码后端未实现

- **现象**：忘记密码页 UI 完整（Email 输入 + Send Reset Link 按钮），但提交无果。
- **根因**：前端 `auth_repository_impl.dart` 调用 `POST /auth/forgot-password`，后端无此路由，返回 404；`POST /auth/reset-password` 同样缺失。页面是纯 UI，无任何 API 支撑。
- **验证**：`curl -X POST http://localhost:8000/api/v1/auth/forgot-password ...` → `404 Not Found`；后端代码 grep 无 forgot 相关实现。

### P1-1 播放时倍速接口 422

- **现象**：每次播放 iTunes 外部单集，后端记录一次 `GET /api/v1/podcasts/playback/rate/effective | status=422`。
- **根因**：`discover_interaction_handler.dart:289` 对 Discover 单集硬编码 `subscriptionId: 0`，而该接口的 `subscription_id` 查询参数要求 `ge=1`。
- **影响**：前端有 fallback（回退默认倍速），不影响听感；但每次播放都产生一次无效请求 + 后端错误日志。

### P1-2 完整播放器展开不稳定

- **现象**：点击迷你播放器封面，首次能展开完整播放器（封面 / 进度条 / 上一首-暂停-下一首 / 15s 快退快进 / 倍速 / 定时 / 下载 / 播放列表齐全）；之后多次点击无法再次展开，界面停留在列表页 + 迷你播放器。
- **线索**：展开由 `podcastPlayerUiProvider.expand()` 驱动（`podcast_bottom_player_widget.dart`），怀疑展开状态被意外重置或 overlay 条件（`pageMode == embedded`）失效。

### P2-1 注册页确认密码错误文案

- 确认密码为空时报的是密码框文案 "Please enter your password"（应区分字段）；
- 错误提示在输入内容后不即时清除，再次提交才刷新。

### P2-2 无障碍文本实体泄漏

- 注册页条款标签的 contentDescription 读作 `I agree to the &#10; and `——HTML 实体 `&#10;`（换行）未转义，读屏用户会听到乱码。

### 环境限制（非 App bug）

- “Check for Updates” 手动检查失败（"Update check failed. Please try again."）：模拟器不继承宿主机代理（127.0.0.1:7897），GitHub 直连不通。宿主浏览器/带代理环境下该功能本身可用（启动时已成功缓存过 v0.52.0 release 信息）。
- adb `input text` 无法输入中文，中文搜索未验证。

### 轻微 UX（顺带记录）

- Onboarding 完成时先被 redirect 到 `/feed` 再 `context.go('/discover')`（onboarding_page.dart:37），中间态会闪现 Feed 页；
- 底部导航中间 Tab 显示 “Library”，实际路由是 `/feed`，命名不一致（可能是有意的设计）。

## ✅ 正常的功能

- **认证全流程**：Splash 自动跳转、注册（免填名 + 自动昵称 `user_0817mxb2`，正确落库）、登录、退出登录（确认对话框）、重新登录（登录态与邮箱记忆正常，Remember me 生效）
- **Onboarding**：3 步引导（欢迎 / AI 摘要 / 每日简报）、Skip 按钮、完成后进入 Discover
- **Discover**：Top Charts 中国区榜单真实数据（声动活泼、有知有行等）、分类筛选 chips（休闲/犯罪纪实/创业/投资）、英文搜索（“AI” 返回带 Subscribe 按钮的结果列表）、单集详情底部弹层（日期/时长/完整 shownotes/Play）、播客单集列表 sheet（8 集正常加载）
- **播放器**：真实音频播放（44100Hz 立体声，16:51 单集完整播完 position=duration）、暂停 / 恢复（音频轨 actual_seconds 验证）、迷你播放器（封面/标题/进度推进/暂停/播放列表）、队列弹层（空态 + Pull to refresh）、完整播放器（首次展开时所有控制齐全）
- **Profile 全套**：统计卡片（订阅/单集/AI 摘要/收听/日报/高亮）、收听历史（空态）、下载管理（空态 + 存储余量 1.83GB）、外观（Light/Dark/System 切换即时全局生效，深色模式已验证）、语言选择弹层（System/简体中文/English）、存储与缓存（总缓存 2.62GB 分类统计 + 分类清理按钮）、Backend API 服务器配置弹层（URL + Connected 状态 + 测试连接）、关于 / 版本（v0.52.0 (114)）
- **空状态设计**：Feed（"Your feed is quiet today" + "You haven't subscribed to any podcasts yet" + Explore Podcasts CTA）、历史（No history）、下载（No downloaded episodes）、队列（Queue is empty）

## 总评与修复优先级建议

浏览 / 播放 / 账户链路健康，空状态设计完善。核心断点在**订阅落库**（导致 Feed、日报、高亮整条核心价值链路空转）和**忘记密码**（后端缺路由）。

建议修复顺序：

1. 订阅按钮（P0-1）——先解决“点击无反应 + 假成功”，再验证落库闭环；
2. 忘记密码端点（P0-2）——后端补 `POST /auth/forgot-password` 与 `POST /auth/reset-password`；
3. 倍速 422（P1-1）——外部单集 `subscriptionId: 0` 改为 null 或放开校验；
4. 播放器展开（P1-2）；
5. 两个 P2 文案 / a11y 小修。
