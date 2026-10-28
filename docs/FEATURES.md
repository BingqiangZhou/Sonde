# 功能说明

本文档介绍 声读 Sonde 的核心功能实现。

---

## 音频转录功能

### 功能概述

播客音频转录功能允许用户将播客单集的音频自动转换为文本：

- 自动下载播客音频文件
- 音频格式转换（转换为 MP3）
- 大文件智能分割（10MB chunks）
- 使用硅基流动 API 进行语音识别
- 转录结果自动合并和存储
- 实时进度跟踪
- 任务管理和错误处理

### 技术架构

#### 核心组件

1. **AudioDownloader** - 音频文件下载器
   - 支持 HTTP/HTTPS 协议
   - 异步下载，支持进度回调

2. **AudioConverter** - 音频格式转换器
   - 使用 FFmpeg 进行格式转换
   - 转换为标准 MP3 格式（16kHz，单声道）

3. **AudioSplitter** - 音频文件分割器
   - 智能分割大文件为小片段
   - 保持音频时序完整性

4. **SiliconFlowTranscriber** - 硅基流动 API 集成
   - 支持并发转录请求
   - 自动限流和错误重试
   - 使用 SenseVoiceSmall 模型

### 任务状态

| 状态 | 说明 |
|------|------|
| pending | 等待中 |
| downloading | 下载中 |
| converting | 格式转换中 |
| splitting | 文件分割中 |
| transcribing | 转录中 |
| merging | 合并结果中 |
| completed | 已完成 |
| failed | 失败 |
| cancelled | 已取消 |

### API 接口

#### 启动转录

```
POST /api/v1/podcasts/episodes/{episode_id}/transcribe
```

请求：
```json
{
    "force_regenerate": false,
    "chunk_size_mb": 10
}
```

#### 查询状态

```
GET /api/v1/podcasts/episodes/{episode_id}/transcription
```

### 配置说明

```env
TRANSCRIPTION_API_URL=https://api.siliconflow.cn/v1/audio/transcriptions
TRANSCRIPTION_API_KEY=your_api_key
TRANSCRIPTION_CHUNK_SIZE_MB=10
```

---

## 密码重置功能

### 功能概述

基于邮件的密码重置流程，包含以下安全特性：

- 安全令牌生成
- 邮件通知
- 令牌有效期（1 小时）
- 自动使之前的令牌失效
- 密码重置后会话失效

### API 接口

#### 请求密码重置

```
POST /api/v1/auth/forgot-password
```

请求：
```json
{
    "email": "user@example.com"
}
```

响应：
```json
{
    "message": "如果账户存在，已发送密码重置链接。"
}
```

#### 重置密码

```
POST /api/v1/auth/reset-password
```

请求：
```json
{
    "token": "uuid-token-received-via-email",
    "new_password": "NewSecurePassword123"
}
```

### 安全特性

1. **令牌安全**
   - 使用加密安全的 UUID 令牌
   - 令牌 1 小时后过期
   - 成功重置后令牌失效

2. **邮件安全**
   - 不透露邮箱是否注册
   - 仅发送至注册邮箱
   - HTML 邮件含安全链接

3. **会话安全**
   - 密码重置后所有会话失效
   - 强制用户重新登录

### 邮件配置

```env
FRONTEND_URL=http://localhost:3000
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_USE_TLS=true
FROM_EMAIL=noreply@personalai.com
```

---

## 相关文档

- [认证系统](backend/docs/AUTHENTICATION.md)
- [部署指南](DEPLOYMENT.md)
