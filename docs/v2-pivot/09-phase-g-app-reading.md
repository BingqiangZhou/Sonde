# Phase G · 退役 Web 阅读站，阅读并入 Flutter App

> 状态：✅ 完成（2026-10-28）　|　前置：Phase A–F　|　终点：阅读功能全部在 App 内，仓库不再含 web/

## 背景与决策

Phase D 建立的 Web 阅读站（`web/`，React Router SSR）定位为公开只读站点。发布 v2.0.0 后复盘：
App 才是唯一面向用户的形态，Web 站维护成本（独立 npm 项目、SSR 容器、CI job、nginx 分流）
与使用价值不成正比，且公开无鉴权读 API 与多用户产品定位有张力。

已确认的决策（2026-10-28）：

1. **访问模式**：登录后使用；`/api/v1/site/*` 从公开无鉴权收紧为 `require_user` 登录态。
   App 的 Dio 拦截器本就为所有请求附加 JWT，客户端零适配。
2. **UI 风格**：全面 Material 3（App 现有设计语言与 token 体系），不搬 Web 站报刊风。
3. **功能范围**：搬「全部动态页」与「三刊归档浏览页」；changelog/关于页不搬（App 自更新
   与关于信息已有承载）。
4. **导航形态**：新增底部「阅读」Tab（发现/Feed/阅读/我的 四栏），阅读成为一等公民；
   `/reports` 旧深链 redirect 到 `/reading`。

## 任务清单

### G1 后端：site API 收紧

- [x] `app/domains/site/routes.py`：router 挂 `Depends(require_user)`，docstring 改 App 语境
- [x] `service.py` 注释与 `_report_to_api` 命名更新（去掉 web 表述；**不删** `industry/site.py`，
      它仍被报告生成与 meta 端点消费）
- [x] 测试：认证 fixture 补 `require_user` override；新增「无凭据 → 401」用例（5 端点覆盖）
- [x] `uv run ruff check .` + `uv run pytest` 全绿（368 passed）

### G2 Flutter：阅读 Tab 与页面补齐

- [x] API 层：`/site/meta`、`/site/episodes`、`/site/episodes/all`、`/site/episodes/{id}` 四端点
      （retrofit + build_runner）；模型并入 `site_report_model.dart`（手写 fromJson，BIGINT id 归一）
- [x] `SiteReadingPage`（/reading，Tab 首页）：日/周/月切换 + 最新刊正文 + 站点标语（meta）；
      AppBar 入口：归档 / 全部动态 / 刷新
- [x] `SiteArchivePage`（/reading/archive）：三刊 Tab 分栏的历史刊物列表（key/版次/生成时间）
- [x] `SiteReportIssuePage`（/reading/issue/:kind/:key）：指定期详情，正文复用共享组件
- [x] `SiteAllEpisodesPage`（/reading/all）：分页列表；入选条目显示中文标题/摘要/评分/分类；
      落选条目显示原标题 + 落选原因 + 「去原始单集」外链（url_launcher）
- [x] 正文渲染抽为共享 `SiteReportBody`（分类徽章/时长/评分色块/为什么值得听）；
      旧 `site_reports_page.dart` 删除；**全量接 l10n**（en/zh ARB 新增 24 key）
- [x] 路由：shell 新增 `/reading` branch（index 2）；`/reports` → redirect `/reading`；
      `isHomeShellRoute` 补 `/reading`（迷你播放器适配）
- [x] 底部导航 4 栏（NavigationDestination + 桌面 Rail 同步）
- [x] Widget 测试：4 个页面 + 共享 FakeSiteRepository（8 用例全绿；全量 `flutter test`
      失败集与基线完全一致，无新增失败；analyze 零 error）

### G3 清理与部署

- [x] `git rm -r web/`（git 历史可追溯，不另存档）
- [x] `docker/docker-compose.yml`：删 web 服务（`WEB_SRC_CONTEXT`/`WEB_PUBLISH_PORT` 变量随之消失）
- [x] `docker/nginx/conf.d/default.conf.template`：删 `web_ssr` upstream，根路径改反代 backend
      （SSL 模板根路径本就指向 backend，无需改）
- [x] `.github/workflows/ci.yml`：删 web job（CI 剩 backend + flutter）
- [x] 根 `README.md` / `AGENTS.md`：移除 web 条目，Phase A–F 表述更新为 A–G，
      认证描述修正（JWT 已是现状）；`CHANGELOG.md` 增 Unreleased 条目
- [x] `docker compose up -d --build` 全栈终验：health 200、无 token 访问 site 端点 401

## 验收标准

1. 仓库不再含 `web/`；compose 五服务（postgres/redis/backend/celery/nginx）健康。
2. 无凭据访问 `/api/v1/site/*` 一律 401；App 登录态下阅读 Tab 数据正常。
3. Flutter analyze 零 error；新增 widget 测试全绿且不引入新的基线失败。
4. 阅读四页（Tab 首页/归档/指定期/全部动态）在 en/zh 双语下文案完整。

## 注意事项

- **G1 与 G3 必须同批部署**：后端收紧鉴权后旧 web 容器会立即失效，两者一起上即无窗口期。
- 单集跳转沿用 `/podcast/episode/detail/:episodeId`（以 episodeId 为主键查询）；若该端点对
  未订阅/未入选单集返回 404，后续可用 `/site/episodes/{id}`（含 transcript/audioUrl，模型已备）
  做轻量阅读兜底——本期未触发该场景，端点已预留。
- Web 端的收藏本地化（localStorage）早已在 Phase E 被服务端收藏取代；changelog/关于页随 web/
  一并退役，App 内关于信息走设置页与自更新对话框。
