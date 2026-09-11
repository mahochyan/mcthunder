class_name TrafficTelemetry
extends RefCounted
# Read-only AI mobility telemetry (audit 001-026, stabilisation step 2).
# Never mutates vehicles, commands or rules; it only samples and reports so the
# fix work can compare "before/after" and attribute WHY a healthy AI stalls.
# Per GPT ruling: legitimate holds (combat/recovery/arrival) and immobile damage
# states are NOT congestion; throttle==0 alone never proves intent to advance.

const MOVE_EPS := 0.6        # m/s below which the vehicle is not making progress
const WAIT_START_S := 2.0    # sustained stall before an episode is opened
const GOAL_HOLD_M := 2.0     # distance at which the goal counts as held/arrived
const EVIDENCE_SLOTS := 10
const MAX_EVIDENCE_BYTES := 2*1024*1024

static func match_evidence_path(match_id: int, folder: String = "user://diagnostics/traffic") -> String:
	return folder.path_join("match_%02d.json"%posmod(match_id,EVIDENCE_SLOTS))

var clock := 0.0
var records: Dictionary = {}   # "entity:life" -> {episodes, longest_s, total_s, ...}
var active: Dictionary = {}    # key -> {t0, driver_phase, ...} current stall episode
var planning: Dictionary = {"failed":0,"unreachable":0,"replanned":0}
var _planning_seen: Dictionary = {} # Driver instance, independent of vehicle respawn.

func step(vehicles: Array, delta: float) -> void:
	clock += delta
	var seen: Dictionary = {}
	for vehicle in vehicles:
		if vehicle.controller == null or not (vehicle.controller is AITankController): continue
		var ai: AITankController = vehicle.controller
		var drv := ai.driver
		var key := "%s:%d" % [vehicle.entity_id, vehicle.life_id]
		seen[key] = true
		var rec: Dictionary = records.get(key, {})
		if rec.is_empty():
			rec = {"team":vehicle.state.team_id,"episodes":[],"longest_s":0.0,"total_s":0.0,"holds":{}}
			records[key] = rec
		# GPT fix (a): planning counters come from real planning-request outcomes in
		# cumulative driver counters, independent of its bounded event history.
		var driver_key := drv.get_instance_id()
		var prior: Dictionary = _planning_seen.get(driver_key,{})
		for kind in drv.planning_counts:
			var count := int(drv.planning_counts[kind])
			planning[kind] += maxi(0,count-int(prior.get(kind,0)))
			prior[kind] = count
		_planning_seen[driver_key] = prior
		if vehicle.state.destroyed:
			_close(key,"destroyed")
			continue
		var caps: Dictionary = vehicle.capabilities()
		var speed: float = vehicle.tank.velocity.length()
		var goal_dist: float = INF
		if drv.has_goal: goal_dist = vehicle.tank.global_position.distance_to(drv.goal)
		var patrol_dist := INF
		if ai.has_patrol: patrol_dist = vehicle.tank.global_position.distance_to(ai.patrol_goal)
		# --- legitimate holds per TASK POLICY, not phase names (GPT fix (b)) ---
		var hold := ""
		if not vehicle.state.fires.is_empty(): hold = "fire"
		elif ai.phase == "repair": hold = "recovery"
		elif ai.phase in ["observe","engage"] and not (ai.advance_while_engaged and caps.drive and (drv.has_goal or ai.has_patrol)):
			hold = "combat"   # engaging with no movement task; carrying one falls through to advance-intent
		elif not caps.drive: hold = "immobile"
		elif drv.phase in ["failed","unreachable"]: hold = "planning_"+drv.phase
		elif ai.has_patrol and patrol_dist <= GameConfig.AI_GOAL_RADIUS_M: hold = "at_objective"
		elif ai.phase == "retreat" and not drv.has_goal and vehicle.get_parent().has_method("_in_supply_area") and vehicle.get_parent().call("_in_supply_area",vehicle): hold = "resupply"
		elif drv.has_goal: pass   # normal advance intent
		elif ai.has_patrol: pass  # GPT fix (d): objective pending without a nav goal = task stall, NOT a hold
		else: hold = "no_task"
		if hold != "":
			_close(key,"state:"+hold)
			rec.holds[hold] = float(rec.holds.get(hold,0.0)) + delta
			continue
		if speed >= MOVE_EPS:
			_close(key,"resumed")
			continue
		var ep: Dictionary = active.get(key, {})
		if ep.is_empty():
			active[key] = {"t0":clock}   # open after WAIT_START_S sustains
		elif not ep.has("opened") and clock - float(ep.t0) >= WAIT_START_S:
			ep.opened = clock - WAIT_START_S
			ep.blocker = _blocker_class(vehicle)
			ep.driver_phase = drv.phase
			ep.ai_phase = ai.phase
			ep.waypoint = ("%d/%d" % [drv.waypoint, drv.path.size()]) if drv.has_goal else "no_nav_goal"
			# ep is the stored reference; no re-assignment needed (and re-assigning
			# the initial empty dict here used to reset t0 every frame, so no episode
			# could ever open — the core undercount this measurement pass found).
	for key in active.keys():
		if not seen.has(key): _close(key,"gone")

