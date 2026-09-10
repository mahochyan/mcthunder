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

var clock := 0.0
var records: Dictionary = {}   # "entity:life" -> {episodes, longest_s, total_s, ...}
var active: Dictionary = {}    # key -> {t0, driver_phase, ...} current stall episode
var planning: Dictionary = {"failed":0,"unreachable":0,"replanned":0}

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
			rec = {"team":vehicle.state.team_id,"episodes":[],"longest_s":0.0,"total_s":0.0,"holds":{},"events_seen":0}
			records[key] = rec
		# GPT fix (a): planning counters come from real planning-request outcomes in
		# the driver event log, never from phase polling that can miss transitions.
		var evs: Array = drv.events
		while int(rec.events_seen) < evs.size():
			var ev: Dictionary = evs[int(rec.events_seen)]
			if ev.get("phase","") in ["failed","unreachable"]:
				planning[ev.phase] = int(planning.get(ev.phase,0)) + 1
			rec.events_seen = int(rec.events_seen) + 1
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
		elif ai.phase == "retreat" and not drv.has_goal: hold = "resupply"
		elif drv.has_goal: pass   # normal advance intent
		elif ai.has_patrol: pass  # GPT fix (d): objective pending without a nav goal = task stall, NOT a hold
		else: hold = "no_task"
		if hold != "":
			_close(key,"state:"+hold)
			rec.holds[hold] = float(rec.holds.get(hold,0.0)) + delta
			continue
		if drv.phase == "replanning" or drv.phase == "escape":
			planning.replanned = int(planning.replanned) + 1
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
		var ep: Dictionary = active.get(key, {})
		if ep.has("opened"):
			episodes.append({"start_s":ep.opened,"end_s":clock,"duration_s":clock-float(ep.opened),
				"outcome":"open_at_end","blocker":ep.blocker,"driver_phase":ep.driver_phase,
				"ai_phase":ep.get("ai_phase","?"),"waypoint":ep.waypoint})
			open_at_end = 1
		out[key] = {"team":rec.team,"episodes":episodes,"longest_s":rec.longest_s,
			"total_s":rec.total_s,"holds":rec.holds,"open_at_end":open_at_end}
	return {"clock":clock,"per_life":out,"planning":planning,
		"thresholds":{"move_eps":MOVE_EPS,"wait_start_s":WAIT_START_S}}

func write_evidence(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(snapshot(),"  "))
	file.close()
	return true
