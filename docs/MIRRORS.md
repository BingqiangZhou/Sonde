# 国内镜像源配置笔记

> 日期：2026-08-17 · 环境：Windows 11 + Docker Desktop（WSL2 后端）+ Flutter 3.47 + Gradle 9.1
>
> 起因：本机直连 `services.gradle.org` / `repo.maven.apache.org` / `deb.debian.org` 均被阻断或超时；
> 清华 tuna 镜像对 Debian trixie 仓库和 PyPI 返回 403；Docker Hub 拉取走 Dead Mirror。
> 本文记录每个下载环节最终采用的国内源（或代理）方案、配置文件位置、验证方法与踩过的坑，
> 供在新机器上复现或排查同类问题。

## 总览

| 下载环节 | 方案 | 配置位置 | 是否仓库文件 |
|----------|------|----------|:---:|
| Gradle 插件（AGP/Kotlin/foojay） | 阿里云 Maven 镜像，直连 | `%GRADLE_USER_HOME%\init.d\init.gradle.kts` | 否（用户级） |
| Gradle/androidx 依赖 | 官方源走代理，阿里云直连豁免 | `%GRADLE_USER_HOME%\gradle.properties` | 否（用户级） |
| Gradle 发行版（wrapper） | 不换，已缓存 | 项目 `gradle-wrapper.properties` | — |
| Docker 镜像拉取 | daocloud 加速器 | `~\.docker\daemon.json` | 否（用户级） |
| Docker 构建内 apt（Debian） | 阿里云 Debian 源 + 重试循环 | `backend/Dockerfile` | **是** |
| Docker 构建内 pip/uv（PyPI） | 阿里云 PyPI | `backend/Dockerfile` | **是** |
| 后端本地 uv 依赖 | 阿里云 PyPI | `%APPDATA%\uv\uv.toml` | 否（用户级） |
| Flutter/Dart 包（pub） | 已是国内源，无需改 | 用户环境变量 `PUB_HOSTED_URL` 等 | — |
| Android SDK（platforms 等） | 不换，`dl.google.com` 可直连 | — | — |

本机 `GRADLE_USER_HOME` 为自定义路径 `D:\Development\Android\Android_Gradle`，下文以该路径为例。

## 一、Gradle 插件镜像（阿里云）

**文件**：`D:\Development\Android\Android_Gradle\init.d\init.gradle.kts`（`init.d` 目录原本不存在，新建）

```kotlin
beforeSettings {
    pluginManagement.repositories {
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
    }
}
```

**原理**：init 脚本在 settings 求值前注入的仓库排在项目自带 `google()`/`mavenCentral()`/`gradlePluginPortal()`
之前，解析按顺序命中；阿里云没有的件自动回退官方源。

**验证**：`./gradlew help --refresh-dependencies --debug` 后统计日志中的请求主机，
阿里云命中 701 次，且构建退出码 0。

```bash
./gradlew help --refresh-dependencies --debug > "$TEMP/gd.log" 2>&1
grep -oE "https://[a-zA-Z0-9.-]+/" "$TEMP/gd.log" | sort | uniq -c | sort -rn
```

### ⚠️ 大坑：只能做 settings 级注入，不能加项目级仓库

曾尝试在 init 脚本里追加以下两种写法给**依赖**（androidx 等）也上镜像，全部失败：

```kotlin
// ❌ 写法一：allprojects
allprojects { repositories { maven("https://maven.aliyun.com/repository/public") } }

// ❌ 写法二：beforeProject
gradle.beforeProject { repositories { maven(...) } }
```

报错（二分法定位，任一写法都触发）：

```
Error resolving plugin [id: 'dev.flutter.flutter-plugin-loader', version: '1.0.0']
> A problem occurred configuring project ':gradle'.
   > Build was configured to prefer settings repositories over project repositories
     but repository 'maven' was added by settings file 'settings.gradle.kts'
```

