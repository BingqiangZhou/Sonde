# 声读 Sonde 全页面风格优化方案

> 日期：2026-10-29 ｜ 范围：`frontend/`（Flutter App 全部 23 个页面 + 设计系统）
> 状态：**本文档第一部分（分析）与第二部分（本轮已实施）均已落地并通过验证**；第三部分为后续迭代路线图。

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

## 三、后续迭代路线图（未实施，按优先级）

### 3.1 结构性收敛（需组件/主题抽象，改动面大）

1. **"面板"组件抽取**：highlights/subscriptions/cache 三处各 ~80 行手写"面板头+Divider+底盖"结构合并为共享 `PanelSection` 组件（与 SurfacePanel 收敛）。
2. **圆角/字号双源合并**：`AppRadius.*` 静态值与 `AppThemeExtension` 平台感知值（iOS 16/14/10）统一为单一来源；`AppTextStyles`（10/11/13/15）并入 TextTheme 槽位，消除 1px 步进。
3. **壳层统一**：`site_reading_page` 从裸 AppBar 迁移到 ContentShell；三刊切换统一用 AdaptiveSegmentedControl（消除 SegmentedButton/TabBar/Adaptive 三套）。
4. **auth_verify（debug 页）整改**：整页 l10n 化（或明示 internal-only 样式）；语义色直引改走 scheme；直连 Dio 收敛。
5. **死 token 清理**：extension 的 `aiPrimary/shellGradient/lightWithGradient/darkWithGradient`、`sunGlow/sunRay/leaf`、`chart5/chart7` 断档命名；排版注释（三字体体系）与现实对齐；`monoStyle` 的 'monospace' 族处理。
6. **alpha 档位 token 化**：114 处 `withValues(alpha:)` 收敛为 3-4 档语义 alpha token。
7. **缓存管理页私有调色板**（`_CachePagePalette`）并入主题语义层；`_refresh` 失败静默吞掉需补错误态；滚动加载阈值统一用 `ScrollConstants`。
8. **AdaptiveButton 平台密度对齐**：iOS outlined 边框色/内边距与 Android 主题化样式同源；`AdaptiveScaffold` iOS FAB 定位（right:16/bottom:16）spacing 化并处理 safe-area。

### 3.2 散点遗留（本轮分析发现、尚未处理的小项）

9. **l10n 残留**：forgot 页英文兜底 `_fallback*` 常量与可空 `AppLocalizations.of` 写法；profile 头像 `'User menu'` 英文 semantics hint。
10. **auth 视觉不一致**：login 标题 `headlineLarge` vs register 默认字号；register 字段间距 smMd vs login md；onboarding 未迁 AuthShell、图标圈 120/56 魔数。
11. **register 条款/隐私链接 `onTap` 为空 TODO**——需产品决策（法务页面 URL）后补。
12. **discover 页魔数**：`maxHeight<540 || screenHeight<720`、`width<600 ? 20 : 12` 阈值未用 Breakpoints/spacing；错误态把原始 error 直塞 AppEmptyState.title。
13. **episodes 页**：筛选 Apple 自制 pill vs Android FilterChip 两套视觉；筛选对话框假 Switch 占位；`_desktopEpisodeCardHeight=160` 与 feed 的 172 两套卡高。
14. **detail 页**：回到顶部按钮定位魔数（56/32/width*0.1）；聊天抽屉宽 420/0.94；l10n 三种取法（context.l10n / AppLocalizations.of ?? En / 可空）应统一为 context.l10n。
15. **highlights 页**：`_isLoadingMore/_hasMore` 在 build 中赋值（实例字段状态易失真）；`delta=200` 阈值。
16. **subscriptions 页**：空/错态 Icon(56) 自绘未用 AppEmptyState；`maxScrollExtent-200` 阈值。
17. **archive 页**：`generatedAt.split('T')` 手工解析应换 TimeFormatter。
18. **site_all_episodes**：`subscriptionId: item.episodeId // 占位` 隐患（跳转详情的参数冒用）。
19. **杂项**：splash 用 spacing 当控件尺寸；appearance 页 segment 图标 size 16 魔数；`custom_adaptive_navigation` 侧栏手写 isDark surface 字面量；AuthShell 480/AppEmptyState 420/ProfileShell 120 等视口魔数未进 token；muted 文字三套近义 token 定义本身的收敛（本轮只修了使用侧）。

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
