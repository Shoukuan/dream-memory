#!/bin/bash
# 记忆蒸馏脚本 — MEMORY.md 截断 + 索引完整性检查
# 用法: bash memory-distill.sh [workspace_dir]
set -e

WORKSPACE="${1:-$HOME/.openclaw/workspace}"
MEMORY_INDEX="$WORKSPACE/MEMORY.md"

MAX_LINES=200
MAX_BYTES=25000

echo "=== 记忆蒸馏 $(date '+%Y-%m-%d %H:%M') ==="

# Step 1: MEMORY.md 截断保护
if [ -f "$MEMORY_INDEX" ]; then
  LINES=$(wc -l < "$MEMORY_INDEX" | tr -d ' ')
  BYTES=$(wc -c < "$MEMORY_INDEX" | tr -d ' ')
  if [ "$LINES" -gt "$MAX_LINES" ] || [ "$BYTES" -gt "$MAX_BYTES" ]; then
    echo "⚠️ MEMORY.md 超限: ${LINES}行 / ${BYTES}B → 截断到 ${MAX_LINES}行"
    head -n "$MAX_LINES" "$MEMORY_INDEX" > "${MEMORY_INDEX}.tmp" && mv "${MEMORY_INDEX}.tmp" "$MEMORY_INDEX"
  else
    echo "✅ MEMORY.md 正常: ${LINES}行 / ${BYTES}B"
  fi
fi

# Step 2: 索引完整性检查 — 用纯 bash 避免 sed 跨平台问题
INVALID=0
if [ -f "$MEMORY_INDEX" ]; then
  # 用 grep 提取 [](path) 格式链接，用 bash 字符串操作代替 sed
  while IFS= read -r line; do
    # 提取括号内的路径
    PATH_PART="${line#*\(}"
    FILE_PATH="${PATH_PART%\)*}"
    FULL_PATH="$WORKSPACE/$FILE_PATH"
    if [ -n "$FILE_PATH" ] && [ ! -f "$FULL_PATH" ]; then
      echo "⚠️ 索引指向的文件不存在: $FILE_PATH"
      INVALID=$((INVALID + 1))
    fi
  done < <(grep -oE '\]\([^)]*\)' "$MEMORY_INDEX" | grep -o '[^()]*$' || true)
fi
if [ "$INVALID" -eq 0 ]; then
  echo "✅ 索引完整性: 0 失效链接"
else
  echo "⚠️ 索引完整性: $INVALID 个失效链接"
fi

# Step 3: 锁文件更新
touch "$WORKSPACE/.consolidate-lock"
echo "✅ 锁文件更新时间: $(stat -f %m "$WORKSPACE/.consolidate-lock")"
echo "=== 蒸馏完成 ==="
