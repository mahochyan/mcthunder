class_name ChallengeDirector
extends Node
signal started
signal finished(result: Dictionary)
static var _next_attempt := 24000
var attempt_id := 0
var config: Dictionary = {}
var phase := "idle"
var countdown_left := 3.0
var elapsed := 0.0
var held := 0.0
var checkpoint := 0
var wave := 0
var spawn_waiting := false
var _next_wave_try := 0.0
var repairs := 0
var result: Dictionary = {}
var kills: Dictionary = {}
var flank_hits: Dictionary = {}
var _seen: Dictionary = {}
var _repair_seen: Dictionary = {}
var _arena: WeakRef
var _player_life := -1
var _player_generation := -1
func begin(arena: Node3D, rules: Dictionary) -> bool:
	if phase != "idle" or arena == null or rules.is_empty() or rules != ChallengeCatalog.create(str(rules.get("id","")),str(rules.get("difficulty",""))): return false
	_next_attempt += 1; attempt_id = _next_attempt
	config = rules.duplicate(true)
	ShotRecordBuilder.freeze_containers(config)
	_arena = weakref(arena)
	_player_life = arena.actor.life_id
	_player_generation = arena.actor.state.generation
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 300
	phase = "countdown"
	return true
func arena() -> Node3D: return _arena.get_ref() as Node3D if _arena != null else null
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not is_inside_tree() or get_tree().paused or not is_finite(delta) or delta <= 0 or phase not in ["countdown","playing"]: return
	var world := arena()
	if world == null: return
	if phase == "countdown":
		countdown_left = maxf(0,countdown_left-delta)
		if countdown_left <= 0: phase = "playing"; started.emit()
		return
	if world.actor.life_id != _player_life or world.actor.state.generation != _player_generation:
		finish_once(false,"identity_changed"); return
	var step := minf(delta,maxf(0,config.limit-elapsed))
	elapsed = minf(config.limit,elapsed+step)
	if world.actor.state.destroyed: finish_once(false,"player_destroyed"); return
	# Death attribution can arrive during damage before shot_record_ready. Evaluate
	# objectives after the manager has finished its physical step.
	for vehicle in world.combat_actors():
		if vehicle.state.team_id != 2 or not vehicle.state.destroyed or kills.has(vehicle.entity_id): continue
		if world._spawned.get(vehicle.entity_id,-1) != vehicle.life_id or world._spawn_generations.get(vehicle.entity_id,-1) != vehicle.state.generation: continue
		var source: Dictionary = vehicle.state.death_record.get("source",{})
		if source.get("round_id",-1) == attempt_id and source.get("shooter_id","") == "A" and source.get("shooter_life_id",-1) == _player_life:
			kills[vehicle.entity_id] = vehicle.life_id
	var success := false
	match config.id:
		"flank_hunter": success = kills.has("B1") and flank_hits.get("B1",-1) == kills.get("B1",-2)
		"hold_ground":
			if _inside(world.actor,config.zone,config.radius) and not contested(): held = minf(config.hold,held+step)
			if wave == 0 and kills.has("B1") and elapsed >= _next_wave_try:
				_next_wave_try = elapsed+1.0
				spawn_waiting = not world.spawn_wave(1)
				if not spawn_waiting: wave = 1
			success = held >= config.hold-0.000001 and kills.size() == config.enemies.size()
		"td_route":
			if checkpoint < config.route.size():
				if _inside(world.actor,config.route[checkpoint],8.0): checkpoint += 1
			elif _inside(world.actor,config.zone,config.radius) and not contested(): held = minf(config.hold,held+step)
			else: held = 0
			success = held >= config.hold-0.000001
	if success: finish_once(true,"objectives_complete")
	elif elapsed >= config.limit-0.000001: finish_once(false,"time_limit")
	elif config.id != "td_route" and world.actor.gunner.rounds_remaining == 0 and world.projectiles.active_count() == 0 and kills.size() < config.enemies.size(): finish_once(false,"ammunition_empty")
	elif config.id == "flank_hunter" and kills.has("B1") and not flank_hits.has("B1"): finish_once(false,"flank_required")
