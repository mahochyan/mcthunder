class_name BallisticMath
extends RefCounted
## 006：恒定加速度点弹丸运动（无空气阻力）。
## 参考实现（GPT 工作单正文附代码，107 项独立 Python 数学检查通过）；
## 本文件为 GDScript 等价接入，须本地解析并实际运行验证。
## 数值精度设定（非历史武器参数）：单段弦长 ≤5m、曲线偏差 ≤2mm、每步子段 ≤32。

const MAX_CHORD_M := 5.0
const MAX_SAG_M := 0.002
const MAX_SUBSTEPS := 32
const TIME_EPS := 1.0e-10

## 恒定加速度单子步推进：p1 = p0 + v0*h + 0.5*g*h^2；v1 = v0 + g*h。
## 返回 {ok, position, velocity} 或 {ok=false, reason}。
static func advance_free(p: Vector3, v: Vector3, a: Vector3, dt: float) -> Dictionary:
	if not p.is_finite() or not v.is_finite() or not a.is_finite():
		return {"ok": false, "reason": "non_finite_state"}
	if not is_finite(dt) or dt < 0.0:
		return {"ok": false, "reason": "invalid_dt"}

	var next_p := p + v * dt + a * (0.5 * dt * dt)
	var next_v := v + a * dt

	if not next_p.is_finite() or not next_v.is_finite():
		return {"ok": false, "reason": "state_overflow"}

	return {
		"ok": true,
		"position": next_p,
		"velocity": next_v
	}

## 规划本物理步内的子步边界（含最小速度转折点拆分）。
## 返回 {ok, times}（times 为子步边界，如 [0, h, 2h] 表示依次推进两个子步）
## 或 {ok=false, reason}（substep_budget_exceeded 等）。
static func plan_times(v: Vector3, a: Vector3, dt: float) -> Dictionary:
	if not v.is_finite() or not a.is_finite():
		return {"ok": false, "reason": "non_finite_state"}
	if not is_finite(dt) or dt <= 0.0:
		return {"ok": false, "reason": "invalid_dt"}

	var speed := v.length()
	var acc := a.length()
	var path_bound := (speed + acc * dt) * dt
	var sag_need := dt * sqrt(acc / (8.0 * MAX_SAG_M))

	var needed := maxf(
		1.0,
		maxf(path_bound / MAX_CHORD_M, sag_need)
	)

	if not is_finite(needed) or needed > float(MAX_SUBSTEPS):
		return {"ok": false, "reason": "substep_budget_exceeded"}

	var count := maxi(1, int(ceil(needed)))
	var times := PackedFloat64Array()

	for i in range(count + 1):
		times.append(dt * float(i) / float(count))

	# 在最小速度处拆分：垂直转折时防止等长端点掩盖"去而复返"的路径。
	var a2 := a.length_squared()
	if a2 > 0.0:
		var turning_t := -v.dot(a) / a2
		if turning_t > TIME_EPS and turning_t < dt - TIME_EPS:
			var exists := false
			for t in times:
				if absf(t - turning_t) <= TIME_EPS:
					exists = true
					break
			if not exists:
				times.append(turning_t)
				times.sort()

	if times.size() - 1 > MAX_SUBSTEPS:
		return {"ok": false, "reason": "substep_budget_exceeded"}

	return {"ok": true, "times": times}
