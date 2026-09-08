class_name VehicleCapabilities
extends RefCounted
## Single derivation shared by player/AI command consumers and the HUD.
static func compute(state: VehicleRuntimeState) -> Dictionary:
	var drive := true
	var fire := true
	var turret_scale := 1.0
	var reload_rate := 1.0
	var reasons: Array[String] = []
	for m in state.module_states.values():
		if float(m.get("integrity",0)) > 0:
			continue
		match str(m.get("kind","")):
			"engine","transmission","track":
				drive = false
				reasons.append(str(m.kind))
			"breech":
				fire = false
				reasons.append("breech")
			"turret_drive":
				turret_scale = 0.0
				reasons.append("turret_drive")
	if not state.crew_states.is_empty():
		if not state.role_available("driver"):
			drive = false
			reasons.append("driver")
		if not state.role_available("gunner"):
			fire = false
			reasons.append("gunner")
			turret_scale = 0.0
		if not state.role_available("loader"):
			reload_rate = GameConfig.DAMAGE_MISSING_LOADER_RATE
	if state.destroyed:
		drive = false
		fire = false
		turret_scale = 0
		reload_rate = 0
		reasons.append("crew_out")
	return {"drive":drive,"steer":drive,"fire":fire,"turret_speed":turret_scale,
		"reload_rate":reload_rate,"reasons":reasons,"crew_alive":state.alive_crew_count()}
