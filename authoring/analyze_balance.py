"""Summarize measured production-resolver fixtures without inventing balance results."""
import argparse
import csv
import hashlib
import json
from collections import defaultdict
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("matrix", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--source-sha", required=True)
args = parser.parse_args()
data = json.loads(args.matrix.read_text(encoding="utf-8-sig"))
rows = data["rows"]
assert len(rows) == 1536 and all("error" not in row for row in rows)
args.output.mkdir(parents=True, exist_ok=True)
columns = ["shooter", "target", "shell", "effect", "distance_m", "side", "height_m", "offset_m", "first_surface", "first_result", "damage_events", "crew_alive", "modules", "terminal"]
with (args.output / "vehicle_shell_matrix.csv").open("w", encoding="utf-8-sig", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=columns)
    writer.writeheader()
    for row in rows:
        flat = {key: row.get(key, "") for key in columns}
        first = row["contacts"][0] if row["contacts"] else {}
        flat.update(first_surface=first.get("patch", ""), first_result=first.get("result", ""), modules=";".join(row["modules"]))
        writer.writerow(flat)
groups = defaultdict(list)
pairs = defaultdict(dict)
for row in rows:
    groups[row["shell"]].append(row)
    key = tuple(row[field] for field in ["shooter", "target", "distance_m", "side", "height_m", "offset_m"])
    pairs[key][row["effect"]] = row
examples = {}
for pair in pairs.values():
    for effect, other in [("kinetic", "internal_burst"), ("internal_burst", "kinetic")]:
        if effect not in examples and pair[effect]["crew_alive"] < pair[other]["crew_alive"]:
            examples[effect] = pair
lines = ["# 四车与两弹种测量", "", f"被测源码：`{args.source_sha}`。1536 发水平入射夹具，四车互射、100/500/1000 米、四个方向、两种高度与两种横向偏移。零重力用于隔离入射位置；这不是玩家瞄准命中率或实车穿甲验证。", "", "各行混合了不同目标、距离和入射点，计数仅用于发现异常，不能当作整车胜率。", "", "| 弹种 ID | 发数 | 首层穿透 | 产生毁伤 | 内爆 |", "|---|---:|---:|---:|---:|"]
for shell, entries in sorted(groups.items()):
    penetrating = sum(bool(row["contacts"]) and row["contacts"][0]["result"] == "penetrated" for row in entries)
    lines.append(f"| {shell} | {len(entries)} | {penetrating} | {sum(row['damage_events'] > 0 for row in entries)} | {sum(row['burst'] for row in entries)} |")
lines += ["", "成对比较中，AP 造成更多乘员伤亡的采样点为 %d，APHE 为 %d。这些样本不是等概率战斗分布。" % (data["paired_crew_advantages"]["ap"], data["paired_crew_advantages"]["aphe"]), ""]
for effect, pair in examples.items():
    row = pair[effect]
    lines.append("- %s 优势示例：%s → %s，%sm，%s，高度 %sm，横向偏移 %sm；相同入射点，AP 剩余乘员 %d，APHE 剩余乘员 %d。" % ("AP" if effect == "kinetic" else "APHE", row["shooter"], row["target"], row["distance_m"], row["side"], row["height_m"], row["offset_m"], pair["kinetic"]["crew_alive"], pair["internal_burst"]["crew_alive"]))
lines += ["", "本轮未调整历史装甲、装填、炮塔转速或挑战阈值。地图/阵营优势由固定种子交换阵营比赛另行筛查；真人四车两图体验保持 PENDING。", "", "输入 JSON SHA256：`%s`。" % hashlib.sha256(args.matrix.read_bytes()).hexdigest(), ""]
(args.output / "matrix_summary.md").write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({"rows": len(rows), "pairs": len(pairs), "shells": len(groups), "paired_crew_advantages": data["paired_crew_advantages"]}))
