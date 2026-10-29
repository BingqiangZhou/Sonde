# GitHub Actions 快速参考 / GitHub Actions Quick Reference

## 快速发布 / Quick Release

### 创建并推送版本 tag / Create and Push Version Tag

```bash
# Linux/macOS
./scripts/create-release.sh 1.0.0

# Windows (PowerShell)
.\scripts\create-release.ps1 -Version 1.0.0
```

### 或手动创建 / Or Manual Creation

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

---

## 文件结构 / File Structure

```
.github/
└── workflows/
    └── release.yml     # 发布工作流 / Release workflow

docs/
├── GITHUB_ACTIONS_GUIDE.md    # 完整使用指南 / Full guide
└── ANDROID_SIGNING.md         # Android 签名配置 / Android signing

scripts/
├── create-release.sh          # Linux/macOS 发布脚本
└── create-release.ps1         # Windows 发布脚本
```

---

## Tag 命令参考 / Tag Commands Reference

```bash
# 查看所有 tags / List all tags
git tag -l

# 查看远程 tags / List remote tags
git ls-remote --tags origin

# 删除本地 tag / Delete local tag
git tag -d v1.0.0

# 删除远程 tag / Delete remote tag
git push origin :refs/tags/v1.0.0

# 查看标签详情 / Show tag details
git show v1.0.0
```

---

## 构建产物 / Build Artifacts

| 平台 / Platform | 文件格式 / Format |
|-----------------|-------------------|
| Android (ARM64) | `.apk` |
| Android (ARM) | `.apk` |
| Android (Universal) | `.apk` |
| Android (Play Store) | `.aab` |
| Windows | `.zip` |
| Linux | `.tar.gz` |
| macOS | `.zip` |

---

## 版本号示例 / Version Examples

```bash
v1.0.0          # 正式版本 / Official
v1.1.0-alpha    # Alpha 预发布
v1.2.0-beta     # Beta 预发布
v2.0.0-rc       # Release Candidate
v2.1.3-preview  # Preview 版本
```

---

## 查看状态 / View Status

| 检查 / Check | 链接 / URL |
|-------------|-----------|
| Actions | `/actions` |
| Releases | `/releases` |
| Tags | `/tags` |

完整 URL: `https://github.com/YOUR_USERNAME/YOUR_REPO/[actions|releases|tags]`
