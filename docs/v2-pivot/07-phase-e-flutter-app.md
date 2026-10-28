# Phase E · Flutter 核心版客户端

> 状态：⬜ 未开始　|　前置：Phase B（auth/favorites）、Phase C（评分/三刊数据就绪）　|　下一步：Phase F

## 目标

Flutter 端对齐 v2 后端：登录、订阅管理、发现（改走后端）、单集浏览（摘要/评分/转录）、三刊阅读、后台播放+进度续播、收藏同步。首版**暂缓**：队列管理、历史/统计、离线下载、睡眠定时 UI、AI 对话、高亮（代码保留不删，入口隐藏）。

## 任务清单

### E1 后端补缺（前置小项）

- [ ] `app/domains/discover/`：实现 `/api/v1/discover?q=` 与 `/discover/charts?country=&limit=`（多国合并、subscribed 标记、5 分钟缓存、ITUNES_DNS/ITUNES_PROXY_URL 出站定制；参考 ts-era `itunes.ts` 行为）+ pytest（mock HTTP）
- [ ] 单集接口补字段：episodes 列表/详情带 score/selected/category/zh 三件套（来自 ai_analyses current）；无分析时为 null
- [ ] 订阅接口暴露 tier；创建/编辑可设 tier
- [ ] 新增 `GET /api/v1/reports/{kind}/latest|/{key}`（App 侧读三刊，可直接复用 D1 site 域，鉴权可选）

### E2 API 客户端对齐（frontend）

- [ ] retrofit 客户端（`features/podcast/data/services/podcast_api_service.dart`）对齐：新增 favorites/discover/reports 端点；episodes 模型加 score/selected/category/zh 字段
- [ ] token 链路回归：401 自动刷新（B 阶段已通）、退出清理

### E3 功能页

- [ ] **登录/注册**：沿用现有 auth UI；注册入口按后端 403 提示"请联系管理员"；server_config 保留
- [ ] **我的订阅**：列表（含 tier 徽标/频率/暂停）、添加（URL 粘贴 + 发现页一键）、删除、立即刷新
- [ ] **发现页**：由直连 Apple 改调后端 discover（搜索 tab + 榜单 tab + 国家选择；旧直连服务保留作离线降级可选，默认走后端）
- [ ] **单集流/详情**：feed 列表展示评分徽标与中文摘要；详情页 = 播放器入口 + zh 三件套 + score/reason + 全文转录（分段懒加载）+ 收藏星标
- [ ] **三刊阅读**：新页（日/周/月切换 + 归档日期选择）：title/lead/highlights/分节渲染（对齐 web 阅读体验）
- [ ] **播放**：沿用现有 audio_service 后台播放/锁屏；进度续播走 `podcast_playback_states`（既有）；倍速保留
- [ ] **收藏**：星标 → /favorites 同步；收藏列表页
- [ ] 隐藏暂缓功能入口（队列管理/历史/统计/下载/对话/高亮；代码不动）

### E4 质量与联调

- [ ] `flutter analyze`（very_good_analysis）零新增告警；单测（auth 流、discover 仓库、favorites 同步）补齐
- [ ] Android 真机全流程：登录 → 发现 → 订阅 → feed → 播放（后台/锁屏/续播）→ 详情评分/转录 → 三刊 → 收藏
- [ ] 桌面（windows/macos 任一）冒烟：登录+阅读+播放可用
- [ ] i18n：新增文案补 zh/en ARB

## 验收标准

1. E1 pytest + flutter analyze/test 全绿。
2. Android 真机完成上述全流程无阻断；断网重连后 token 刷新正常。
3. 暂缓功能入口不可见但代码完好（开关式隐藏，便于后续开放）。
4. 与 web 数据一致：同一账号收藏在 App 星标后 web/收藏列表一致（web 首版 localStorage 除外，见 06 D2）。

## 注意事项

- Drift 本地缓存表（episodes_cache）继续用于 feed 离线浏览；不新增表。
- 发现页改后端后，原 16 国枚举与后端 ITUNES_COUNTRIES 取并集展示（后端为准）。
- 播放音频源直连 enclosure URL（audio_url），不经后端转发。
