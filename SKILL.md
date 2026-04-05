---
name: dream-memory
description: >
  优化的工作区记忆管理系统。四层架构（Agent规则 + Markdown文件 + OpenViking向量 + 会话生命周期）+ 6个自动化脚本 + cron调度。
  Use when: 为新Agent部署记忆系统、排查记忆丢失、优化蒸馏cron、修复OpenViking索引、
  配置Session Flush、查看记忆质量评分、配置Memory GC。
---

# Dream Memory — Agent记忆管理系统 (优化版 v2.1)

> 2026-04-04优化完成：从300+行精简到核心规则 + 6脚本自动化
> 架构：`AGENTS.md`(规则) → `memory/`(文件) → `OpenViking`(向量) → `Cron`(调度)

## 🏗️ 架构总览（四层）

```
第1层: Agent规则  — AGENTS.md（何时写、写哪、怎么写、何时Flush）
第2层: 文件存储   — MEMORY.md(索引) + memory/目录(全文) + WEEKLY-PROGRESS.md(周进度)
第3层: 向量检索   — OpenViking 0.1.18 + Ollama bge-m3(1024维)
第4层: 生命周期   — sessions.json追踪 + Session Start/End双向检
```

## 📁 文件结构

```
workspace/
├── AGENTS.md                 # 操作规则（记忆写入逻辑在此）
├── MEMORY.md                 # 长期记忆索引（<200行, <25KB，硬截断保护）
├── SOUL.md                   # Agent人格
├── USER.md                   # 用户画像
├── WEEKLY-PROGRESS.md        # 本周进度表（单一事实源）
├── .consolidate-lock          # 蒸馏检查锁（更新时间戳）
├── memory/
│   ├── YYYY-MM-DD.md         # 每日日志（Append only, 跨自动切换）
│   ├── topics/               # 专题详情（profile.md, goals.md, decisions.md...）
│   ├── archive/              # 压缩归档（旧碎片）
│   ├── archives/             # 周级归档
│   └── .surfaces.json        # 搜索去重记录（最多50条）
├── scripts/
│   ├── memory-distill.sh     # 蒸馏：MEMORY.md截断 + 索引整性检查 + 锁更新
│   ├── memory-selector.sh    # 轻量选择器：.surfaces.json去重 + 限5条
│   ├── memory-score.sh       # 质量评分：命中×3 + 年龄 + 大小 → 🔴🟡🟢
│   ├── memory-gc.sh          # 周维护：碎片合并→压缩→标签→归档→重建索引→报告
│   ├── session-summary.sh    # Session自动提取：最近会话→当天日志
│   └ session-to-longterm.sh # 晋升检查：8高频主题出现≥3次→建议长期化
```

## ⏰ Cron度表

| Job | Schedule | 脚本 | Target | Status |
|-----|----------|------|--------|--------|
| 记忆蒸馏-夜间 | `30 23 * * *` (stagger 5m) | memory-distill.sh | isolated main | ✅ |
| 记忆蒸馏-夜间(trader) | `45 23 * * *` | memory-distill.sh | isolated trader | ✅ |
| session-auto-summary | `0 */4 * * *` | session-summary.sh | isolated main | ✅ |
| memory-gc-main | `30 2 * * 0` (exact) | memory-gc.sh | main | ✅ |
| memory-gc (trader) | `0 2 * * 0` | memory-gc.sh | isolated trader | ✅ |

## 📐 Agent规则层（AGENTS.md核心摘要）

### 实时记录 ⚡

**何时立即写入当天日志**（匹配即写，不犹豫）：

| 信号 | 写入内容 |
|------|----------|
| 用户纠正错误 | 纠正内容 + 正确做法 |
| 用户表达偏好/习惯 | 偏好描述 |
| 用户透露目标/身份/项目上下文 | 摘要 |
| 用户说"记住/remember" | 原文verbatim |
| 外部系统指针（URL/ticket/channel） | 系统名 + 引用 |
| 用户报告任务完成（"已发/已清"） | 更新待办，标记✅ |

**格式**：`- HH:MM 用户偏好：git commit不加Co-Authored-By`
**铁律**：Append only，不修改历史行，跨日自动切换文件

### 精确蒸馏触发阈值 🎯

基于客观阈值，不凭感觉：

