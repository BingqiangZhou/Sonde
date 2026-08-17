# Sonde - Flutter 前端

跨平台移动应用，提供播客订阅管理、音频播放、AI 对话等功能。

## 技术栈

| 技术 | 说明 |
|------|------|
| Flutter (Dart 3.8+) | 跨平台 UI 框架 |
| Material 3 | UI 设计系统 |
| Riverpod 3.x | 状态管理 |
| GoRouter | 路由管理 |
| Dio + Retrofit | HTTP 客户端（ETag 缓存、Token 刷新） |
| Drift (SQLite) | 本地数据库（下载、播放进度、剧集缓存） |
| audioplayers | 音频播放 |

## 项目结构

```
frontend/lib/
├── core/                   # 核心层
│   ├── app/               # 应用入口配置
│   ├── constants/         # AppSpacing, AppRadius, AppDurations, Breakpoints
│   ├── database/          # Drift ORM（AppDatabase, DownloadDao, PlaybackDao, EpisodeCacheDao）
│   ├── events/            # 事件总线
│   ├── localization/      # 国际化（中/英 ARB）
│   ├── network/           # Dio 客户端（ETag 缓存、Token 刷新、重试）
│   ├── offline/           # ConnectivityProvider（离线感知）
│   ├── platform/          # 平台适配（页面过渡、自适应控件、触觉反馈）
│   ├── providers/         # 全局 Providers
│   ├── router/            # GoRouter 路由配置
│   ├── services/          # 缓存、更新检查、下载、Home Widget、Spotlight
│   ├── storage/           # SharedPreferences + SecureStorage
│   ├── theme/             # AppTheme, AppColors (design tokens), CupertinoTheme
│   ├── utils/             # AppLogger, Debounce, URL 规范化
│   └── widgets/           # 通用组件
│       ├── adaptive/      # 14 个 .adaptive() 自适应控件
│       └── ...            # CustomAdaptiveNavigation, 对话框, 骨架屏
│
├── shared/                 # 共享层
│   ├── models/            # PaginatedState, GitHubRelease
│   └── widgets/           # EmptyState, Loading, Skeleton, SettingsSectionCard
│
└── features/               # 功能模块
    ├── auth/              # 认证（data/domain/presentation 三层架构）
    ├── home/              # 主页（StatefulShellRoute 外壳）
    ├── podcast/           # 播客（最大模块，含发现/排行榜）
    ├── profile/           # 个人中心（订阅、历史、缓存管理）
    ├── settings/          # 设置（外观、更新检查）
    └── splash/            # 启动页
```

## 快速开始

### 1. 安装依赖

```bash
cd frontend
flutter pub get
```

### 2. 代码生成

修改 `@riverpod`、`@RestApi`、`@JsonSerializable` 或 Drift 文件后，需要重新生成：

```bash
dart run build_runner build
```

### 3. 运行应用

```bash
flutter run

# 指定设备
flutter run -d chrome          # Web
flutter run -d windows         # Windows
flutter run -d macos           # macOS
flutter run -d <设备ID>         # 移动设备
```

### 4. 构建发布

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web
```

## 测试要求

### Widget 测试

**必须为每个页面编写 Widget 测试**，测试文件放在 `test/widget/` 目录。

```bash
# 运行 Widget 测试
flutter test test/widget/

# 运行所有测试
flutter test

# 运行特定文件
flutter test test/widget/auth_test.dart
```

### 测试标准

- 页面渲染测试
- 用户交互测试
- 状态变化测试

### 多屏幕测试

必须在以下屏幕尺寸下测试：
- 移动端 (<600dp)
- 平板 (600dp-1200dp)
- 桌面 (>=1200dp)

## 开发规范

### 代码规范

- 使用 Material 3 组件（`useMaterial3: true`）
- 使用 Riverpod 3.x 进行状态管理
- 使用 `CustomAdaptiveNavigation` + `Breakpoints`（NOT flutter_adaptive_scaffold）
- 使用 `AppColors`、`AppRadius`、`AppSpacing` 设计令牌，禁止硬编码
- 使用 `Color.withValues(alpha:)` 替代已废弃的 `Color.withOpacity()`

### 响应式设计

使用 `CustomAdaptiveNavigation` 实现自适应布局：

```dart
CustomAdaptiveNavigation(
  selectedIndex: 0,
  destinations: [...],
  onDestinationSelected: (index) {...},
  body: body,
)
```

断点定义在 `Breakpoints` 类：
- `mobile <600`
- `tablet 600-1200`
- `desktop >=1200`

### 国际化

项目支持中英文双语，编辑 `app_localizations_en.arb` 和 `app_localizations_zh.arb` 后运行：

```bash
flutter gen-l10n
```

## 常用命令

```bash
# 代码分析
flutter analyze

# 格式化代码
dart format .

# 运行测试
flutter test

# 构建 APK
flutter build apk --release

# 清理缓存
flutter clean
```

## 相关文档

- [部署指南](../docs/DEPLOYMENT.md)
- [Android 签名配置](../docs/ANDROID_SIGNING.md)
