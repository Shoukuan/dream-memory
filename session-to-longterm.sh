#!/bin/bash
# session-to-longterm.sh — Session 摘要自动晋升到长期记忆
# 用法: bash session-to-longterm.sh [workspace_dir]
set -e

WORKSPACE="${1:-$HOME/.openclaw/workspace}"
MEMORY_DIR="$WORKSPACE/memory"
TOPICS_DIR="$MEMORY_DIR/topics"
MEMORY_INDEX="$WORKSPACE/MEMORY.md"

echo "=== Session → 长期晋升检查 ==="

# Step 1: 扫描所有日志中的重复主题
# 同类型信息出现 ≥3 次才值得长期化
PROMOTION_THRESHOLD=3
TEMP_FILE="$MEMORY_DIR/.promotion-check.tmp"

# 提取所有日志中的关键词频次
KEYWORDS=("修复" "优化" "配置" "教训" "决策" "发现" "规则" "工具")
> "$TEMP_FILE"
for keyword in "${KEYWORDS[@]}"; do
  if [ -d "$MEMORY_DIR" ]; then
    COUNT=$(grep -rl "$keyword" "$MEMORY_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COUNT" -ge "$PROMOTION_THRESHOLD" ]; then
      echo "$keyword:$COUNT" >> "$TEMP_FILE"
    fi
  fi
done

# Step 2: 输出建议（不自动写，需要 Agent 确认）
if [ -s "$TEMP_FILE" ]; then
  echo ">> 以下主题值得长期化（出现 $PROMOTION_THRESHOLD+ 次）:"
  while IFS=: read -r topic count; do
    echo "  📌 $topic: 出现 $count 次"
  done < "$TEMP_FILE"
  
  echo ""
  echo "建议操作："
  while IFS=: read -r topic count; do
    TOPIC_FILE="$TOPICS_DIR/${topic}-summary.md"
    if [ ! -f "$TOPIC_FILE" ]; then
      echo "  → 创建: $TOPIC_FILE（汇总 $count 次相关记录）"
    else
      echo "  → 更新: $TOPIC_FILE（追加新记录）"
    fi
  done < "$TEMP_FILE"
else
  echo "▶️ 无值得晋升的主题"
fi
rm -f "$TEMP_FILE"

# Step 3: 检查是否有未归档的旧日志需要清理
echo ""
echo ">> 归档检查..."
OLD_COUNT=0
if [ -d "$MEMORY_DIR" ]; then
  while IFS= read -r file; do
    # 超过 30 天的日志
    FILE_DATE=$(basename "$file" .md)
    FILE_TS=$(date -j -f "%Y-%m-%d" "$FILE_DATE" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DAYS_OLD=$(( (NOW_TS - FILE_TS) / 86400 ))
    
    if [ "$DAYS_OLD" -gt 30 ]; then
      echo "  📦 $FILE_DATE ($DAYS_OLD 天) → 建议归档"
      OLD_COUNT=$((OLD_COUNT + 1))
    fi
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name "2026-03-*.md" -o -name "2026-02-*.md" 2>/dev/null)
fi

if [ "$OLD_COUNT" -eq 0 ]; then
  echo "  ✅ 无需要归档的日志"
fi

echo ""
echo "=== 晋升检查完成 ==="