**根因**：`:gradle` 是 Flutter 的 `flutter_tools/gradle` 复合构建（`includeBuild`）项目，
其内部强制 "prefer settings repositories" 模式，禁止任何项目级仓库注入；
init 脚本的 `allprojects`/`beforeProject` 注入会波及这个被包含的构建，导致所有 Flutter 项目无法构建。

**结论**：依赖（androidx 等）只能走各项目自带的 `google()`/`mavenCentral()`，由下面的代理配置兜底。

## 二、Gradle 代理与直连豁免

**文件**：`D:\Development\Android\Android_Gradle\gradle.properties`（新建）

```properties
# Gradle daemon 代理（与 git 代理一致；本机直连国际源被阻断）
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=7897
systemProp.https.proxyHost=127.0.0.1
systemProp.https.proxyPort=7897
# 阿里云镜像直连，不绕代理
systemProp.http.nonProxyHosts=localhost|127.0.0.1|maven.aliyun.com
```

**分工**：阿里云镜像（插件）直连；官方源回退、foojay 的 JDK 工具链下载
（`api.foojay.io` / Adoptium，无国内镜像）走代理。代理关闭时插件解析不受影响。

**注意**：gradle.properties 只能放 JVM/代理这类系统属性，**不能**配置仓库源；
仓库源的位置见上文 init 脚本。改完需 `./gradlew --stop` 停掉旧 daemon 再构建，
否则已运行的 daemon 不会重读该文件。

## 三、Docker 镜像加速器（daemon.json）

**文件**：`C:\Users\<用户>\.docker\daemon.json`

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://ij39ei1s.mirror.aliyuncs.com",
    "https://docker.nju.edu.cn"
  ]
}
```

原列表四个源全是死源：个人阿里云加速器 403、`registry.docker-cn.com` 早已停服、
`registry.cn-hangzhou.aliyuncs.com` 不是 docker.io 镜像端点、NJU 镜像基本仅校园网可用。
真正干活的是 daocloud，后两个只是无害备选。

### ⚠️ 大坑：必须在 Docker Desktop 完全退出后修改

在 Docker Desktop **运行中**编辑 `daemon.json`，它退出时会把内存里的旧配置刷回文件，覆盖修改——
表现为"改了、重启了、`docker info` 还是旧列表"。

正确时序：

```powershell
# 1. 完全退出（杀干净进程 + 停引擎发行版）
Stop-Process -Name 'Docker Desktop' -Force
wsl -t docker-desktop
# 2. 此刻再编辑 daemon.json
# 3. 重新启动
Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
```

（或者直接用 GUI：Settings → Docker Engine → 编辑 → Apply & Restart，GUI 自己管理时序。）

**验证**：

```bash
docker info | grep -A5 "Registry Mirrors"   # 应显示 daocloud 首位
time docker pull hello-world                # 实测 ~4s 拉取成功
docker rmi hello-world                      # 测试完清理
```

**应急技巧**：加速器不可用时，可手动加前缀拉取再重打标签：

```bash
docker pull docker.m.daocloud.io/library/python:3.11-slim
docker tag  docker.m.daocloud.io/library/python:3.11-slim python:3.11-slim
docker rmi  docker.m.daocloud.io/library/python:3.11-slim
```

## 四、Docker 构建内部源（backend/Dockerfile）

构建镜像时容器内还要访问 Debian apt 和 PyPI，这两个也有源的问题：

- **tuna 全线 403**（对 trixie 的 apt 仓库和 PyPI 都是），原 Dockerfile 的 tuna 配置直接失效；
- **阿里云 Debian 源偶发随机 502**：大批量安装（ffmpeg 一家就 ~200 个包）时总有几个包中招，
  apt 内置的 `Acquire::Retries "3"` 救不回来。

改动（已在本仓库 `backend/Dockerfile`，属仓库文件）：

```dockerfile
# apt：tuna → 阿里云
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources \
    && sed -i 's/security.debian.org/mirrors.aliyun.com\/debian-security/g' /etc/apt/sources.list.d/debian.sources

