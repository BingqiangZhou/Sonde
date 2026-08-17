# 功能说明

**版本基线：v0.52.0（2026-04-21）**

本文档介绍 Sonde 的核心功能。功能变更历史见 [CHANGELOG.md](../CHANGELOG.md)。

---

## 自动化管线（核心）

系统通过 Celery Beat 定时任务实现全自动数据处理闭环，无需人工介入：

| 任务 | 频率 | 说明 |
|------|------|------|
| 刷新播客 RSS | 每小时整点 | 发现新单集，轻量 feed 快速路径 |
| 生成待处理摘要 | 每 30 分钟 | 扫描已转写单集，调用 LLM 自动生成中文摘要 |
| 生成播客日报 | 每天 19:30 | 汇总当日新单集与摘要 |
| 缓存清理 | 每天 04:00 | 清理过期音频缓存与临时文件 |

新单集发现后自动进入转写队列（含积压调度：每 5 分钟补批 20 条、Redis 锁、失败重试）。

---

## 用户认证与会话

- 邮箱注册登录，JWT 双 Token 机制（Access + Refresh 自动刷新）
- 滑动会话、多设备会话管理（查看设备信息和 IP）
- 基于邮件的密码重置（UUID 令牌 1 小时有效，重置后全部会话失效）
- 密码重置邮件不透露邮箱是否注册

## 播客管理

- RSS Feed 订阅，自动解析播客元数据
- 可配置的自动抓取频率（每小时/每日/每周）
- 批量创建、删除订阅；重复检测（标题 + URL）
- 分类管理、OPML 导入导出
- 懒加载分页、多维度筛选、全文搜索

## 音频播放

- 基于 audioplayers + audio_service 的完整播放器
- 后台播放、系统锁屏媒体控制（Android 前台服务 + MediaButtonReceiver）
- 播放/暂停、快进/快退、进度条拖动
- 播放进度记录和断点续播（启动时恢复上次播放）

### 播放增强

- 播放队列管理（添加、重新排序、自动推进）
- 个性化播放速度（每用户、每订阅独立记忆）
- 睡眠定时器、迷你浮动播放器
- 收听统计（时长、播放次数）

## AI 功能

### 音频转录

- 自动下载播客音频 → FFmpeg 转换为标准 MP3（16kHz 单声道）→ 大文件智能分割（10MB chunks）→ API 转录 → 结果自动合并存储
- 默认使用硅基流动（SiliconFlow）SenseVoiceSmall 模型，支持多提供商路由
- 并发转录、自动限流、错误重试
- 转录任务全状态管理（pending / downloading / converting / splitting / transcribing / merging / completed / failed / cancelled）
- 新单集自动调度转录，支持批量与强制重新生成

```env
# 关键配置（backend/.env）
TRANSCRIPTION_API_URL=https://api.siliconflow.cn/v1/audio/transcriptions
TRANSCRIPTION_CHUNK_SIZE_MB=10
TRANSCRIPTION_BACKLOG_ENABLED=true
```

### AI 摘要

- 每 30 分钟自动扫描已转写单集，调用 LLM 生成结构化中文摘要
- 摘要 prompt 针对可读性反复打磨（默认中文输出）

### 单集金句（Highlights）

- AI 从转录稿提取关键金句/亮点
- 转录稿与金句双视图切换浏览

### 播客日报

- 每天 19:30 自动生成当日播客日报
- 内联日历 UI、按日期渐进加载历史报告

### AI 对话

- 基于单集转录稿与 AI 对话讨论内容
- 多会话管理，支持思维内容过滤

## AI 模型配置

- 多供应商支持（OpenAI、Anthropic、DeepSeek、SiliconFlow 等）
- API Key 加密存储（RSA + Fernet）
- 管理面板内连接测试、使用统计

## 管理面板（`/super`）

- 仪表盘、系统统计与监控指标
- 订阅管理、API 密钥管理（可直接测试已存密钥）
- 用户审计日志、系统设置
- 独立认证体系（2FA、CSRF 保护、服务端渲染 HTML）

## 发现与浏览

- Apple Podcasts 排行榜浏览（分类、国家/地区选择）
- 搜索与排行榜双标签页、响应式网格布局
- 后端集成 xyzrank Top 1000 中文播客榜单同步
- iTunes 单集查询与应用内试听

## 离线与下载

- 离线连接状态感知（ConnectivityProvider）
- 后台下载管理（Drift SQLite 持久化、队列自动下载）
- 下载列表页面、已下载单集离线播放

## 平台集成

- 6 平台支持：Android、iOS、Web、macOS、Windows、Linux
- macOS Spotlight 索引、Android/iOS 主屏幕 Widget
- iOS Cupertino 风格适配、macOS Apple Podcasts 风格侧栏

## 用户界面

- Material 3 设计，中英文国际化
- 14 个 `.adaptive()` 自适应控件（Cupertino/Material 自动切换）
- CustomAdaptiveNavigation（非 flutter_adaptive_scaffold）
- 响应式断点：mobile <600 | tablet 600-1200 | desktop >=1200
- 骨架屏加载、平台感知页面过渡动画、深浅主题

---

## 相关文档

- [认证系统](../backend/docs/AUTHENTICATION.md)
- [部署指南](DEPLOYMENT.md)
- [Android 签名配置](ANDROID_SIGNING.md)
- [发布快速参考](RELEASE_QUICK_REF.md)
