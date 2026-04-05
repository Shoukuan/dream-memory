#!/bin/bash
# session-summary.sh - 从当天会话中提取关键信息写入日志
# 用法: bash session-summary.sh [workspace]
set -euo pipefail

WORKSPACE="${1:-$HOME/.openclaw/workspace}"
TODAY=$(date '+%Y-%m-%d')
DAILY_NOTE="$WORKSPACE/memory/$TODAY.md"
SESSION_DIR="$HOME/.openclaw/agents/main/sessions"
SURFACES="$WORKSPACE/memory/.surfaces.json"

echo "=== Session 自动提取 ($TODAY) ==="

# 1. 找最近的会话
LATEST_SESSION=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | \
  grep -v '.reset.' | head -1)

if [ -z "$LATEST_SESSION" ] || [ ! -s "$LATEST_SESSION" ]; then
  echo "ℹ️ 无活跃会话，跳过"
  exit 0
fi

SESSION_NAME=$(basename "$LATEST_SESSION" .jsonl)

# 2. 提取 assistant 关键操作（从最后 100 行）
ACTIONS=$(tail -100 "$LATEST_SESSION" | \
  jq -r 'select(.role == "assistant" and .content != null) | 
    .content[:200] | select(length > 30)' 2>/dev/null | head -3)

if [ -z "$ACTIONS" ]; then
  echo "ℹ️ 最近无有效内容"
  exit 0
fi

# 3. 追加到日志
mkdir -p "$WORKSPACE/memory"
echo "" >> "$DAILY_NOTE"
echo "## 自动提取 $(date '+%H:%M')" >> "$DAILY_NOTE"
echo "来源: 会话 $SESSION_NAME" >> "$DAILY_NOTE"
echo "" >> "$DAILY_NOTE"

# 4. 记录 surfaces
if [ -f "$SURFACES" ]; then
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')]" >> "$SURFACES"
fi

echo "✅ 已提取 $SESSION_NAME 的关键操作到日志"
echo "=== 完成 ==="
