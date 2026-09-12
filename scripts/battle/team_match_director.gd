class_name TeamMatchDirector
extends Node
signal round_started
signal vehicle_lost(id: String)
signal match_finished(result: Dictionary)
var state := TeamMatchState.new()
var respawns := RespawnService.new()
var center := Vector3.ZERO
var player_shots := 0
var _last_player_life := -1
var _last_player_shot := 0
var report := {"hits":0,"penetrations":0,"kills":0,"deaths":0,"capture_seconds":0.0,"last_death":""}
var _hit_shots := {}
var _penetrating_shots := {}

func observe_contact(record: Dictionary) -> void:
	if state.phase != "playing" or record.get("round_id",-1) != state.match_id or record.get("shooter_id","") != "A": return
	var target := str(record.get("entity_id",""))
	if not state.roster.has(target) or state.roster[target].team == state.roster.A.team: return
	if record.get("life_id",-1) != state.roster[target].life_id: return
	var shot := int(record.get("projectile_id",-1))
	if shot < 0: return
	if not _hit_shots.has(shot):
		_hit_shots[shot] = true
		report.hits += 1
	if record.get("result","") == "penetrated" and not _penetrating_shots.has(shot):
		_penetrating_shots[shot] = true
		report.penetrations += 1

func _ready() -> void:
	process_physics_priority = SimulationPhases.MATCH
	process_mode = Node.PROCESS_MODE_PAUSABLE

func begin(team_size: int = 4, objectives: Array = []) -> bool:
	if team_size < 1 or team_size > 16: return false
	var capture_set: BattleObjectives = null
	if not objectives.is_empty():
		capture_set = BattleObjectives.new()
		if not capture_set.configure(objectives): return false
	state = TeamMatchState.new()
	state.initialize(team_size)
	state.objectives = capture_set
	player_shots = 0
	_last_player_life = -1
	_last_player_shot = 0
	report = {"hits":0,"penetrations":0,"kills":0,"deaths":0,"capture_seconds":0.0,"last_death":""}
	_hit_shots.clear()
	_penetrating_shots.clear()
	return true
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or get_tree().paused: return
	if state.phase == "countdown":
		state.countdown = maxf(0,state.countdown-delta)
		if state.countdown <= 0:
			state.phase = "playing"
			state.record("match_started",{})
			round_started.emit()
		return
	if state.phase != "playing": return
	var used := minf(delta,maxf(0,TeamMatchState.TIME_LIMIT-state.elapsed))
	state.elapsed += used
	var teams: Array = []
	var occupants: Array = []
	var player_inside := false
	for id in state.roster:
		var vehicle := state.actor_for(id)
		var row: Dictionary = state.roster[id]
		var protected_at_start := float(row.protection_left)>0
		row.protection_left = maxf(0,float(row.protection_left)-used)
		if vehicle == null: continue
		if vehicle.life_id != row.life_id or vehicle.state.generation != row.generation: continue
		if id == "A":
			if vehicle.life_id != _last_player_life:
				_last_player_life = vehicle.life_id
				_last_player_shot = 0
			player_shots += maxi(0,vehicle.gunner.shot_id-_last_player_shot)
			_last_player_shot = vehicle.gunner.shot_id
		if vehicle.state.destroyed:
			state.queue_death(vehicle.state.death_record)
			continue
		if protected_at_start: continue
		occupants.append({"id":id,"team":row.team,"position":vehicle.tank.global_position})
		var offset := vehicle.tank.global_position-center
		offset.y = 0
		if offset.length() <= TeamMatchState.CAPTURE_RADIUS:
			teams.append(row.team)
			if id == "A": player_inside = true
	var owned: Dictionary
	if state.objectives == null:
		owned = CapturePoint.step(state,teams,used)
		if player_inside and not state.contested: report.capture_seconds += used
	else:
		var capture := state.objectives.step(state,occupants,used)
		owned = capture.owned
		report.capture_seconds += capture.player_seconds
	var deaths := TicketLedger.apply_events(state,owned)
	for id in deaths:
		var lost := state.actor_for(id)
		if id == "A":
			report.deaths += 1
			if lost != null: report.last_death = str(lost.state.death_record.get("cause","unknown"))
		elif lost != null and lost.state.team_id != state.roster.A.team:
			var source: Dictionary = lost.state.death_record.get("source",{})
			if source.get("shooter_id","") == "A" and source.get("round_id",-1) == state.match_id: report.kills += 1
		vehicle_lost.emit(id)
	if state.phase != "playing": return
	var outcome := TicketLedger.result_after_tick(state)
	if not outcome.is_empty():
		finish_once(outcome,"time_limit" if state.elapsed >= TeamMatchState.TIME_LIMIT else "tickets")
		return
	respawns.step(state)

func on_vehicle_destroyed(record: Dictionary) -> void:
	var vehicle := state.actor_for(str(record.get("entity_id","")))
	if vehicle != null and vehicle.state.destroyed: state.queue_death(vehicle.state.death_record)

func observe_command(vehicle: VehicleActor, command: VehicleCommand) -> void:
	if state.phase != "playing" or not state.roster.has(vehicle.entity_id): return
	var row: Dictionary = state.roster[vehicle.entity_id]
	if row.life_id != vehicle.life_id: return
	if command.fire_requested or absf(command.throttle)>0.001 or absf(command.steer)>0.001:
		row.protection_left = 0.0

func finish_once(outcome: String, reason: String) -> bool:
	if state.phase not in ["countdown","playing"]: return false
	state.phase = "finished"
	state.finish_count += 1
	for row in state.roster.values(): row.respawn_at = -1.0; row.request_sent = false
	state.pending_deaths.clear()
	state.record("match_finished",{"outcome":outcome,"reason":reason,"tickets":state.tickets.duplicate()})
	state.result = {"title":LocalizationService.text("ui_0dd5e3593738"),"outcome":outcome,"reason":reason,"status":"passed" if outcome == "victory" else "failed","shots":player_shots,"match_id":state.match_id,"seconds":state.elapsed,"tickets":state.tickets.duplicate(),"events":state.events.duplicate(true)}
	state.result["event_sequence"] = state.event_sequence
	if state.objectives != null: state.result["objectives"] = state.objectives.snapshot()
	state.result["combat_summary"] = report.duplicate(true)
	match_finished.emit(state.result.duplicate(true))
	return true