| 条件 | 动作 |
|------|------|
| MEMORY.md > 200行 OR > 25KB | `memory-distill.sh` 自动截断到200行 |
| 会话结束但未Flush | 新会话Session Start Check自动补写 |
| >8h未写日志 | Heartbeat触发摘要提取 |
| 会话运行>30min未写 | Session End Flush |
| `.consolidate-lock` <1h | 跳过蒸馏（防重复执行） |

### Session End Flush 🔥

**触发**（任一满足即执行）：
1. 用户说"下班/再见/晚安/goodbye"
2. 会话运行>30min且未写日志
3. 心跳检测>8h未写日志
4. 跨日切换

**检查清单**：
- [ ] 重要决定 → `memory/topics/decisions.md`
- [ ] 新知识 → `memory/YYYY-MM-DD.md`
- [ ] 错误/教训 → `MEMORY.md` lessons表
- [ ] 待办/开放线程 → 日志"待办"段
- [ ] MEMORY.md > 4KB → 修剪
- [ ] 轻量蒸馏 → 扫描当天→更新topics→检查MEMORY.md
- [ ] OpenViking索引更新 → 见下方"向量检索层"（**服务未响应则跳过**）

### Session Start Check 🔍

**核心原则**：新会话启动时，自动检查上一个会话是否有未写入记忆的遗漏。

**步骤**：
1. 读 `~/.openclaw/agents/{agent-id}/sessions/sessions.json`
2. 找上一个用户会话的 `endedAt`（状态=`done`）
3. 比对当天日志最后修改时间：`stat -f %m memory/YYYY-MM-DD.md`
4. 日志修改时间 < endedAt → ❌ 补写

**补写格式**：
```markdown
## [YYYY-MM-DD HH:MM 补写] — 标题
- 修复了什么/完成了什么/发现了什么
- 补写原因：上一个会话 {endedAt时间} 结束后未自动Flush
```

### 长期记忆晋升规则 🧠

| 触发信号 | 动作 |
|----------|------|
| 同类错误/纠错≥2次 | 提炼为教训→写入`memory/topics/<topic>.md` |
| 核心目标/身份变化 | 更新`profile.md`和`goals.md` |
| 系统配置变更验证成功 | 更新`openclaw-config.md` |
| 项目里程碑/方向调整 | 更新`goals.md` |
| 新技能安装验证可用 | 更新MEMORY.md技能状态 |
| 已有记录被证伪 | 源文件修正 + MEMORY.md entry更新 |

**写入约束**（严格执行）：
- MEMORY.md < 200行 AND < 25KB
- Entry格式：`- [Title](memory/topics/file.md) — one-line hook`
- Entry正文<150字符，详情移入主题文件
- 主题文件按内容域组织，合并不创建近重复

## 🔧 自动化脚本摘要

### memory-distill.sh
```bash
bash scripts/memory-distill.sh [workspace_dir]  # 默认 $HOME/.openclaw/workspace
```
- MEMORY.md超限→截断到200行
- 索引完整性：提取所有`[]()`链接，验证目标文件存在
- 更新`.consolidate-lock`时间戳

### memory-selector.sh
```bash
bash scripts/memory-selector.sh record "memory/topics/goals.md"    # 记录展示
bash scripts/memory-selector.sh list                               # 列出最近记录
bash scripts/memory-selector.sh clean                              # 清理（>30→保留20）
echo -e "file1\nfile2\nfile3" | bash scripts/memory-selector.sh filter  # 过滤已展示
```
- `.surfaces.json`记录最近展示的文件路径
- `filter`命令返回最多5条新结果

### memory-score.sh
```bash
bash scripts/memory-score.sh [workspace_dir]
```
- 评分：搜索命中×3 + 年龄权重(90-天数) + 大小/100
- 🔴<50低质量 | 🟡<100中等 | 🟢高质量
- 输出建议归档的低分文件

### memory-gc.sh
```bash
bash scripts/memory-gc.sh  # 完整7步维护流水线
```
1. 碎片合并（同一天的多个文件合并）
2. 压缩旧日志（>5KB的压缩到archive）
3. 补标签
4. 周级归档（>7天的按周归档
5. 重建索引
6. 大小检查
7. 写维护报告

### session-summary.sh
```bash
bash scripts/session-summary.sh [workspace_dir]
```
- 找最近活跃的.jsonl会话文件
- 提取assistant关键操作
- 追加到当天日志

