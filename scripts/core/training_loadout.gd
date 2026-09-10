class_name TrainingLoadout
extends RefCounted
const SHELLS := {"ap70":70.0,"ap120":120.0}

static func validate(value: Dictionary) -> Dictionary:
	if value.get("vehicle_id","") != "test_vehicle": return {"ok":false,"reason":LocalizationService.text("ui_96602d1248bc")}
	if not SHELLS.has(value.get("shell_id","")): return {"ok":false,"reason":LocalizationService.text("ui_6d8f21a11885")}
	var rounds: Variant = value.get("rounds")
	if not rounds is int or rounds < 1 or rounds > 30: return {"ok":false,"reason":LocalizationService.text("ui_ec430569133a")}
	if not value.get("infinite") is bool: return {"ok":false,"reason":LocalizationService.text("ui_ce01cbdfa8c6")}
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
