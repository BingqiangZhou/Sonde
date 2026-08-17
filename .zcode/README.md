# .zcode — ZCode 项目配置目录

本目录是 ZCode 的项目级配置结构（由原 `.claude/` 目录转换而来，2026-08-17）。

## 结构

```
.zcode/
├── skills/                  # ZCode 技能发现目录（SKILL.md + name/description frontmatter）
│   ├── commit/              # 智能提交命令（原 /commit 命令）
│   └── release/             # 版本发布流程（原 /release 命令）
└── reference/               # 归档参考（ZCode 不自动加载，agent 按需阅读）
    └── agents/              # 多 agent 角色定义（roles/workflows/prompts，原 .claude/agents）
```

## 说明

- **skills/** 下的技能在 ZCode 会话中可通过 `/名称` 触发或由 agent 自动匹配。
- **reference/agents/** 是原 Claude 多 agent 体系的角色与工作流文档（architect、backend-dev、
  feature-development 等）。ZCode 没有项目级 agent 定义加载机制，主 agent 编排子任务时可
  直接阅读这些文件作为角色说明与流程清单。
- 项目级指令文件为根目录 `AGENTS.md`。
- 原 `.claudeignore` 的安全忽略规则已并入根 `.gitignore`（*.pem、*.sql、.vscode/settings.json）。