# apt 安装加外层重试循环，兜住阿里云随机 502
RUN apt-get update \
    && (apt-get install -y --no-install-recommends build-essential libpq-dev curl ffmpeg \
        || (sleep 15 && apt-get update && apt-get install -y ... ) \
        || (sleep 30 && apt-get update && apt-get install -y ... )) \
    && rm -rf /var/lib/apt/lists/*

# pip / uv：tuna → 阿里云 PyPI
ENV UV_INDEX_URL=https://mirrors.aliyun.com/pypi/web/simple \
    UV_EXTRA_INDEX_URL=https://mirrors.aliyun.com/pypi/web/simple
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/web/simple \
    && pip config set global.trusted-host mirrors.aliyun.com
```

**验证**：`cd docker && docker compose build backend celery_worker` 全程走阿里云，构建成功。
构建容器内还可通过 `host.docker.internal:7897` 访问宿主代理（已实测），
需要联网的构建步骤可用 `--build-arg HTTP_PROXY=http://host.docker.internal:7897` 传入。

## 五、uv 用户级 PyPI（本地后端开发）

**文件**：`C:\Users\<用户>\AppData\Roaming\uv\uv.toml`（新建）

```toml
index-url = "https://mirrors.aliyun.com/pypi/web/simple"
```

**验证**：临时 venv 中 `uv pip install six` 成功（1.17.0）。
项目内不配源（仓库是公开的，不放 CN 专属配置），靠用户级配置生效。

## 六、无需改动的环节

| 环节 | 原因 |
|------|------|
| pub / Flutter 存储 | `PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 已是用户级持久化环境变量 |
| Gradle 发行版 | 9.1.0 已缓存在 `%GRADLE_USER_HOME%\wrapper\dists`，仅升版本时下载；换源需改仓库文件 `gradle-wrapper.properties` 且 CN 镜像 URL 对公开仓库的外部贡献者不友好，故不改（需要时可用 `https://mirrors.cloud.tencent.com/gradle/gradle-x.y-all.zip`） |
| Android SDK | `dl.google.com` 国内可直连，实测 sdkmanager 正常 |

## 验证速查（2026-08-17 实测记录）

```text
maven.aliyun.com/repository/gradle-plugin   (foojay 插件 POM)      → 200, 73ms
maven.aliyun.com/repository/google          (AGP 8.13.1 插件 POM)   → 200, 53ms
maven.aliyun.com/repository/public          (asm-9.9.pom)           → 200, 57ms
mirrors.aliyun.com/pypi/web/simple          (six 索引页)            → 200, 11KB 真实内容
mirrors.aliyun.com/debian                   (trixie Release)        → 200, 138KB
mirrors.aliyun.com/debian-security          (trixie-security)      → 200, 42KB
docker.m.daocloud.io/v2/                    (registry 探活)         → 401（正常存活响应）
```

外加真实流量验证：Gradle `--refresh-dependencies` 阿里云命中 701 次；`docker pull hello-world` 4.1s；
后端 Docker 镜像全量构建成功；uv 装包成功。

## 附：同期环境问题（与换源相关，一并记录）

同一天为在模拟器跑通前端还解决了这些问题，详见 git 待提交变更：

1. **Java 25 与 Gradle 8.14 不兼容**（本机无独立 JDK，`JAVA_HOME` 指向 Android Studio JBR 25.0.2）：
   wrapper 升 9.1.0 + AGP 8.11.1 → 8.13.1（新版才能识别 `android-37.0` 这种 minor-version 平台目录名，
   flutter_secure_storage 等插件要求 compileSdk 37）+ foojay-resolver-convention 插件
   （自动下载 JDK 21 到 `%GRADLE_USER_HOME%\jdks`）。
2. **`docker/.env` 模板的 `BACKEND_CMD` 默认是 gunicorn**，镜像里未安装，容器 127 无限重启：
   本地部署置空该变量走默认 uvicorn。
3. **Kotlin 增量编译跨盘符警告**（pub 缓存在 D 盘、项目在 E 盘，"different roots"）：
   会自动降级不阻塞；若硬失败则在 `frontend/android/gradle.properties` 设 `kotlin.incremental=false`。
