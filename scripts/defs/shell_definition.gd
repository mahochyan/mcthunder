class_name ShellDefinition
extends Resource
## 003：弹种不可变配置（可共享）。003 首版为线段弹体（即时命中），
## muzzle_velocity_mps=0 表示无飞行时间；penetration_mm 为 004 装甲/内构占位。
## 006：零初速占位约定取消——运行弹种必须 muzzle_velocity_mps>0（有限速度炮弹）；
## 新增 gravity_scale（重力倍率）与 max_flight_time_s（最大飞行时间，模拟时间）。

@export var id: String = ""
@export var schema_version: int = 1
@export var caliber_mm: float = 75.0
@export var muzzle_velocity_mps: float = 0.0
@export var penetration_mm: float = 0.0
@export var armor_policy: String = "resolve"
@export var penetration_curve: PackedVector2Array = PackedVector2Array([Vector2(0, 60), Vector2(200, 50)])
@export var gravity_scale: float = 1.0      # 006：重力倍率（0 = 无重力弹道）
@export var max_flight_time_s: float = 8.0  # 006：最大飞行时间（模拟时间，>0）

# --- RC-001 来源与核验（003 最小入口；测试夹具显式声明无历史依据） ---
@export var source_refs: Array[String] = []
@export var verification: String = "unknown"

func validate() -> Dictionary:
	var errors: Array[String] = []
	if armor_policy not in ["resolve", "legacy_contact_only"]:
		errors.append("armor_policy: unsupported")
	if armor_policy == "resolve" and not PenetrationCurve.validate(penetration_curve):
		errors.append("penetration_curve: invalid distance/penetration points")
	if armor_policy == "legacy_contact_only" and not "TEST ONLY" in str(source_refs):
		errors.append("legacy_contact_only: only permitted on explicit TEST ONLY fixtures")
	if id.is_empty():
		errors.append("id: empty")
	if not is_finite(caliber_mm) or caliber_mm <= 0.0:
		errors.append("caliber_mm: must be finite and > 0")
	if not is_finite(muzzle_velocity_mps) or muzzle_velocity_mps <= 0.0:
		errors.append("muzzle_velocity_mps: must be finite and > 0 (006: zero-velocity instant-hit placeholder removed)")
	if not is_finite(gravity_scale) or gravity_scale < 0.0:
		errors.append("gravity_scale: must be finite and >= 0")
	if not is_finite(max_flight_time_s) or max_flight_time_s <= 0.0:
		errors.append("max_flight_time_s: must be finite and > 0")
	if not is_finite(penetration_mm) or penetration_mm < 0.0:
		errors.append("penetration_mm: must be finite and >= 0")
	if verification not in ["verified", "estimated", "unknown"]:
		errors.append("verification: must be verified/estimated/unknown")
	return {"ok": errors.is_empty(), "errors": errors}
