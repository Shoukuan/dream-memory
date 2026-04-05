# Dream Memory — AI Agent 记忆管理系统

> 四层架构的优化工作区记忆管理系统，基于 OpenClaw 验证

## 概述

Dream Memory 是一个为 AI Agent 设计的记忆管理系统，采用四层架构：
- **Agent规则层** — AGENTS.md 定义何时写、写哪、怎么写
- **文件存储层** — Markdown 文件组织长期/短期记忆
- **向量检索层** — OpenViking 提供语义搜索能力
- **会话生命周期层** — 自动追踪 Session Start/End

## 核心特性

- ✅ 6个自动化脚本（蒸馏/选择/评分/GC/会话摘要/晋升检查）
- ✅ Cron 调度支持（夜间蒸馏、周级GC、会话自动摘要）
- ✅ 记忆质量评分系统（🔴🟡🟢 三级标识）
- ✅ Session End Flush 机制（防止记忆丢失）
- ✅ OpenViking 向量检索集成（bge-m3 1024维）

## 快速开始

1. 安装本 skill 到 `~/.openclaw/skills/dream-memory/`
2. 复制 `scripts/` 到目标 workspace 并 `chmod +x`
3. 配置 AGENTS.md 规则
4. 安装 Ollama + bge-m3 模型
5. 配置 OpenViking 扩展
6. 创建 cron 调度任务

详见 [SKILL.md](SKILL.md) 获取完整文档。

## 文件结构

```
dream-memory/
├── SKILL.md              # 完整技能文档
├── README.md             # 项目概述（本文件）
├── memory-*.sh           # 核心脚本
├── session-*.sh          # 会话管理脚本
├── references/           # 参考资料
│   └── ollama-setup.md   # Ollama 配置指南
└── scripts/              # 额外脚本
    └── memory-check.sh   # 记忆检查脚本
```

## 许可证

内部项目，仅供团队使用。
