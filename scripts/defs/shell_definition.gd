class_name ShellDefinition
extends Resource
## 003：弹种不可变配置（可共享）。003 首版为线段弹体（即时命中），
## muzzle_velocity_mps=0 表示无飞行时间；penetration_mm 为 004 装甲/内构占位。

@export var id: String = ""
@export var schema_version: int = 1
@export var caliber_mm: float = 75.0
@export var muzzle_velocity_mps: float = 0.0
@export var penetration_mm: float = 0.0

# --- RC-001 来源与核验（003 最小入口；测试夹具显式声明无历史依据） ---
@export var source_refs: Array[String] = []
@export var verification: String = "unknown"

func validate() -> Dictionary:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("id: empty")
	if not is_finite(caliber_mm) or caliber_mm <= 0.0:
		errors.append("caliber_mm: must be finite and > 0")
	if not is_finite(muzzle_velocity_mps) or muzzle_velocity_mps < 0.0:
		errors.append("muzzle_velocity_mps: must be finite and >= 0")
	if not is_finite(penetration_mm) or penetration_mm < 0.0:
		errors.append("penetration_mm: must be finite and >= 0")
	if verification not in ["verified", "estimated", "unknown"]:
		errors.append("verification: must be verified/estimated/unknown")
	return {"ok": errors.is_empty(), "errors": errors}
