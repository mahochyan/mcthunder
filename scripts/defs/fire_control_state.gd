class_name FireControlState
extends RefCounted
## Fixed-step authority state. Measured range never arrives in an input command.
const VERSION := 1
const STATUSES := ["idle","measuring","measured","failed","expired"]
var status := "idle"
var reason := ""
var measured_range_m := 0.0
var measurement_left_s := 0.0
var measurement_duration_s := 0.0
var valid_left_s := 0.0
var zeroing_m := 0.0
var solution_ok := true
var solution_reason := "direct"
var _measurement_ray: Dictionary = {}
var _measurement_mode := ""

func reset() -> void:
	status="idle"; reason=""; measured_range_m=0; measurement_left_s=0
	measurement_duration_s=0; valid_left_s=0; zeroing_m=0
	solution_ok=true; solution_reason="direct"; _measurement_ray.clear(); _measurement_mode=""

func cancel_measurement(why: String) -> void:
	if status!="measuring": return
	status="failed"; reason=why; measurement_left_s=0; _measurement_ray.clear()

func snapshot() -> Dictionary:
	return {"version":VERSION,"status":status,"reason":reason,"measured_range_m":measured_range_m,
		"measurement_left_s":measurement_left_s,"measurement_duration_s":measurement_duration_s,
		"valid_left_s":valid_left_s,"zeroing_m":zeroing_m,"solution_ok":solution_ok,"solution_reason":solution_reason}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=10: return false
	if not VehicleCommandCodec.integer(value.get("version")) or value.version!=VERSION: return false
	if value.get("status") not in STATUSES or not value.get("solution_ok") is bool: return false
	for key in ["reason","solution_reason"]:
		if not value.get(key) is String or value[key].length()>96: return false
	for key in ["measured_range_m","measurement_left_s","measurement_duration_s","valid_left_s","zeroing_m"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])) or float(value[key])<0 or float(value[key])>10000: return false
	if value.measurement_left_s>value.measurement_duration_s: return false
	if value.status=="measured" and (value.measured_range_m<=0 or value.valid_left_s<=0): return false
	if value.status=="measuring" and value.measurement_left_s<=0: return false
	return true

func apply_snapshot(value: Variant) -> bool:
	if not valid_snapshot(value): return false
	for key in value:
		if key!="version": set(key,value[key])
	_measurement_ray.clear()
	return true

func advance(actor: VehicleActor, cmd: VehicleCommand, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	if actor.state.destroyed:
		reset(); return
	var profile := actor.definition.optics_profile
	var intent := cmd.aim_intent
	valid_left_s=maxf(0,valid_left_s-delta)
	if status=="measured" and valid_left_s<=0: status="expired"; reason="expired"
	if cmd.zeroing_steps!=0:
		zeroing_m=clampf(zeroing_m+cmd.zeroing_steps*profile.zeroing_step_m,0,minf(profile.zeroing_max_m,actor.weapon.gun_range))
	if zeroing_m<=0: solution_ok=true; solution_reason="direct"
	if cmd.apply_range_requested:
		if status=="measured" and valid_left_s>0:
			zeroing_m=clampf(measured_range_m,0,minf(profile.zeroing_max_m,actor.weapon.gun_range)); reason="applied"
		else: reason="no_measurement"
	var eligible := intent!=null and intent.active and intent.mode in ["sight","binocular"]
	if not actor.state.crew_states.is_empty():
		eligible=eligible and actor.state.role_available("commander" if intent!=null and intent.mode=="binocular" else "gunner")
	if status=="measuring":
		if not eligible or intent.mode!=_measurement_mode:
			cancel_measurement("observation_changed")
		else:
			var ray := actor.cam_rig.optical_ray()
			if ray.origin.distance_to(_measurement_ray.origin)>0.75 or ray.direction.angle_to(_measurement_ray.direction)>deg_to_rad(0.75):
				cancel_measurement("aim_moved")
			else:
				measurement_left_s=maxf(0,measurement_left_s-delta)
				if measurement_left_s<=0:
					var contact := actor.cam_rig.measure_contact(profile.rangefinder_max_m)
					if contact.get("ok",false) and contact.distance_m>=profile.rangefinder_min_m:
						measured_range_m=clampf(roundf(float(contact.distance_m)/profile.rangefinder_resolution_m)*profile.rangefinder_resolution_m,profile.rangefinder_min_m,profile.rangefinder_max_m)
						status="measured"; reason="estimated"; valid_left_s=profile.measurement_valid_s
					else: status="failed"; reason=str(contact.get("reason","too_close")); measured_range_m=0
	if cmd.range_requested and status!="measuring":
		if not eligible:
			status="failed"; reason="sight_required"; measured_range_m=0; valid_left_s=0
		else:
			status="measuring"; reason=""; measured_range_m=0; valid_left_s=0
			measurement_duration_s=profile.measurement_time_s; measurement_left_s=measurement_duration_s
			_measurement_ray=actor.cam_rig.optical_ray(); _measurement_mode=intent.mode

func aim_solution(actor: VehicleActor) -> Dictionary:
	solution_ok=true; solution_reason="direct"
	if zeroing_m<=0: return {}
	var ray := actor.cam_rig.optical_ray()
	var target: Vector3=ray.origin+ray.direction*zeroing_m
	var solution := SightBallistics.solve(actor.turret.muzzle.global_position,target,actor.gunner.shell)
	solution_ok=solution.ok; solution_reason=solution.reason
	return solution

func hud_text() -> String:
	var range_text := LocalizationService.text("range_status_"+status)
	if status=="measuring": range_text+=" %.1fs"%measurement_left_s
	if status in ["measured","expired"]: range_text+=" %dm"%roundi(measured_range_m)
	if status=="failed": range_text+=" · "+LocalizationService.text("range_reason_"+reason)
	var result := range_text+" · "+LocalizationService.text("range_zeroing")%roundi(zeroing_m)
	if not solution_ok: result+=" · "+LocalizationService.text("range_solution_unavailable")
	return result
