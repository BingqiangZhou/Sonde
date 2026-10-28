# 声读 Sonde v2 转向文档集（2026-10-28）

本目录是 v2 转向（回归 Python + Flutter 多用户形态）的**唯一开发依据**。所有开发工作按此处的文档推进；实施中产生的任何设计变更，必须回写对应文档。

## 阅读顺序

| 文档 | 内容 | 读者 |
|---|---|---|
| [00-decisions.md](00-decisions.md) | 转向决策、分支布局、风险总表 | 所有人，先读 |
| [01-baseline-v0.md](01-baseline-v0.md) | v0 基线实测盘点（后端/Flutter/基础设施/已知问题） | 动手前必读 |
| [02-architecture.md](02-architecture.md) | 目标架构：数据模型、API、流水线、多用户与成本设计 | 动手前必读 |
| [03-phase-a-baseline-cleanup.md](03-phase-a-baseline-cleanup.md) | Phase A：基线收尾 | 按阶段读 |
| [04-phase-b-multiuser-auth.md](04-phase-b-multiuser-auth.md) | Phase B：多用户认证恢复 | 按阶段读 |
| [05-phase-c-scoring-reports.md](05-phase-c-scoring-reports.md) | Phase C：AI 评分与三刊成刊 | 按阶段读 |
| [06-phase-d-site-web.md](06-phase-d-site-web.md) | Phase D：站点读 API 与 Web 切换 | 按阶段读 |
| [07-phase-e-flutter-app.md](07-phase-e-flutter-app.md) | Phase E：Flutter 核心版 | 按阶段读 |
| [08-phase-f-ci-release.md](08-phase-f-ci-release.md) | Phase F：CI 与发布 v2.0.0 | 按阶段读 |

## 阶段状态看板

> 开发时随手更新此表与各 Phase 文档内的任务 checkbox。

| 阶段 | 内容 | 状态 |
|---|---|---|
| Phase 0 | 分支手术（ts-era 存档 + main 切回 v0 基线） | ✅ 完成（本地与远程均已同步） |
| Phase A | 基线收尾（验证、清理、品牌、迁入 web/industry） | ✅ 完成 |
| Phase B | 多用户认证恢复（JWT、注册开关、收藏） | ⬜ 未开始 |
| Phase C | AI 评分与三刊成刊（移植 TS 流水线） | ⬜ 未开始 |
| Phase D | 站点读 API 与 Web 阅读站切换 | ⬜ 未开始 |
| Phase E | Flutter 核心版客户端 | ⬜ 未开始 |
| Phase F | CI 与发布 v2.0.0 | ⬜ 未开始 |

## 总原则

1. **串行推进**：Phase A→F 依次进行，每阶段完成后更新看板，不跳阶段。
2. **每阶段一组 Conventional Commits**（feat/fix/docs/chore...），不混阶段提交。
3. **完成定义**：阶段文档中的验收标准全部满足（pytest/ruff、Flutter analyze、Docker 端到端等），才允许进入下一阶段。
4. **活文档**：设计变更必须回写本目录对应文件，文档与代码不允许长期脱节。
5. Python 依赖一律用 `uv`（禁 pip）；prompt 文本只进 `industry` prompts 目录；付费 AI 调用必须过 provider 层并写成本台账（Phase C 起）。
