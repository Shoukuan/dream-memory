#!/bin/bash
# memory-score.sh — 记忆文件质量评分
# 用法: bash memory-score.sh [workspace_dir]
set -euo pipefail

WORKSPACE="${1:-$HOME/.openclaw/workspace}"
MEMORY_DIR="$WORKSPACE/memory"

echo "=== 记忆质量评分 ==="

# 用 python3 做评分（兼容性更好）
python3 << 'PYEOF'
import os, json, time, sys

workspace = os.environ.get("WORKSPACE_DIR", os.path.expanduser("~/.openclaw/workspace"))
memory_dir = os.path.join(workspace, "memory")
surfaces_file = os.path.join(memory_dir, ".surfaces.json")

# 加载已展示记录
surfaced = set()
if os.path.exists(surfaces_file):
    try:
        with open(surfaces_file) as f:
            data = json.load(f)
            if isinstance(data, list):
                surfaced = set(r.get("path", "") for r in data if isinstance(r, dict))
            elif isinstance(data, dict) and "memories" in data:
                surfaced = set(r.get("path", "") for r in data["memories"] if isinstance(r, dict))
    except:
        pass

now = time.time()
scores = []

for root, dirs, files in os.walk(memory_dir):
    for fname in files:
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(root, fname)
        rel_path = os.path.relpath(fpath, memory_dir)
        
        # 指标1: 被搜索命中次数
        hit_score = 0
        for sp in surfaced:
            if fname in sp or rel_path in sp:
                hit_score += 1
        
        # 指标2: 文件年龄
        file_mtime = os.path.getmtime(fpath)
        days_old = (now - file_mtime) / 86400
        age_score = max(0, int(90 - days_old))
        
        # 指标3: 文件大小
        file_size = os.path.getsize(fpath)
        size_score = file_size // 100
        
        total = hit_score * 3 + age_score + size_score
        
        if total < 50:
            status = "🔴 低质量"
        elif total < 100:
            status = "🟡 中等"
        else:
            status = "🟢 高质量"
        
        scores.append({
            "path": rel_path,
            "hits": hit_score,
            "age_days": int(days_old),
            "size": file_size,
            "score": total,
            "status": status
        })

# 输出
print(f"{'文件路径':<50s} {'命中':>4s} {'天数':>6s} {'大小':>6s} {'总分':>6s} {'状态':<12s}")
print("-" * 90)
for s in sorted(scores, key=lambda x: x["score"], reverse=True):
    print(f"{s['path']:<50s} {s['hits']:4d} {s['age_days']:6d} {s['size']:5d}B {s['score']:6d} {s['status']:<12s}")

print()

# 建议
low = [s for s in scores if s["score"] < 50]
star = [s for s in scores if s["score"] > 200]

if low:
    print(">> 建议归档 (低分):")
    for s in low:
        print(f"  📦 {s['path']}  (得分: {s['score']})")
else:
    print(">> 无需要归档的低分文件")

if star:
    print(">> 高质量文件 (考虑拆分专题):")
    for s in star:
        print(f"  ⭐ {s['path']}  (得分: {s['score']})")
PYEOF
