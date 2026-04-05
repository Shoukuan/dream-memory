#!/bin/bash
# memory-selector.sh — 轻量选择器辅助脚本
# 用法:
#   bash memory-selector.sh record "memory/topics/goals.md"      # 记录已展示
#   bash memory-selector.sh list                                 # 列出最近记录
#   bash memory-selector.sh clean                                # 清理旧记录（保留30条）
#   bash memory-selector.sh filter "file1.txt file2.txt"         # 过滤掉已展示的文件

SURFACES_FILE="${1%/*}/.surfaces.json" || "~/.openclaw/workspace/memory/.surfaces.json"
SURFACES_FILE="$HOME/.openclaw/workspace/memory/.surfaces.json"
MAX_RECORDS=30
KEEP_RECORDS=20

action="$1"
shift

case "$action" in
  record)
    # 记录新文件
    FILE_PATH="$1"
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S+00:00")
    # 追加记录
    if [ -f "$SURFACES_FILE" ] && [ -s "$SURFACES_FILE" ]; then
      # 追加到 JSON 数组
      python3 -c "
import json
with open('$SURFACES_FILE') as f:
    data = json.load(f)
data.append({'path': '$FILE_PATH', 'at': '$NOW'})
# 保留最近 30 条
if len(data) > $MAX_RECORDS:
    data = data[-$MAX_RECORDS:]
with open('$SURFACES_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
    else
      echo "[{\"path\": \"$FILE_PATH\", \"at\": \"$NOW\"}]" > "$SURFACES_FILE"
    fi
    echo "✅ 已记录: $FILE_PATH"
    ;;
    
  list)
    if [ -f "$SURFACES_FILE" ] && [ -s "$SURFACES_FILE" ]; then
      python3 -c "
import json
with open('$SURFACES_FILE') as f:
    data = json.load(f)
print(f'已展示记录: {len(data)} 条')
for r in data[-10:]:
    print(f'  {r[\"path\"]} ({r[\"at\"]})')
"
    else
      echo "无记录"
    fi
    ;;
    
  clean)
    if [ -f "$SURFACES_FILE" ] && [ -s "$SURFACES_FILE" ]; then
      python3 -c "
import json
with open('$SURFACES_FILE') as f:
    data = json.load(f)
if len(data) > $MAX_RECORDS:
    data = data[-$KEEP_RECORDS:]
    with open('$SURFACES_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print(f'✅ 清理: {len(data)} 条记录')
else:
    print('无需清理')
"
    fi
    ;;
    
  filter)
    # 过滤掉已展示的文件（通过 stdin 传入候选列表）
    python3 -c "
import json, sys
try:
    with open('$SURFACES_FILE') as f:
        surfaced = json.load(f)
    surfaced_paths = set(r['path'] for r in surfaced[-$MAX_RECORDS:])
except:
    surfaced_paths = set()

candidates = sys.stdin.read().strip().split('\\n')
filtered = [c for c in candidates if c and c not in surfaced_paths]
if filtered:
    print('FILTERED_RESULTS:')
    for f in filtered[:5]:  # 最多返回5条
        print(f)
else:
    print('NO_NEW_RESULTS')
"
    ;;
    
  *)
    echo "用法: memory-selector.sh {record|list|clean|filter}"
    echo "示例:"
    echo "  memory-selector.sh record memory/topics/goals.md"
    echo "  memory-selector.sh list"
    echo "  memory-selector.sh clean"
    echo "  echo 'file1\nfile2' | memory-selector.sh filter"
    ;;
esac