### session-to-longterm.sh
```bash
bash scripts/session-to-longterm.sh [workspace_dir]
```
- 扫描8个高频主题：修复/优化/配置/教训/决策/发现/规则/工具
- 同一主题出现≥3次→建议晋升到topics
- 检查>30天的旧日志→建议归档

## 🔍 向量检索层（OpenViking）

### 服务信息
- **版本**：OpenViking 0.1.18
- **端口**：1933（`http://127.0.0.1:1933`）
- **配置**：`~/.openviking/ov.conf`
- **Embedding模型**：Ollama bge-m3（**dimension: 1024**，必须配置）

### 状态检查
```bash
# 系统状态
curl http://127.0.0.1:1933/api/v1/system/status
# VikingDB状态
curl http://127.0.0.1:1933/api/v1/observer/vikingdb
# 完整系状态
curl http://127.0.0.1:1933/api/v1/observer/system
# Swagger UI（浏览器打开）
open http://127.0.0.1:1933/docs
```

### ⚠️ OpenViking v0.1.18 API变更

**`POST /api/v1/resources` 已不再支持用户内容！** 返回错误：
```
INVALID_ARGUMENT: add_resource only supports resources scope
```

**正确的方式 — 使用Session API**：
```bash
# 1. 创建会话
SESSION_ID=$(curl -s -X POST http://127.0.0.1:1933/api/v1/sessions \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['result']['session_id'])")

# 2. 添加消息（可以是文件内容）
curl -s -X POST "http://127.0.0.1:1933/api/v1/sessions/$SESSION_ID/messages" \
  -H "Content-Type: application/json" \
  -d "{\"role\":\"user\",\"content\":\"记忆内容...\"}"

# 3. 提交会话（触发记忆提取）
curl -s -X POST "http://127.0.0.1:1933/api/v1/sessions/$SESSION_ID/commit"

# 4. 等待处理完成
curl -s -X POST http://127.0.0.1:1933/api/v1/system/wait \
  -H "Content-Type: application/json" -d '{}'
```

**搜索API**：
```bash
# 语义搜索（无session上下文）
curl -s -X POST http://127.0.0.1:1933/api/v1/search/find \
  -H "Content-Type: application/json" \
  -d '{"query":"记忆系统","limit":5}'

# Grep内容搜索
curl -s -X POST http://127.0.0.1:1933/api/v1/search/grep \
  -H "Content-Type: application/json" \
  -d '{"uri":"viking://","pattern":"蒸馏"}'
```

### BGE-M3 关键配置
```yaml
# ov.conf 中必须包含：
added dimension: 1024    # bge-m3输出1024维，默认2048会导致embedding失败
```

## 🆕 安装到新Agent

1. 安装本skill（复制到~/.openclaw/skills/dream-memory/）
2. 复制scripts/下6个脚本到目标workspace的scripts/目录并chmod +x
3. AGENTS.md中添加规则层内容（实时记录/Flush/晋升规则）
4. 安装Ollama + bge-m3模型（见[references/ollama-setup.md](references/ollama-setup.md)）
5. 配置OpenViking扩展（mode, configPath, targetUri）
6. 创建6个cron任务（参考上方调度表）
7. 创建memory/目录结构
8. 验证：`bash scripts/memory-score.sh` → 应显示文件列表和评分

## 🐛 故障排查

| 症状 | 原因 | 修复 |
|------|------|------|
| OpenViking索引为0 | embedding维度不匹配 | ov.conf添加`added dimension: 1024` |
| POST /resources报INVALID_ARGUMENT | v0.1.18不支持用户内容 | 改用Session API |
| 跨日日志未创建 | 无人触发写入 | Session Start Check自动补写 |
| memory_search返回重复 | 无重机制 | memory-selector.sh去重 |
| MEMORY.md膨胀 | 无截断保护 | memory-distill.sh自动截断 |
| 蒸馏后内容丢失 | Session结束未Flush | 增强End Flush规则 |
| "服务无响应则跳过" | curl超时或端点不存在 | 用`/api/v1/system/status`检查，非`/health` |

## 📊 关键指标

- memory/ 文件数：定期用 `memory-score.sh` 评估
- MEMORY.md 大小：< 25KB（硬阈值）
- 索引完整性：蒸馏脚本自动检查，0失效链接为优
- .surfaces.json：最多50条（自动清理）
