# 声读 Sonde 全页面风格优化方案

> 日期：2026-10-29 ｜ 范围：`frontend/`（Flutter App 全部 23 个页面 + 设计系统）
> 状态：第一、二轮全部落地并通过验证（analyze 0 错误；测试 532 过/6 失败均为 main 既有；模拟器亮/暗回归无布局异常）。唯一遗留：register 条款/隐私链接 TODO（待产品决策）。

---

## 一、现状分析（问题总览）

分析手段：设计系统代码审读（theme/constants/adaptive 组件/壳组件）、全页面逐一审读（23 页）、模拟器亮色关键页截图（发现/单集榜/详情/资料库/阅读/个人资料）。

### 1. 设计系统层（结构性问题）

| # | 问题 | 位置 | 影响 |
|---|------|------|------|
| S1 | **ColorScheme container 角色未覆盖**：surfaceContainerLow/High/Highest、surfaceTint 仍来自 indigo 种子的 M3 tonal palette，与手工覆盖的 Apple 中性色混用 | `app_theme.dart` `_buildColorScheme` | 输入框填充、chip、SurfacePanel、分段控件全部带紫色偏色，浅暗两色均受影响 |
| S2 | 输入框错误态圆角(10)与正常态(12)不一致，校验报错时圆角跳变 | `app_theme.dart` `_inputBorder` vs `inputDecorationTheme` | 表单页视觉抖动 |
| S3 | `AdaptiveTextField` Material 回退绕过主题（裸 `OutlineInputBorder`，圆角 4 无填充） | `adaptive_text_field.dart` | 未显式传 decoration 的输入框与全局样式脱节 |
| S4 | `SurfacePanel.showBorder/showShadow` 死参数（声明但被忽略） | `app_shells.dart` | `AuthShell(showBorder:false)` 不生效 |
| S5 | 语义色无 dark 变体（success/warning/error 单值），且页面直引 `AppColors.*` 绕过 ColorScheme | `app_colors.dart` | 暗色下饱和度不符 Apple HIG |
| S6 | 聊天抽屉/头部硬编码 dark 系色（浅色模式下白字配浅底不可见） | `chat_sessions_drawer.dart`、`chat_header.dart` | 浅色模式真 bug |
| S7 | `bottomSheetTheme` 圆角 24 魔数；`0xFF5E5CE6` 字面量重复两处 | `app_theme.dart` | token 收敛度 |
| S8 | muted 文字三套近义 token（lightOnSurfaceMuted/onSurfaceVariant…）被无条件或手写 isDark 使用 | 多处 | 暗色下对比度不正确 |

### 2. 页面层（跨页面共性问题）

| # | 问题 | 波及页面 |
|---|------|---------|
| P1 | **空/错/载入三态实现碎片化**：至少 4 种模式（AppEmptyState / 自绘 Icon+Text / Center+Text(outline 色) / 手拼面板），错误态有的带重试有的没有 | site 系全部、episodes、feed 空态、subscriptions、highlights |
| P2 | **site_* 产品线（阅读/归档/收藏/全部动态/指定期）整体游离**：裸 Scaffold+AppBar、`colorScheme.outline` 当弱文字色 16 处、原生 RefreshIndicator、硬编码中文 | 5 个页面 |
| P3 | **site_favorites_page 是全应用风格最差页**：零 l10n 硬编码中文、`Colors.amber`、裸 `Image.network`、无 AppEmptyState | favorites |
| P4 | **按钮三轨并行**：AdaptiveButton vs 裸 FilledButton/OutlinedButton/TextButton（forgot/reset）vs FilledButton.tonal（highlights） | auth 2 页、highlights、all-episodes |
| P5 | 魔数泛滥：圆角 12/16/18/10/14/28、卡高 172/160、阈值 540/720/600/200、间距 `xxl - md` 算术、`spacing.xl` 当按钮高度 | feed、episodes、detail、profile、list、forgot/reset |
| P6 | 密码要求清单同一功能两种视觉（register 带卡片底色 vs reset 裸列） | register、reset |
| P7 | l10n 遗漏：favorites 全页中文、detail tooltip 中文、profile 活动卡「我的收藏」中文 | 3 处 |
| P8 | 评分徽章/收藏星标色绕过语义层（`AppColors.success/warning` 无暗色感知、`Colors.amber`） | all-episodes、favorites |

---

## 二、本轮已实施（全部通过验证）

### A. 主题与组件层（一次修复，全局生效）

