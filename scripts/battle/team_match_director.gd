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

func _ready() -> void:
	process_physics_priority = 300
	process_mode = Node.PROCESS_MODE_PAUSABLE

func begin() -> void: state.initialize()
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or get_tree().paused: return
	if state.phase == "countdown":
		state.countdown = maxf(0,state.countdown-delta)
		if state.countdown <= 0:
			state.phase = "playing"
			round_started.emit()
		return
	if state.phase != "playing": return
	var used := minf(delta,maxf(0,TeamMatchState.TIME_LIMIT-state.elapsed))
	state.elapsed += used
	var teams: Array = []
	for id in state.roster:
		var vehicle := state.actor_for(id)
		var row: Dictionary = state.roster[id]
		var protected_at_start := float(row.protection_left)>0
		row.protection_left = maxf(0,float(row.protection_left)-used)
		if vehicle == null: continue
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
		var offset := vehicle.tank.global_position-center
		offset.y = 0
		if offset.length() <= TeamMatchState.CAPTURE_RADIUS: teams.append(row.team)
	var owned := CapturePoint.step(state,teams,used)
	var deaths := TicketLedger.apply_events(state,owned)
	for id in deaths: vehicle_lost.emit(id)
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
	state.result = {"title":"4对4占点","outcome":outcome,"reason":reason,"status":"passed" if outcome == "victory" else "failed","shots":player_shots,"match_id":state.match_id,"seconds":state.elapsed,"tickets":state.tickets.duplicate(),"events":state.events.duplicate(true)}
	match_finished.emit(state.result.duplicate(true))
	return true
