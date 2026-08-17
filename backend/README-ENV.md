# Docker环境配置说明

## 环境变量配置

本项目已将Docker配置改为从.env文件读取环境变量，提供了更好的配置管理和安全性。

### 配置文件位置
- 环境配置文件: `backend/.env`
- 环境配置模板: `backend/.env.example`
- Docker Compose文件: `docker/docker-compose.podcast.yml`

### 主要配置项

#### 数据库配置
```env
POSTGRES_DB=personal_ai
POSTGRES_USER=admin
POSTGRES_PASSWORD=MySecurePass2024!
DATABASE_URL=postgresql+asyncpg://admin:MySecurePass2024!@postgres:5432/personal_ai
```

#### 转录功能配置
```env
# 转录API配置 (必需: 替换为实际的API密钥)
TRANSCRIPTION_API_URL=https://api.siliconflow.cn/v1/audio/transcriptions
TRANSCRIPTION_API_KEY=your_siliconflow_api_key_here

# 文件处理配置
TRANSCRIPTION_CHUNK_SIZE_MB=10
TRANSCRIPTION_TARGET_FORMAT=mp3
TRANSCRIPTION_TEMP_DIR=./temp/transcription
TRANSCRIPTION_STORAGE_DIR=./storage/podcasts

# 并发控制
TRANSCRIPTION_MAX_THREADS=4
```

#### AI功能配置
```env
# OpenAI API (可选)
OPENAI_API_KEY=your-openai-api-key-here
```

### 使用方法

1. **配置转录API密钥** (必需)
   ```bash
   # 编辑 backend/.env 文件
   # 将 TRANSCRIPTION_API_KEY 替换为你的硅基流动API密钥
   TRANSCRIPTION_API_KEY=sk-your-actual-api-key-here
   ```

2. **启动服务**
   ```bash
   cd docker
   docker-compose -f docker-compose.podcast.yml up -d
   ```

3. **查看日志**
   ```bash
   docker-compose -f docker-compose.podcast.yml logs -f backend
   ```

4. **停止服务**
   ```bash
   docker-compose -f docker-compose.podcast.yml down
   ```

### 目录结构

Docker会自动创建以下目录用于转录功能：

```
backend/
├── .env                   # 环境配置文件
├── .env.example          # 环境配置模板
├── storage/              # 持久化存储
│   └── podcasts/        # 播客音频和转录文件
└── temp/                # 临时文件
    └── transcription/   # 转录临时文件

docker/
├── docker-compose.podcast.yml
```

### 安全注意事项

1. **不要提交.env文件到版本控制系统**
   - .env文件已添加到.gitignore
   - 包含敏感信息如API密钥

2. **定期更新API密钥**
   - 建议定期更换转录API密钥
   - 监控API使用量避免超限

3. **数据库安全**
   - 生产环境应使用更强的密码
   - 考虑使用Docker secrets或外部密钥管理系统

### 故障排除

1. **转录功能不工作**
   - 检查TRANSCRIPTION_API_KEY是否正确配置
   - 确认网络连接到硅基流动API
   - 查看backend容器日志排查错误

2. **存储目录权限问题**
   - 确保docker目录有写权限
   - 检查storage/podcasts目录是否创建成功

3. **环境变量未生效**
   - 确认.env文件在backend目录下
   - 重新启动Docker服务
   - 使用 `docker-compose config` 验证配置

### 配置优化

可以根据实际需求调整以下参数：

- `TRANSCRIPTION_CHUNK_SIZE_MB`: 根据网络和API限制调整文件块大小
- `TRANSCRIPTION_MAX_THREADS`: 根据服务器性能调整并发数
- `DATABASE_POOL_SIZE`: 根据负载调整数据库连接池大小