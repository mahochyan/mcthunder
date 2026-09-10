"""Summarize recorded Release measurements; never infer unmeasured acceptance."""
import argparse
import hashlib
import json
import statistics
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("evidence", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()

def read(name):
    return json.loads((args.evidence / name).read_text(encoding="utf-8-sig"))

report, result, memory, hardware = (read(name) for name in
    ("performance.json", "RESULTS.json", "process-memory.json", "hardware.json"))
if not result["passed"] or not report["complete"] or report["failed"]:
    raise SystemExit("Incomplete or failed measurements; do not generate a passing report")

def span(rows, key):
    values = [float(row[key]) for row in rows]
    return {"min": min(values), "median": statistics.median(values), "max": max(values)}

def slope(rows, key):
    x = [row["wall_seconds"] / 60 for row in rows]
    y = [row[key] / 2**20 for row in rows]
    xm, ym = statistics.mean(x), statistics.mean(y)
    denominator = sum((v - xm)**2 for v in x)
    return sum((a - xm)*(b - ym) for a, b in zip(x, y)) / denominator if denominator else None

windows = []
for start in range(0, int(memory[-1]["wall_seconds"]) + 1, 300):
    rows = [r for r in memory if start <= r["wall_seconds"] < start + 300]
    if rows:
        windows.append({"start_seconds": start, "end_seconds": min(start+300, memory[-1]["wall_seconds"]),
                        "samples": len(rows), "private_bytes": span(rows, "private_bytes"),
                        "working_set_bytes": span(rows, "working_set_bytes")})
steady = [r for r in memory if 600 <= r["wall_seconds"] < report["requested_wall_seconds"]]
resource_keys = ["live", "wrecks", "projectiles", "records", "audio_voices", "fx_active", "fires", "retained_fragment_paths"]
observed_cycles = []
for cycle in sorted({row["cycle"] for row in report["samples"]}):
    rows = [row for row in report["samples"] if row["cycle"] == cycle]
    observed_cycles.append({"cycle": cycle, "map": rows[0]["map"], "fx_level": rows[0]["fx_level"],
                            "first_sample_wall_seconds": rows[0]["wall_seconds"], "last_sample_wall_seconds": rows[-1]["wall_seconds"],
                            "last_sample_simulation_seconds": rows[-1]["seconds"], "max_sampled_accepted_shots": max(row["accepted_shots"] for row in rows)})
summary = {"source_sha": result["source_sha"], "exe_sha256": result["exe_sha256"],
           "pck_sha256": result["pck_sha256"], "wall_seconds": result["wall_seconds"],
           "checks": report["checks"], "frame_times": report["frame_times"], "groups": report["groups"],
           "lifecycle_count": len(report["lifecycle"]), "observed_cycles": observed_cycles,
           "replay_probes": report.get("replay_probes", []),
           "post_warmup_cleanup": {k: span(report["lifecycle"][4:], k) for k in ["nodes", "objects", "resources", "orphans"]},
           "memory_windows": windows, "private_mib_per_minute_after_600s": slope(steady, "private_bytes") if steady else None,
           "working_set_mib_per_minute_after_600s": slope(steady, "working_set_bytes") if steady else None,
           "observed_resource_peaks": {k: max(r[k] for r in report["samples"]) for k in resource_keys},
           "sampled_cpu_gpu_ms": {k: span(report["samples"], k) for k in ["process_ms", "physics_ms", "render_cpu_ms", "render_gpu_ms"]},
           "input_hashes": {name: hashlib.sha256((args.evidence/name).read_bytes()).hexdigest() for name in ["performance.json", "RESULTS.json", "process-memory.json", "hardware.json"]}}
args.output.mkdir(parents=True, exist_ok=True)
(args.output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
lines = ["# 最终候选性能实测数据", "", f"源码 `{result['source_sha']}`；实际证据 `{args.evidence.as_posix()}`。",
         "", f"{report['cpu']} / {report['gpu']} / {report['driver']} / {report['os_version']}；{report['resolution']}，{report['renderer']}。",
         f"墙钟 {result['wall_seconds']:.1f} 秒，{len(report['lifecycle'])} 次场景创建/退出/释放，{report['checks']} 项检查通过。后段短周期不代表完整自然比赛。",
         "", "| 采样组 | 帧数 | 平均 FPS | p95 ms | p99 ms | 最大 ms |", "|---|---:|---:|---:|---:|---:|"]
for group, values in {"all": report["frame_times"], **report["groups"]}.items():
    lines.append(f"| {group} | {values['count']} | {values['fps_from_mean']:.2f} | {values['p95_ms']:.2f} | {values['p99_ms']:.2f} | {values['max_ms']:.2f} |")
lines += ["", "各组使用不同种子和战斗阶段，不能把组间差异当作严格画质 A/B 对照。回放每次仅采样 12 帧，是功能负载探针。",
          "", "| 墙钟秒区间 | 样本数 | 私有内存中位/最大 MiB | 工作集中位/最大 MiB |", "|---|---:|---:|---:|"]
for row in windows:
    p, w = row["private_bytes"], row["working_set_bytes"]
    lines.append(f"| {row['start_seconds']}–{row['end_seconds']:.0f} | {row['samples']} | {p['median']/2**20:.1f} / {p['max']/2**20:.1f} | {w['median']/2**20:.1f} / {w['max']/2**20:.1f} |")
lines += ["", "内存来自 Windows 进程私有字节和工作集；Godot Release 的 static_memory=0 表示监视器不可用。斜率受到地图轮换、存储分配器和诊断采样缓冲影响，不能单独证明泄漏或证明无泄漏。原始两秒采样与完整生命周期保留供复查。",
          "", "## 预热四周期之后的释放状态", "", "| 项目 | 最小 | 中位 | 最大 |", "|---|---:|---:|---:|"]
for key, values in summary["post_warmup_cleanup"].items():
    lines.append(f"| {key} | {values['min']:.0f} | {values['median']:.0f} | {values['max']:.0f} |")
lines += ["", "活动预算使用真实采样峰值：", "", "```json", json.dumps(summary["observed_resource_peaks"], indent=2), "```", "",
          "本表为机器观测值，最终趋势解释和未达到 60 FPS 的场景须在 PERFORMANCE_REPORT.md 中明确。其它 GPU、分辨率与真人手感未由本表验证。", ""]
(args.output / "measurements.md").write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({k: summary[k] for k in ["checks", "wall_seconds", "lifecycle_count", "frame_times", "post_warmup_cleanup", "private_mib_per_minute_after_600s"]}))