func _blocker_class(vehicle) -> String:
	# Nearest other vehicle proximity as a cheap congestion hint; otherwise unknown.
	for other in vehicle.get_parent().combat_actors():
		if other == vehicle or other.state.destroyed: continue
		if vehicle.tank.global_position.distance_to(other.tank.global_position) < 5.0:
			return "near_vehicle"
	return "unknown"

func _close(key: String, outcome: String) -> void:
	var ep: Dictionary = active.get(key, {})
	if ep.is_empty():
		active.erase(key)
		return
	active.erase(key)
	if not ep.has("opened"): return   # stall never sustained long enough to matter
	var rec: Dictionary = records[key]
	var duration: float = clock - float(ep.opened)
	if duration < 1.0: return
	var episodes: Array = rec.episodes
	episodes.append({"start_s":ep.opened,"end_s":clock,"duration_s":duration,
		"outcome":outcome,"blocker":ep.blocker,"driver_phase":ep.driver_phase,
		"ai_phase":ep.get("ai_phase","?"),"waypoint":ep.waypoint})
	rec.longest_s = maxf(float(rec.longest_s), duration)
	rec.total_s = float(rec.total_s) + duration

func snapshot() -> Dictionary:
	# GPT fix (c): a stall still running at snapshot time is recorded as
	# "open_at_end" (unrecovered as of end), never as a recovered success.
	var out: Dictionary = {}
	for key in records:
		var rec: Dictionary = records[key]
		var episodes: Array = rec.episodes.duplicate(true)
		var open_at_end := 0
		var open_duration := 0.0
		var ep: Dictionary = active.get(key, {})
		if ep.has("opened"):
			open_duration = maxf(0,clock-float(ep.opened))
			episodes.append({"start_s":ep.opened,"end_s":clock,"duration_s":clock-float(ep.opened),
				"outcome":"open_at_end","blocker":ep.blocker,"driver_phase":ep.driver_phase,
				"ai_phase":ep.get("ai_phase","?"),"waypoint":ep.waypoint})
			open_at_end = 1
		out[key] = {"team":rec.team,"episodes":episodes,"longest_s":maxf(rec.longest_s,open_duration),
			"total_s":rec.total_s+open_duration,"closed_total_s":rec.total_s,"open_total_s":open_duration,"holds":rec.holds,"open_at_end":open_at_end}
	return {"clock":clock,"per_life":out,"planning":planning.duplicate(),
		"thresholds":{"move_eps":MOVE_EPS,"wait_start_s":WAIT_START_S}}

func write_evidence(path: String) -> bool:
	var serialized := JSON.stringify(snapshot(),"  ")
	if serialized.to_utf8_buffer().size()>MAX_EVIDENCE_BYTES: return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(serialized)
	file.close()
	return true
