extends SceneTree
# WT-020-R1: AI task distribution, hysteresis, auditable decision reasons, bounded
# head-on give-way, and a laboratory check that perception never tracks hidden truth.
var count := 0
var failed := 0
var scene: AICombatRange
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
func _roster() -> Array:
	var rows: Array = []
	for i in 8:
		rows.append({"entity_id":"AI%d"%i,"team":1,"position":Vector3(float(i)*4.0,0.0,0.0),
			"forward":Vector3.FORWARD,"ammo_fraction":1.0,"mobile":true,"destroyed":false})
	return rows
func _context() -> Dictionary:
	return {"team":1,
		"objectives":[{"id":"A","position":Vector3(-520,9,120),"owner_team":0},
			{"id":"B","position":Vector3(0,9,-130),"owner_team":0},
			{"id":"C","position":Vector3(520,9,100),"owner_team":0}],
		"supply":{1:Vector3(370,9,712),2:Vector3(370,9,-712)}}
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. allocation covers the three public objectives and includes a flank ---
	var allocator := AIRoleAllocator.new()
	var assignments := allocator.assign(_roster(),_context())
	var roles := {}
	var objectives := {}
	for id in assignments:
		roles[str(assignments[id].role)] = int(roles.get(str(assignments[id].role),0))+1
		if str(assignments[id].role) in ["attack","flank"]:
			objectives[str(assignments[id].objective)] = true
	_check(assignments.size() == 8,"every living slot receives a task (8 of 8)")
	_check(objectives.size() == 3,"attack and flank tasks cover all three public objectives (%s)"%str(objectives.keys()))
	_check(int(roles.get("flank",0)) == 1,"exactly one slot is assigned to the flank role")
	_check(int(roles.get("attack",0)) >= 3,"the remaining mobile slots push public objectives (%d attack)"%int(roles.get("attack",0)))
	# determinism: same inputs, same result
	var second := AIRoleAllocator.new()
	var repeat := second.assign(_roster(),_context())
	var identical := true
	for id in assignments:
		if str(assignments[id].role) != str(repeat[id].role) or str(assignments[id].objective) != str(repeat[id].objective): identical = false
	_check(identical,"task allocation is deterministic for identical roster and context")
	# --- 2. hysteresis: no per-step oscillation ---
	allocator.tick(1.0)
	var before := allocator.task_for("AI1")
	var changed := allocator.assign(_roster(),_context())
	_check(str(changed["AI1"].role) == str(before.role) and str(changed["AI1"].objective) == str(before.objective),"a re-assignment inside the cooldown keeps the same role and objective")
	_check(float(allocator.decision_reason("AI1").assigned_age_s) < AIRoleAllocator.SWITCH_COOLDOWN_S,"task age is tracked for the hysteresis window")
	# --- 3. urgent triggers bypass the cooldown ---
	var hurt := _roster()
	hurt[2]["mobile"] = false
	hurt[2]["immobile_damaged"] = true
	var urgent_assign := allocator.assign(hurt,_context())
	_check(str(urgent_assign["AI2"].role) == "repair" and bool(urgent_assign["AI2"].urgent),"an immobile damaged slot switches to repair immediately, bypassing the cooldown")
	var dry := _roster()
	dry[3]["ammo_fraction"] = 0.1
	var dry_assign := allocator.assign(dry,_context())
	_check(str(dry_assign["AI3"].role) == "supply" and bool(dry_assign["AI3"].urgent),"a dry slot switches to resupply immediately")
	_check(str(allocator.objective_position("AI3",_context())) == str(Vector3(370,9,712)),"the resupply task resolves to the team's own supply point")
	# --- 4. auditable decision reason ---
	var reason := allocator.decision_reason("AI3",{"last_seen_age_s":2.5,"ammo_state":"dry","damage_state":"engine_damaged"})
	for field in ["task","objective","reason","assigned_age_s","urgent","last_seen_age_s","ammo_state","damage_state"]:
		_check(reason.has(field),"decision reason carries %s"%field)
	_check(float(reason.last_seen_age_s) == 2.5 and str(reason.ammo_state) == "dry","decision reason reports the state it actually saw")
	# legitimate holds are labelled, so a defended objective is never counted as a stall
	var holder_rows := _roster()
	holder_rows[5]["at_objective"] = true
	var hold_alloc := AIRoleAllocator.new()
	hold_alloc.assign([holder_rows[5]],{"team":1,"objectives":[],"supply":{1:Vector3.ZERO}})
	_check(str(hold_alloc.task_for("AI5").get("hold_reason","")) == "legitimate_objective_hold","holding an owned objective is recorded as a legitimate hold")
	# --- 5. bounded head-on give-way ---
	var gate := AIRoleAllocator.new()
	gate.chokepoint_test = func(_p: Vector3) -> bool: return true
	var lower := {"entity_id":"AI1","team":1,"position":Vector3.ZERO,"forward":Vector3.FORWARD}
	var higher := {"entity_id":"AI3","team":1,"position":Vector3(3,0,0),"forward":Vector3.BACK}
	_check(gate.should_give_way(higher,lower),"inside a chokepoint the higher entity id yields to the lower one")
	_check(not gate.should_give_way(lower,higher),"the lower entity id does not yield to the higher one")
	var open := AIRoleAllocator.new()
	open.chokepoint_test = func(_p: Vector3) -> bool: return false
	_check(not open.should_give_way(higher,lower),"nobody yields outside a chokepoint")
	var same_way := AIRoleAllocator.new()
	same_way.chokepoint_test = func(_p: Vector3) -> bool: return true
	var follower := {"entity_id":"AI3","team":1,"position":Vector3(3,0,0),"forward":Vector3.FORWARD}
	_check(not same_way.should_give_way(higher,follower),"nobody yields when headings are not opposing")
	var enemy := {"entity_id":"B7","team":2,"position":Vector3(3,0,0),"forward":Vector3.BACK}
	_check(not same_way.should_give_way(higher,enemy),"give-way applies to the same team only")
	_check(AIRoleAllocator.CHOKEPOINT_GIVE_WAY_S <= 10.0,"give-way waiting is bounded in time")
	# --- 6. laboratory: perception never tracks hidden truth ---
	scene = AICombatRange.new()
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	_check(scene.combat_ready,"combat laboratory ready for the perception check")
	var ai := scene.ai
	var hidden_observation: Dictionary = ai.observation
	print("[info] hidden observation=",hidden_observation)
	var visible_hidden: Variant = hidden_observation.get("visible",false)
	_check(visible_hidden == false,"with the target behind cover the AI reports it as not visible")
	for forbidden in ["modules","crew","module_states","crew_states"]:
		_check(not hidden_observation.has(forbidden),"perception exposes no %s from the target's internals"%forbidden)
	var stale_visible := false
	for i in 500:
		await physics_frame
		if bool(ai.observation.get("visible",false)): stale_visible = true
	_check(not stale_visible,"the hidden target is never tracked through the wall over 500 ticks")
	# --- 7. controller wiring: the assigned task drives the objective, and a head-on
	#        friendly inside a chokepoint produces a bounded throttle-zero hold ---
	var team_alloc := AIRoleAllocator.new()
	team_alloc.chokepoint_test = func(_p: Vector3) -> bool: return true
	var bot := scene.target_actor
	var bot_context := {"team":bot.state.team_id,
		"objectives":[{"id":"A","position":Vector3(-520,9,120),"owner_team":0}],
		"supply":{bot.state.team_id:Vector3(370,9,712)},
		"friendly_rows":[{"entity_id":"AA","team":bot.state.team_id,"position":bot.tank.global_position+Vector3(1,0,0),"forward":bot.tank.global_basis.z}]}
	var bot_row := {"entity_id":bot.entity_id,"team":bot.state.team_id,"position":bot.tank.global_position,
		"forward":Vector3.FORWARD,"ammo_fraction":1.0,"mobile":true,"destroyed":false}
	team_alloc.assign([bot_row],bot_context)
	ai.bind_allocator(team_alloc)
	var events_before := ai.events.size()
	ai.apply_task(bot_context)
	_check(not str(ai.role).is_empty(),"a bound allocator assigns a role to the real AI (%s)"%ai.role)
	_check(str(ai.task_objective) == "A","the assigned task carries the public objective id")
	var assigned_events := 0
	for ev in ai.events.slice(events_before):
		if str(ev.get("reason","")) == "task_assigned": assigned_events += 1
	_check(assigned_events >= 1,"task assignment is recorded as an auditable event")
	var hold_cmd := ai.update_command(0.2)
	_check(ai.phase == "yielding" and absf(hold_cmd.throttle) < 0.001,"a head-on friendly inside a chokepoint produces a throttle-zero hold")
	_check(ai.give_way_until-ai.clock <= AIRoleAllocator.CHOKEPOINT_GIVE_WAY_S+0.001,"the hold is bounded to the give-way window")
	ai.give_way_until = -INF
	var resumed := ai.update_command(0.2)
	_check(ai.phase != "yielding","after the hold expires the AI is no longer forced to yield")
	print("[info] wired role=%s objective=%s reason=%s hold_expired_throttle=%.2f"%[ai.role,ai.task_objective,ai.task_reason,resumed.throttle])
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("AI_TACTICS_CHECKS_PASS" if failed == 0 else "AI_TACTICS_CHECKS_FAIL")
	scene.free()
	quit(1 if failed else 0)
