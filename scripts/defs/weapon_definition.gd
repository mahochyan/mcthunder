class_name WeaponDefinition
extends Resource
## 003：武器不可变配置（可共享）。reload_time s、gun_range m、角度 degree。
## 006：gun_range 本轮明确作为累计分段路程上限（模拟折线长度近似，非直线距离）；
## initial_rounds = 单武器初始弹数（测试配额，非历史携弹量；配置可共享，剩余弹数不共享）。

@export var id: String = ""
@export var schema_version: int = 1
@export var shell_id: String = ""
@export var reload_time: float = 2.0
@export var gun_range: float = 200.0
@export var barrel_pitch_min: float = -8.0
@export var barrel_pitch_max: float = 20.0
@export var initial_rounds: int = 30   # 006：单武器初始弹数（测试配额）

# --- RC-001 来源与核验（003 最小入口；测试夹具显式声明无历史依据） ---
@export var source_refs: Array[String] = []
@export var verification: String = "unknown"

func validate() -> Dictionary:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id: empty")
	if shell_id.is_empty():
		errors.append("shell_id: empty")
	if not is_finite(reload_time) or reload_time <= 0.0:
		errors.append("reload_time: must be finite and > 0")
	if not is_finite(gun_range) or gun_range <= 0.0:
		errors.append("gun_range: must be finite and > 0")
	if initial_rounds <= 0:
		errors.append("initial_rounds: must be > 0")
	if not is_finite(barrel_pitch_min) or not is_finite(barrel_pitch_max) or barrel_pitch_min >= barrel_pitch_max:
		errors.append("barrel_pitch: min must be < max")
	if verification not in ["verified", "estimated", "unknown"]:
		errors.append("verification: must be verified/estimated/unknown")
	return {"ok": errors.is_empty(), "errors": errors}
