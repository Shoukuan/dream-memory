#!/bin/bash
# memory-gc.sh — 完整的记忆维护流水线（每周日 02:00 执行）
# 步骤：碎片合并 → 压缩日志 → 补标签 → 周级归档 → 重建索引 → 大小检查

set -e

WORKSPACE="/Users/yibiao/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
ARCHIVE_DIR="$MEMORY_DIR/archive"
SKILL_DIR="$WORKSPACE/skills/memory-cn"

mkdir -p "$ARCHIVE_DIR"
mkdir -p "$MEMORY_DIR/archives"

echo "========================================="
echo "🧠 记忆自动维护 $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="

# ① 碎片文件合并
echo ""
echo "━━━ ① 碎片文件合并 ━━━"
python3 << 'PYEOF'
import os, glob, re
from collections import defaultdict

mem_dir = os.environ.get('MEMORY_DIR', '/Users/yibiao/.openclaw/workspace/memory')
archive_dir = os.path.join(mem_dir, 'archive')
os.makedirs(archive_dir, exist_ok=True)

files = glob.glob(os.path.join(mem_dir, "2026-*.md"))
date_files = defaultdict(list)

for f in sorted(files):
    basename = os.path.basename(f)
    m = re.match(r'(2026-\d{2}-\d{2})', basename)
    if m:
        date = m.group(1)
        date_files[date].append(basename)

merged_count = 0
for date, fnames in sorted(date_files.items()):
    if len(fnames) <= 1:
        continue
    base = f"{date}.md"
    if base in fnames:
        others = [f for f in fnames if f != base]
        if others:
            print(f"  合并 {date}: {len(others)} 个碎片 → {base}")
            for fname in others:
                src = os.path.join(mem_dir, fname)
                dst = os.path.join(archive_dir, fname)
                if os.path.exists(src):
                    with open(src) as fh:
                        content = fh.read()
                    with open(os.path.join(mem_dir, base), 'a') as fh:
                        fh.write(f"\n\n--- ({fname} 合并) ---\n\n{content}")
                    os.rename(src, dst)
                    merged_count += 1

print(f"  合并完成：{merged_count} 个文件")
PYEOF

# ② 压缩日志
echo ""
echo "━━━ ② 压缩旧日志 ━━━"
python3 "$SKILL_DIR/compress-logs.py" "$MEMORY_DIR" --max-kb 5

# ③ 补标签
echo ""
echo "━━━ ③ 补标签 ━━━"
python3 "$SKILL_DIR/add-tags.py" "$MEMORY_DIR"

# ④ 周级归档
echo ""
echo "━━━ ④ 周级归档 ━━━"
python3 << 'PYEOF'
import os, glob, re
from datetime import datetime, timedelta

mem_dir = os.environ.get('MEMORY_DIR', '/Users/yibiao/.openclaw/workspace/memory')
archives_dir = os.path.join(mem_dir, 'archives')
archive_dir = os.path.join(mem_dir, 'archive')
os.makedirs(archives_dir, exist_ok=True)
os.makedirs(archive_dir, exist_ok=True)

cutoff = datetime.now() - timedelta(days=7)
daily_files = sorted(glob.glob(os.path.join(mem_dir, "2026-*-*.md")))

weeks = {}
for f in daily_files:
    basename = os.path.basename(f)
    m = re.match(r'(2026)-(\d{2})-(\d{2})', basename)
    if not m:
        continue
    date_str = m.group(0)
    try:
        file_date = datetime.strptime(date_str, '%Y-%m-%d')
    except:
        continue
    if file_date >= cutoff:
        continue  # 最近 7 天保留
    week_num = file_date.isocalendar()[1]
    week_key = f"{m.group(1)}-W{week_num}"
    if week_key not in weeks:
        weeks[week_key] = []
    weeks[week_key].append((basename, os.path.getsize(f)))

for week_key, file_list in sorted(weeks.items()):
    archive_file = os.path.join(archives_dir, f"{week_key}.md")
    total_size = sum(s for _, s in file_list)
    print(f"  归档 {week_key}: {len(file_list)} 个文件, {total_size//1024}KB")
    with open(archive_file, 'a') as out:
        for fname, size in file_list:
            src = os.path.join(mem_dir, fname)
            if os.path.exists(src):
                with open(src) as inp:
                    content = inp.read()
                out.write(f"\n\n## {fname}\n\n{content}\n")
                os.rename(src, os.path.join(archive_dir, fname))

print("  归档完成")
PYEOF

# ⑤ 重建索引
echo ""
echo "━━━ ⑤ 重建索引 ━━━"
openclaw memory index --force 2>&1
echo "  ✅ 索引重建完成"

# ⑥ 大小检查
echo ""
echo "━━━ ⑥ 大小检查 ━━━"
MEMORY_FILE="$WORKSPACE/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    mem_size=$(stat -f%z "$MEMORY_FILE" 2>/dev/null || stat -c%s "$MEMORY_FILE")
    if [ "$mem_size" -gt 4096 ]; then
        echo "  ⚠️  MEMORY.md 超过 4KB (${mem_size} bytes)，建议手动修剪"
    else
        echo "  ✅ MEMORY.md: ${mem_size} bytes (OK)"
    fi
fi

total_size=$(du -sh "$MEMORY_DIR" 2>/dev/null | cut -f1)
file_count=$(find "$MEMORY_DIR" -name "*.md" -not -path "*/archive/*" -not -path "*/archives/*" | wc -l | tr -d ' ')
echo "  总文件数: ${file_count}"
echo "  memory/ 大小: ${total_size}"

# ⑦ 写报告
echo ""
echo "━━━ ⑦ 写维护报告 ━━━"
cat << REPORT > "$MEMORY_DIR/gc-report.md"
# 记忆维护报告

**执行时间:** $(date '+%Y-%m-%d %H:%M:%S')
**MEMORY.md 大小:** $(stat -f%z "$MEMORY_FILE" 2>/dev/null || echo "N/A") bytes
**记忆文件数:** ${file_count}
**memory/ 大小:** ${total_size}
**状态:** ✅ 完成
REPORT
echo "  ✅ 报告已写入 memory/gc-report.md"

echo ""
echo "========================================="
echo "✅ 记忆维护完成"
echo "========================================="
