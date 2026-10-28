# Phase D · 站点读 API 与 Web 切换

> 状态：⬜ 未开始　|　前置：Phase C　|　下一步：Phase E

## 目标

backend 提供公开站点读 API `/api/v1/site/*`（JSON 对齐 ts-era），`web/` 阅读站从"可构建"变为"真实数据可读"；Jinja2 管理面板补齐成本/报告/诊断/发现。

## 任务清单

### D1 site 读 API（backend，公开无鉴权）

- [ ] 新路由域 `app/domains/site/`（或挂 podcasts 域下独立 router）：**无鉴权**，仅读
- [ ] `GET /api/v1/site/meta`：自 `app/industry`（站名/主题/tagline）
- [ ] `GET /api/v1/site/episodes?limit=`：入选（selected 且 is_current）时间线，发表倒序
- [ ] `GET /api/v1/site/episodes/all?page=`：全部已分析单集分页（含落选：score+reason），50/页 + `{total,page,pages}`
- [ ] `GET /api/v1/site/episodes/{id}`：详情 = 单集基础 + **audio_url、duration_seconds** + zh 三件套 + score/category/tags + transcript（`podcast_episode_transcripts`）
- [ ] `GET /api/v1/site/reports/{kind}/latest`、`/{kind}/{key}`（daily/weekly=`YYYY-MM-DD`、monthly=`YYYY-MM`，正则校验）、`/{kind}?page=&size=`
- [ ] 响应字段名与 ts-era `/api/site/*` 逐一对照（camelCase：durationSeconds/titleZh/...；参考 ts-era `packages/backend/src/publication/read.ts`）
- [ ] pytest：各端点形状/分页/404/key 校验

### D2 web 切换到真实 API

- [ ] `web/` 的 loader 基址指向 backend（环境变量；nginx 同源反代 `/api/`）
- [ ] 页面字段适配（ts-era web 读 `/api/site/*`，现改 `/api/v1/site/*`，字段已对齐应仅改前缀与少量类型）
- [ ] 报告页（日/周/月 + 归档）、全部动态页、单集详情页数据渲染核对
- [ ] `/changelog` 页改读根 CHANGELOG.md（v2 基线注记后内容有效）
- [ ] 收藏页首版保持 localStorage（登录同步待 E 阶段 App 端先做，web 后续）
- [ ] `npm run build` + 本地跑 `web/` 连 backend 冒烟全页面

### D3 管理面板扩展（Jinja2）

- [ ] 成本页：ai_receipts 按 service/model 汇总（30 天）+ 最近 50 条
- [ ] 报告页：三刊列表（kind/key/revision/generated_at）+ 按需"重新生成"按钮（调 C5 服务函数）
- [ ] 单集诊断页：episodes join 转写状态 + 最新 ai_analyses（score/selected/失败原因），支持按状态过滤
- [ ] 订阅编辑暴露 tier（T1/T2）
- [ ] 发现入口：面板订阅页内嵌搜索/热门榜（调 Phase B/C 已备的 discover 服务；若 discover 尚未实现则本任务顺延至 E 前置，先留位）

### D4 compose 集成

- [ ] `docker/docker-compose.yml` 增加 web 服务（node 构建 + 自定义 server 反代 /api → backend，对齐 ts-era `apps/web/server.ts` 模式）
- [ ] nginx → web:3000（对外唯一入口），backend 不直接暴露
- [ ] 全栈起栈验证：`docker compose up -d --build` → web 首页/三刊/详情有真实数据、面板四新页可用

## 验收标准

1. site API pytest 全绿；响应与 ts-era 形状一致（字段名/嵌套）。
2. Docker 全栈：web 全页面（首页/三刊×3+归档/全部动态/单集详情/changelog/about）真实数据渲染。
3. 面板成本/报告/诊断页数据正确；报告可手动重生成且 revision+1。
4. `web/` `npm run build` 无错；无 TS workspace 残留依赖。

## 注意事项

- site API 公开意味着单集音频 URL/转录对外可见——个人站定位可接受（与 ts-era 一致）；若将来要私有化再加签名，不在本阶段。
- web 反代保留原有 cookie 面板逻辑不迁（web 无 /admin）。
- discover 服务实现若提前（E 阶段需要），D3 面板发现入口直接复用。