1. **ColorScheme container 角色全覆盖**（`app_theme.dart`）：surfaceContainerLowest/Low/Container/High/Highest、surfaceTint 全部改为 Apple 分层中性色（浅色 F2F2F7→E5E5EA 阶梯，暗色 12121F→2C2C2E 阶梯）；error 增加 dark 变体；`0xFF5E5CE6` 字面量收敛为 `AppColors.primaryLight`。→ 全 App 输入框/chip/面板的紫偏消除。
2. **输入框错误态圆角对齐**：`_inputBorder` 改用 `AppRadius.mdLgRadius`，与正常态一致。
3. **bottomSheet 圆角 token 化**：24 → `AppRadius.xxl`。
4. **语义色 dark 变体**（`app_colors.dart`）：新增 `successDark/warningDark/errorDark` 与收藏色 `favorite/favoriteDark`（systemYellow）。
5. **SurfacePanel 死参数修复**：`showBorder/showShadow` 真实生效（边框可关、默认加极淡阴影提升层次）。
6. **AdaptiveTextField Material 回退主题化**：去掉裸 `OutlineInputBorder`，回落到 inputDecorationTheme。
7. **聊天抽屉/头部主题化**：硬编码 dark 系色 → `colorScheme.surface/onSurface/onSurfaceVariant`，修复浅色模式白字不可见。
8. **弱文本色统一**：`linear_section_header`、`transcription_step_indicators` 的手写 isDark/lightOnly 静态色 → `onSurfaceVariant`。

### B. 页面层（19 个文件）

- **site_favorites_page 重写**：l10n（3 个新 key）、AppEmptyState 空态/错误态+重试、PodcastImageWidget（占位/缓存策略）、AdaptiveButton、收藏星标 `favorite` token、自适应刷新指示器。
- **site_reading_page**：`outline` 弱文本 → `onSurfaceVariant`；空态/未发布态 → AppEmptyState；错误态带重试；spinner 自适应。
- **site_archive_page**：空/错态 → AppEmptyState（带重试）；RefreshIndicator → AdaptiveRefreshIndicator；条目弱文本色修正。
- **site_all_episodes_page**：空/错态 → AppEmptyState；加载更多 OutlinedButton → AdaptiveButton(outlined)；评分徽章色暗色感知（successDark/warningDark）；底部提示色修正。
- **site_report_issue_page**：三态全部 AppEmptyState 化 + 重试。
- **site_report_body**：4 处 `outline` 弱文本 → `onSurfaceVariant`。
- **forgot/reset_password**：裸 FilledButton/OutlinedButton/TextButton → AdaptiveButton（filled/outlined/text）；`spacing.xl` 当按钮高度的误用消除；reset 密码要求清单包卡片与 register 统一；成功态弱化色用 onSurfaceVariant。
- **podcast_feed_page**：圆角 12/16 → `AppRadius.mdLg/lgXl`；`xxl-md` 算术间距 → `xl`；自绘空态 → AppEmptyState。
- **podcast_episodes_page_view**：网格间距 12 硬编码 → `AppSpacing.smMd`；自绘空态（Icon 80）→ AppEmptyState。
- **podcast_episode_detail_page_header**：收藏 tooltip 硬编码中文 → l10n；封面圆角 18/10 → `AppRadius.chip/md`。
- **podcast_highlights_page**：FilledButton.tonal → AdaptiveButton(outlined)。
- **profile_page**：对话框圆角 14/28 → `AppRadius.lg/xxl`。
- **profile_activity_cards**：「我的收藏」硬编码中文 → l10n。
- **onboarding_page**：指示器改为胶囊形（pill）。

### C. l10n

新增 9 个 key（en/zh 成对）：`favorites_title/empty/remove`、`common_load_failed/no_data/not_published` 等，已 `flutter gen-l10n`。

### D. 验证结果

- `flutter analyze`：**0 errors**（无新增 warning）。
- `flutter test` 全量：**532 passed / 6 failed**——6 个失败经 `git stash` 双向对比确认全部为 main 既有失败（transcription×2、custom_adaptive_navigation、shared_header_style、login_page、content_share_entry），本次改动**零新增失败**。
- 模拟器（API 36）实机回归：亮色（资料库）+ 暗色（个人资料/阅读/发现/收藏）截图验证——暗色分层灰阶正确无紫偏、site 系页面三态规范、收藏页空态卡片化、无崩溃无布局异常。
- 期间顺手授权了 `POST_NOTIFICATIONS` 运行时权限（重装后系统弹窗）。

---

## 三、第二轮：路线图全部落地（2026-10-29 同日完成）

除「条款/隐私链接 TODO（待产品决策，暂不处理）」外，第一轮路线图 3.1/3.2 全部实施完毕。

### 3.1 结构性收敛（已全部实施）