func contested() -> bool:
	var world := arena()
	if world == null: return false
	for vehicle in world.combat_actors():
		if vehicle.state.team_id == 2 and not vehicle.state.destroyed and _inside(vehicle,config.zone,config.radius): return true
	return false
static func _inside(vehicle: VehicleActor, point: Vector3, radius: float) -> bool:
	return Vector2(vehicle.tank.global_position.x-point.x,vehicle.tank.global_position.z-point.z).length() <= radius
func accept_record(record: Dictionary) -> bool:
	if phase != "playing" or not record.get("identity") is Dictionary or not record.get("record_id") is String: return false
	var world := arena()
	if world == null or _seen.has(record.record_id) or _seen.size() >= 256: return false
	var identity: Dictionary = record.identity
	if identity.get("round_id",-1) != attempt_id or identity.get("shooter_id","") != "A" or identity.get("shooter_life_id",-1) != _player_life: return false
	var authentic := false
	for i in world.projectiles.shot_records.count():
		if world.projectiles.shot_records.get_record(i) == record: authentic = true; break
	if not authentic: return false
	_seen[record.record_id] = true
	for contact in record.contacts:
		if contact.get("result","") != "penetrated" or contact.get("backface",false): continue
		var target: VehicleActor = world.find_actor(str(contact.get("entity_id","")),int(contact.get("life_id",-1)))
		if target == null or target.state.team_id != 2: continue
		if world._spawned.get(target.entity_id,-1) != target.life_id or contact.get("target_generation",-1) != world._spawn_generations.get(target.entity_id,-2) or target.state.generation != contact.get("target_generation",-1): continue
		for patch in target.damage_layout_override.armor_patches:
			if patch.id == contact.get("surface_id","") and (patch.plate_group_id.contains("sides") or patch.plate_group_id.contains("rear")):
				flank_hits[target.entity_id] = target.life_id
	return true
func accept_repair(record: Dictionary) -> bool:
	var world := arena()
	if phase != "playing" or world == null or record != world.actor.last_recovery_record or record.is_empty(): return false
	if record.get("life_id",-1) != _player_life or record.get("generation",-1) != _player_generation or record.get("entity_id","") != "A" or record.get("kind","") != "repair" or record.get("after",0) <= record.get("before",0) or _repair_seen.has(record.event_id) or repairs >= 256: return false
	_repair_seen[record.event_id] = true; repairs += 1
	return true
func finish_once(passed: bool, reason: String) -> bool:
	if phase not in ["countdown","playing"]: return false
	var world := arena()
	if world == null: return false
	# No external caller can manufacture a victory: only objective evaluation uses it.
	if passed:
		var verified: bool = (config.id == "flank_hunter" and kills.has("B1") and flank_hits.get("B1",-1) == kills.B1) or (config.id == "hold_ground" and held >= config.hold-0.000001 and kills.size() == config.enemies.size()) or (config.id == "td_route" and checkpoint == config.route.size() and held >= config.hold-0.000001)
		if not verified or world.actor.state.destroyed: return false
	phase = "finished"
	var stats := {"elapsed":roundi(elapsed*1000)/1000.0,"shots":world.actor.gunner.shots_fired,"repairs":repairs}
	result = ChallengeScore.evaluate(config,stats,passed)
	result.merge({"attempt_id":attempt_id,"best_key":ChallengeCatalog.key(config),"title":config.title,"status":"passed" if passed else "failed","reason":reason})
	ShotRecordBuilder.freeze_containers(result)
	finished.emit(result.duplicate(true))
	return true
func progress_text() -> String:
	match config.id:
		"flank_hunter": return "侧后穿透 %s · 击毁 %d/1"%["已确认" if flank_hits.has("B1") else "尚未确认",kills.size()]
		"hold_ground": return "驻守 %.0f/%.0f秒 · 击毁 %d/2 · 有效维修 %d%s"%[held,config.hold,kills.size(),repairs," · 第二波等候道路清空" if spawn_waiting else ""]
		"td_route": return "道路检查点 %d/2 · 连续占点 %.0f/%.0f秒"%[checkpoint,held,config.hold]
	return ""
