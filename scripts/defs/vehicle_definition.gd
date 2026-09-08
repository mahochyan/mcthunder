class_name VehicleDefinition
extends Resource
## 003：车辆不可变配置（可共享）。单位：速度 m/s、加速度 m/s²、角度 degree。
## 只读；加载时校验 ID 与范围；校验失败明确报错，不悄悄给默认值。

@export var id: String = ""
@export var schema_version: int = 1
@export var display_name_key: String = ""

# --- RC-001 车型身份（003 最小入口） ---
# content_tier: "test"（开发测试夹具，非历史车型）/ "research"（资料研究区）/ "production"（正式车型）
@export var content_tier: String = "test"
# source_refs: 资料来源（公开可核验史料；测试夹具必须显式声明无历史依据）
@export var source_refs: Array[String] = []
# verification: "verified"（有依据）/ "estimated"（估算，标估算）/ "unknown"（未知，不编造）
@export var verification: String = "unknown"
# 004-c：关联布局 id（us_m4a3_75w_vvss_1944 等）；空 = 无布局关联（向后兼容：旧资源缺省空串不破坏校验）
@export var layout_id: String = ""

# --- movement（m/s、m/s²、deg/s） ---
@export var forward_max_speed: float = 8.0
@export var reverse_max_speed: float = 3.0
@export var forward_accel: float = 6.0
@export var reverse_accel: float = 4.0
@export var brake_decel: float = 10.0
@export var coast_decel: float = 3.0
@export var hull_turn_speed: float = 75.0
@export var max_slope_deg: float = GameConfig.DRIVE_MAX_SLOPE_DEG
@export var drive_collision_size: Vector3 = GameConfig.DRIVE_COLLISION_SIZE
@export var drive_collision_center: Vector3 = GameConfig.DRIVE_COLLISION_CENTER
@export var follow_camera_distance: float = GameConfig.CAM_DISTANCE
@export var follow_camera_height: float = GameConfig.CAM_HEIGHT

# --- turret（deg/s、deg） ---
@export var turret_yaw_speed: float = 35.0
@export var turret_pitch_speed: float = 30.0
@export var barrel_pitch_min: float = -8.0
@export var barrel_pitch_max: float = 20.0

# --- weapon 引用 ---
@export var weapon_id: String = ""

func validate() -> Dictionary:
	# 返回 {ok: bool, errors: Array[String]}；errors 以字段名开头，便于定位
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id: empty")
	if schema_version <= 0:
		errors.append("schema_version: must be > 0")
	if not is_finite(forward_max_speed) or forward_max_speed <= 0.0:
		errors.append("forward_max_speed: must be finite and > 0")
	if not is_finite(reverse_max_speed) or reverse_max_speed < 0.0:
		errors.append("reverse_max_speed: must be finite and >= 0")
	if not is_finite(forward_accel) or forward_accel <= 0.0:
		errors.append("forward_accel: must be finite and > 0")
	if not is_finite(reverse_accel) or reverse_accel <= 0.0:
		errors.append("reverse_accel: must be finite and > 0")
	if not is_finite(brake_decel) or brake_decel <= 0.0:
		errors.append("brake_decel: must be finite and > 0")
	if not is_finite(coast_decel) or coast_decel < 0.0:
		errors.append("coast_decel: must be finite and >= 0")
	if not is_finite(hull_turn_speed) or hull_turn_speed <= 0.0:
		errors.append("hull_turn_speed: must be finite and > 0")
	if not is_finite(max_slope_deg) or max_slope_deg <= 0 or max_slope_deg >= 60:
		errors.append("max_slope_deg: must be finite between 0 and 60")
	if not drive_collision_size.is_finite() or drive_collision_size.x <= 0 or drive_collision_size.y <= 0 or drive_collision_size.z <= 0:
		errors.append("drive_collision_size: must be finite and positive")
	if not drive_collision_center.is_finite(): errors.append("drive_collision_center: must be finite")
	if not is_finite(follow_camera_distance) or follow_camera_distance <= 0: errors.append("follow_camera_distance: must be finite and positive")
	if not is_finite(follow_camera_height) or follow_camera_height < 0: errors.append("follow_camera_height: must be finite and nonnegative")
	if not is_finite(turret_yaw_speed) or turret_yaw_speed <= 0.0:
		errors.append("turret_yaw_speed: must be finite and > 0")
	if not is_finite(turret_pitch_speed) or turret_pitch_speed <= 0.0:
		errors.append("turret_pitch_speed: must be finite and > 0")
	if not is_finite(barrel_pitch_min) or not is_finite(barrel_pitch_max) or barrel_pitch_min >= barrel_pitch_max:
		errors.append("barrel_pitch: min must be < max")
	if weapon_id.is_empty():
		errors.append("weapon_id: empty")
	if content_tier not in ["test", "research", "production"]:
		errors.append("content_tier: must be test/research/production")
	if verification not in ["verified", "estimated", "unknown"]:
		errors.append("verification: must be verified/estimated/unknown")
	if content_tier == "production" and verification != "verified":
		errors.append("verification: production vehicle must be verified")
	# 003-R1：正式/已核验条目必须有实质来源（非空、非空白、非仅 TEST ONLY 声明）
	if verification == "verified":
		var has_source := false
		for s in source_refs:
			var t := s.strip_edges()
			if not t.is_empty() and "TEST ONLY" not in t:
				has_source = true
				break
		if not has_source:
			errors.append("verification: verified requires a substantive source_refs entry (not TEST ONLY)")
	return {"ok": errors.is_empty(), "errors": errors}
