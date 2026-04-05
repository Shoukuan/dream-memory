# 🧠 Dream Memory — AI Agent 记忆管理系统

> **让 AI Agent 拥有可靠的长期记忆** — 四层架构，纯脚本实现，零新增依赖

[![Shell](https://img.shields.io/badge/Shell-Bash/SH-blue.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-OpenClaw-orange.svg)](https://docs.openclaw.ai)

---

## 🤔 为什么需要它

AI Agent 最大的痛点之一：**每次启动都是失忆状态**。

- 对话上下文断了，重复问同样的问题
- 用户的偏好、项目的决策、学到的教训全丢了
- 记忆维护靠人工——容易忘、容易乱、难以持续

Dream Memory 解决这个问题。它不依赖数据库或外部服务，而是用**纯 Bash + Markdown + 向量检索**构建了一套完整的 Agent 记忆生命周期管理。

---

## 🏗 四层架构

```
┌─────────────────────────────────────────┐
│  4️⃣ Agent 规则层 — AGENTS.md           │
│     定义：何时写、写哪、怎么写            │
├─────────────────────────────────────────┤
│  3️⃣ 向量检索层 — OpenViking + bge-m3    │
│     语义搜索，跨文档精准召回              │
├─────────────────────────────────────────┤
│  2️⃣ 文件存储层 — Markdown 文件组织       │
│     日记/主题/长期记忆，人可读可编        │
├─────────────────────────────────────────┤
│  1️⃣ 会话生命周期层 — 自动追踪            │
│     Session Start/End 自动 Flush        │
└─────────────────────────────────────────┘
```

---

## ✨ 核心功能

### 📋 6 个自动化脚本

| 脚本 | 功能 | 触发方式 |
|------|------|---------|
| `memory-distill.sh` | **记忆蒸馏** — 扫描当日日志，自动提取关键信息到长期记忆库 | Cron 每夜 |
| `memory-gc.sh` | **垃圾回收** — 归档过期周报、清理碎片、检查 MEMORY.md 尺寸 | Cron 每周 |
| `memory-selector.sh` | **智能选择器** — 去重 + 展示未读记忆，避免重复阅读 | 手动/自动 |
| `memory-score.sh` | **质量评分** — 按完整性给记忆文件打分 🔴🟡🟢 | Cron 每周 |
| `session-summary.sh` | **会话自动摘要** — 每 4 小时自动提炼会话关键内容 | Cron 定时 |
| `session-to-longterm.sh` | **晋升检查** — 发现高频主题，提议升级为长期记忆 | Cron 定时 |

### 🔑 关键特性

- **零新增依赖** — 纯 Bash + Markdown，不需要数据库
- **人可读可编辑** — 所有记忆文件都是 `.md`，直接打开就能看
- **自动防丢失** — Session End Flush 机制，会话结束前自动写记忆
- **跨会话同步** — 新会话启动时自动检查上个会话是否漏写记忆
- **向量检索集成** — OpenViking + bge-m3 提供语义搜索，支持中文
- **蒸馏阈值精确控制** — 200 行/25KB 触发截断，避免记忆失控

---

## 🚀 快速开始（5 分钟）

### 前置条件

- OpenClaw 环境
- Ollama（安装 bge-m3 模型用于向量嵌入）

### 1. 安装

将项目克隆或复制到你的 OpenClaw 技能目录：

```bash
git clone https://github.com/Shoukuan/dream-memory.git ~/.openclaw/skills/dream-memory
```

### 2. 执行脚本

```bash
chmod +x ~/.openclaw/skills/dream-memory/*.sh
chmod +x ~/.openclaw/skills/dream-memory/scripts/*.sh
```

### 3. 配置 AGENTS.md

在你的 workspace 的 AGENTS.md 中添加记忆写入规则：

```markdown
### 实时记录
- 用户纠正了我的错误 → 追加到 memory/YYYY-MM-DD.md
- 用户表达了偏好 → 追加到对应 memory/topics/*.md
- 任务完成/失败 → 更新 WEEKLY-PROGRESS.md
```

### 4. 设置 Cron 任务（可选）

```bash
# 每日 23:30 自动蒸馏
# 每周日凌晨 GC + 质量评分
# 每 4 小时自动会话摘要
```

详见 [SKILL.md](SKILL.md) 获取完整的 Cron 配置。

---

## 📂 文件结构

```
dream-memory/
├── SKILL.md              # 完整技能文档（所有细节）
├── README.md             # 项目概述（本文件）
├── LICENSE               # MIT 许可证
├── memory-distill.sh     # 记忆蒸馏
├── memory-gc.sh          # 垃圾回收
├── memory-score.sh       # 质量评分
├── memory-selector.sh    # 智能选择器
├── session-summary.sh    # 会话摘要
├── session-to-longterm.sh # 长期记忆晋升
├── scripts/
│   └── memory-check.sh    # 记忆检查工具
└── references/
    └── ollama-setup.md    # Ollama + bge-m3 安装指南
```

---

## 📰 记忆组织

```
memory/
├── MEMORY.md              # 长期记忆索引（< 25KB）
├── YYYY-MM-DD.md          # 每日笔记（原始日志）
├── topics/
│   ├── profile.md          # 用户画像
│   ├── goals.md            # 目标与计划
│   ├── investing-rules.md  # 投资规则
│   ├── decisions.md        # 关键决策记录
│   └── openclaw-config.md  # OpenClaw 配置经验
└── archive/               # 归档（自动清理）
```

---

## 🎯 核心概念

### Session Start Memory Check

每次新会话启动时，自动检查上一个会话是否有**未写入记忆的遗漏**。如果发现日志最后修改时间早于会话结束时间，则自动补写。

### Session End Memory Flush

会话结束时执行检查清单：
- [ ] 今天的决策写入 decisions.md
- [ ] 新知识点写入日志
- [ ] 错误/教训更新 MEMORY.md
- [ ] 未完成事项写入待办
- [ ] MEMORY.md 是否超限 → 超限时自动截断

### 记忆蒸馏（Distillation）

周期性扫描当日日志，将有价值的信息自动提升为长期记忆：

| 触发条件 | 动作 |
|--------|------|
| 同一问题出现 ≥2 次 | 总结为教训，写入主题文件 |
| 用户目标/身份变化 | 更新 profile.md + goals.md |
| 配置变更并验证成功 | 更新 openclaw-config.md |
| MEMORY.md > 200 行或 > 25KB | 自动截断保护 |

---

## 📄 许可证

MIT License — 详见 [LICENSE](LICENSE)。

---

## 👤 作者

由 [阿宽](https://github.com/Shoukuan) 创建，基于 OpenClaw AI Agent 平台验证。

完整技能文档见 [SKILL.md](SKILL.md)。

> 💡 **企业定制** — 需要多 Agent 协同记忆、团队知识图谱或私有化部署？联系我们获取支持。
