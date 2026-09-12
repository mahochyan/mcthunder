class_name VehicleCapabilities
extends RefCounted
## Single derivation shared by player/AI command consumers and the HUD.
static func compute(state: VehicleRuntimeState, loading_profile: LoadingProfile = null) -> Dictionary:
	var drive := true
	var propulsion := true
	var left_track := true
	var right_track := true
	var fire := true
	var turret_scale := 1.0
	var yaw_scale := 1.0
	var pitch_scale := 1.0
	var stabilizer_available := true
	var reload_rate := 1.0
	var reasons: Array[String] = []
	for id in state.module_states:
		var m: Dictionary=state.module_states[id]
		var fraction := clampf(float(m.get("integrity",0))/maxf(0.0001,float(m.get("max_integrity",1))),0,1)
		if m.get("kind")=="turret_horizontal_drive": yaw_scale=minf(yaw_scale,fraction)
		if m.get("kind")=="turret_vertical_drive": pitch_scale=minf(pitch_scale,fraction)
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
			"turret_horizontal_drive","turret_vertical_drive":
				reasons.append(str(m.kind))
			"stabilizer":
				stabilizer_available=false
				reasons.append("stabilizer")
	if not state.crew_states.is_empty():
		if not state.role_available("driver"):
			drive = false
			propulsion = false
			reasons.append("driver")
		if not state.role_available("gunner"):
			fire = false
			reasons.append("gunner")
			turret_scale = 0.0
	if state.destroyed:
		drive = false
		propulsion = false
		fire = false
		turret_scale = 0
		reload_rate = 0
		reasons.append("crew_out")
	var track_pivot := propulsion and left_track!=right_track
	yaw_scale*=turret_scale; pitch_scale*=turret_scale
	stabilizer_available=stabilizer_available and turret_scale>0 and not state.destroyed
	var loading := LoadingRules.compute(loading_profile,state)
	reload_rate=float(loading.reload_rate)
	var result := {"drive":drive,"steer":drive or track_pivot,"track_pivot":track_pivot,"left_track":left_track,"right_track":right_track,"fire":fire,"turret_speed":turret_scale,
		"yaw_scale":yaw_scale,"pitch_scale":pitch_scale,"stabilizer_available":stabilizer_available,
		"reload_rate":reload_rate,"reasons":reasons,"crew_alive":state.alive_crew_count()}
	result.merge(loading,true)
	return result