1. ✅ **"面板"组件抽取**：新增 `PanelHeaderSliver` / `PanelBottomCapSliver`（app_shells.dart），highlights/subscriptions/cache 三处手写结构全部替换。
2. ✅ **圆角/字号双源统一**：解除 app_radius→app_colors 反向依赖后，extension 的 card/button/navItem/item/pill 半径改为引用 `AppRadius` 常量并删除 iOS 16/14/10 分叉（统一 14/10/8）；bottomSheet 接 `sheetRadius`、checkbox 接 `AppRadius.xs`；`AppTextStyles` 尺寸对齐刻度（13→12、15→14），monoStyle 增加 fontFamilyFallback。
3. ✅ **壳层统一**：阅读页迁 ContentShell（HeroHeader + 圆角视口 + 胶囊按钮，header 按钮用 iconOnly 密度修复 0.29px 溢出）；阅读/归档三刊切换统一 AdaptiveSegmentedControl。
4. ✅ **auth_verify 整改**：状态色改语义 tone 枚举按 scheme 解析；文档标注 internal-only（debug 路由独占，不进 l10n、Dio 独立属有意设计）。
5. ✅ **死 token 清理**：删除 extension 的 `aiPrimary/shellGradient/lightWithGradient/darkWithGradient/podcastGradientColors`、AppColors 的 `sunGlow/sunRay/leaf/chart5/chart7/aiBubble*/cosmicFilterActive` 与 8 个无引用的 on-surface/muted/TextTertiary 定义；chartColors 内联字面量；排版注释对齐现实（系统字体）。
6. ✅ **alpha 档位 token 化**：新增 `AppOpacity`（faint/border/light/medium/strong），0.15/0.1/0.3/0.5/0.5/0.7 六档高频值全库替换（35 个文件）。
7. ✅ **缓存管理页**：deepClean 色改语义 error 角色（视觉由灰变警示红，语义更正确）；`_refresh` 失败改为错误态 UI（AppEmptyState + 重试）；滚动阈值统一 `ScrollConstants.loadMoreThreshold`（highlights/subscriptions）。
8. ✅ **AdaptiveButton 平台对齐**：iOS outlined 边框改 outlineVariant 与 Android 同源；Material 三态补默认 padding 与 iOS 密度一致；`AdaptiveScaffold` iOS FAB 定位 spacing 化 + bottom safe-area。

### 3.2 散点遗留（除 #11 外已全部实施）

9. ✅ forgot 页删除全部 `_fallback*` 常量与可空 l10n 写法，统一 `context.l10n`；profile 头像 hint 接新增 key `profile_user_menu`。
10. ✅ login 标题改 headlineMedium 与 AuthShell 默认一致；register 字段间距 smMd→md 与 login 对齐；onboarding 图标圈 120/56 命名常量（整页翻页形态保留，不强行套 AuthShell——设计决策）。
11. ⏸ **register 条款/隐私链接 TODO**：待产品决策，本轮不处理。
12. ✅ discover：阈值接 `Breakpoints.medium` + spacing token；错误态改「固定标题 + error 副标题 + AdaptiveButton 重试」。
13. ✅ episodes：删除 Apple 专用 pill，双平台统一 FilterChip；删除筛选对话框假 Switch；卡高 160/172 保留为各自布局常量（列表页与流页卡型不同，非同款卡）。
14. ✅ detail：定位接 Breakpoints/AppSpacing；聊天抽屉宽命名常量；4 个文件 l10n 统一 `context.l10n`。
15. ✅ highlights：`_hasMore` 字段删除，滚动守卫改读 provider；阈值接 ScrollConstants。
16. ✅ subscriptions：空/错态改 AppEmptyState（错误态带重试）；阈值接 ScrollConstants。
17. ✅ archive：时间解析改 TimeFormatter（formatDate/formatTime）。
18. ✅ site_all_episodes/report_body：`goToEpisodeDetail` 的 subscriptionId 改可选，无订阅上下文时走 `episodeDetailDirect` 路由，删除 episodeId 冒充 subscriptionId 的占位。
19. ✅ 杂项：splash 独立尺寸常量；appearance 图标常量；导航侧栏 surface 字面量改 scheme；AuthShell 480/EmptyState 420 进 extension token（`authContentMaxWidth`/`emptyStateMaxWidth`）、ProfileShell 120 命名常量；muted/TextTertiary 定义收敛删除。

---

## 附：本轮变更文件清单

```
frontend/lib/core/theme/app_colors.dart          语义色 dark 变体、favorite token
frontend/lib/core/theme/app_theme.dart           container 角色/圆角/字面量
frontend/lib/core/widgets/app_shells.dart        SurfacePanel 参数生效
frontend/lib/core/widgets/adaptive/adaptive_text_field.dart  Material 回退主题化
frontend/lib/core/widgets/linear_section_header.dart         弱文本色
frontend/lib/features/auth/presentation/pages/  forgot/reset/onboarding ×3
frontend/lib/features/podcast/presentation/pages/  site ×5、feed、episodes×2、detail header、highlights
frontend/lib/features/podcast/presentation/widgets/  site_report_body、chat×2、transcription indicators
frontend/lib/features/profile/  profile_page、profile_activity_cards
frontend/lib/core/localization/  en/zh ARB + 生成文件
```
