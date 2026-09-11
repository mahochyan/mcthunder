class_name VehicleCapabilities
extends RefCounted
## Single derivation shared by player/AI command consumers and the HUD.
static func compute(state: VehicleRuntimeState) -> Dictionary:
	var drive := true
	var propulsion := true
	var left_track := true
	var right_track := true
	var fire := true
	var turret_scale := 1.0
	var reload_rate := 1.0
	var reasons: Array[String] = []
	for id in state.module_states:
		var m: Dictionary=state.module_states[id]
		if float(m.get("integrity",0)) > 0:
			continue
		match str(m.get("kind","")):
			"engine","transmission":
				drive = false
				propulsion = false
				reasons.append(str(m.kind))
			"track":
				drive=false
				if id=="track_left": left_track=false
				elif id=="track_right": right_track=false
				else: left_track=false; right_track=false # Unknown side cannot authorize a pivot.
				reasons.append(str(id))
			"breech":
				fire = false
				reasons.append("breech")
			"turret_drive":
				turret_scale = 0.0
				reasons.append("turret_drive")
	if not state.crew_states.is_empty():
		if not state.role_available("driver"):
			drive = false
			propulsion = false
			reasons.append("driver")
		if not state.role_available("gunner"):
			fire = false
			reasons.append("gunner")
			turret_scale = 0.0
		if not state.role_available("loader"):
			reload_rate = GameConfig.DAMAGE_MISSING_LOADER_RATE
	if state.destroyed:
		drive = false
		propulsion = false
		fire = false
		turret_scale = 0
		reload_rate = 0
		reasons.append("crew_out")
	var track_pivot := propulsion and left_track!=right_track
	return {"drive":drive,"steer":drive or track_pivot,"track_pivot":track_pivot,"left_track":left_track,"right_track":right_track,"fire":fire,"turret_speed":turret_scale,
		"reload_rate":reload_rate,"reasons":reasons,"crew_alive":state.alive_crew_count()}
