class_name PreviewCameraMath
extends RefCounted

# 004-R2-A：相机轨道求解——俯仰下限随目标高度/距离/最低相机高度动态计算。
# 单一入口：拖动、滚轮缩放、恢复视图、切换模型都经 solve_orbit()，
# 不在滚轮回调里另写一套高度修正。纯计算，不依赖场景树。

const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 30.0
const MAX_PITCH_DEG := 80.0
const ABS_MIN_PITCH_DEG := -75.0


static func solve_orbit(
		focus: Vector3,
		yaw_deg: float,
		requested_pitch_deg: float,
		requested_distance: float,
		min_camera_y: float
	) -> Dictionary:

	if not focus.is_finite():
		return {"ok": false, "error": "non-finite focus"}

	for value in [
		yaw_deg,
		requested_pitch_deg,
		requested_distance,
		min_camera_y
	]:
		if not is_finite(value):
			return {"ok": false, "error": "non-finite orbit input"}

	var distance := clampf(requested_distance, MIN_DISTANCE, MAX_DISTANCE)

	# 即使抬到最大允许角度仍低于安全高度，则明确报告不可行。
	if focus.y + distance * sin(deg_to_rad(MAX_PITCH_DEG)) < min_camera_y:
		return {"ok": false, "error": "no feasible above-ground orbit"}

	var required_sine := (min_camera_y - focus.y) / distance
	var floor_pitch_deg := rad_to_deg(
		asin(clampf(required_sine, -1.0, 1.0))
	)

	var min_pitch_deg := maxf(ABS_MIN_PITCH_DEG, floor_pitch_deg)
	var applied_pitch_deg := clampf(
		requested_pitch_deg,
		min_pitch_deg,
		MAX_PITCH_DEG
	)

	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(applied_pitch_deg)

	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance

	return {
		"ok": true,
		"position": focus + offset,
		"pitch_deg": applied_pitch_deg,
		"distance": distance
	}