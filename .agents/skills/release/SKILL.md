---
name: release
description: Release workflow for 声读 Sonde — generate the CHANGELOG via git-cliff, bump the frontend/pubspec.yaml version and build number, update README version badge, then commit, tag and push. Use whenever the user asks to release a new version, says /release <version>, 发版, 发布新版本, or cut a release.
---

# Release Workflow

The user provides a version number (e.g. `/release 1.0.0` or "发布 1.0.0"). Execute these steps in order; stop and surface the problem if any step fails.

## Step 1: Generate CHANGELOG

```bash
git-cliff --tag v<版本号> -o CHANGELOG.md
```

## Step 2: Update README.md

Edit `README.md` directly:

1. Update the version badge
2. Update the current-version statement and date
3. Update feature/version annotations where needed

## Step 3: Bump the Version

1. Read the current version from `frontend/pubspec.yaml` (format: `x.y.z+N`).
2. Set the new version number to the user-provided one.
3. Increment the build number (`+N`): current + 1 (e.g. `0.39.0+99` → `0.40.0+100`).

## Step 4: Commit

Stage `CHANGELOG.md`, `README.md`, `frontend/pubspec.yaml` and commit with:

```
chore(release): update version to <版本号> and generate changelog
```

## Step 5: Push the Commit

Push the commit to the remote repository.

## Step 6: Create and Push the Tag

```bash
git tag v<版本号>
git push origin v<版本号>
```

## Worked Example

Input: `/release 1.0.0`

- Current version: `0.39.0+99` → new version: `1.0.0+100`（build 99+1）
- Tag: `v1.0.0`
- Commit message: `chore(release): update version to 1.0.0 and generate changelog`
