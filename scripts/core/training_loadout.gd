class_name TrainingLoadout
extends RefCounted
const SHELLS := {"ap70":70.0,"ap120":120.0}

static func validate(value: Dictionary) -> Dictionary:
	if value.get("vehicle_id","") != "test_vehicle": return {"ok":false,"reason":"请选择可用的工程测试车"}
	if not SHELLS.has(value.get("shell_id","")): return {"ok":false,"reason":"弹种不可用"}
	var rounds: Variant = value.get("rounds")
	if not rounds is int or rounds < 1 or rounds > 30: return {"ok":false,"reason":"携弹量必须为1至30发"}
	if not value.get("infinite") is bool: return {"ok":false,"reason":"训练补给设置无效"}
	return {"ok":true,"loadout":value.duplicate(true)}

static func apply(vehicle: VehicleActor, value: Dictionary) -> Dictionary:
	var checked := validate(value)
	if not checked.ok: return checked
	vehicle.gunner.shell = vehicle.gunner.shell.duplicate(true)
	vehicle.gunner.shell.id = "training_"+value.shell_id
	vehicle.gunner.shell.armor_policy = "resolve"
	var penetration: float = SHELLS[value.shell_id]
	vehicle.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,penetration),Vector2(200,penetration)])
	vehicle.gunner.rounds_remaining = value.rounds
	vehicle.gunner.training_resupply = value.infinite
	return {"ok":true}
