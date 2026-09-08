extends SceneTree
## Golden expectations are constants/independent geometry, not computed by ArmorResolver.
var count := 0
var failed := 0
var mgr: ProjectileManager
var world: Node3D
var records: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var shot := 0

func _initialize() -> void:
	call_deferred("_run")

func _ok(condition: bool, label: String) -> void:
	count += 1
	if not condition:
		failed += 1
	print(("[PASS] " if condition else "[FAIL] ") + label)

func _near(a: float, b: float, tolerance: float = 1e-4) -> bool:
	return absf(a - b) <= tolerance

func _contact(thickness: float, angle: float = 0.0) -> Dictionary:
	return {"has_thickness": thickness >= 0, "thickness_status": "estimated" if thickness >= 0 else "unknown",
		"thickness_mm": maxf(0,thickness), "normal_world": Basis(Vector3.UP,deg_to_rad(angle)) * Vector3.BACK}

func _resolve(thickness: float, angle: float, power: float, consumed: float = 0, scale: float = 1, bounces: int = 0, dir: Vector3 = Vector3.FORWARD) -> Dictionary:
	return ArmorResolver.resolve(_contact(thickness,angle),dir,{"base_mm":power,"consumed_mm":consumed,"scale":scale,"ricochets":bounces})

func _unit() -> void:
	var curve := PackedVector2Array([Vector2(0,70), Vector2(100,60), Vector2(200,40)])
	_ok(PenetrationCurve.validate(curve),"curve valid")
	for pair in [Vector2(0,70),Vector2(50,65),Vector2(100,60),Vector2(150,50),Vector2(200,40),Vector2(1000,40)]:
		_ok(_near(PenetrationCurve.sample_mm(curve,pair.x),pair.y),"curve independent expected at " + str(pair.x))
	for points in [PackedVector2Array(),PackedVector2Array([Vector2(0,70),Vector2(0,50)]),
		PackedVector2Array([Vector2(0,70),Vector2(1,80)]),PackedVector2Array([Vector2(-1,70)]),
		PackedVector2Array([Vector2(0,-1)]),PackedVector2Array([Vector2(INF,70)])]:
		_ok(not PenetrationCurve.validate(points),"invalid curve rejected " + str(points))
	_ok(PenetrationCurve.sample_mm(curve,-1) < 0,"negative distance rejected")
	_ok(PenetrationCurve.sample_mm(curve,NAN) < 0,"nonfinite distance rejected")
	var r := _resolve(40,0,60)
	_ok(r.result == "penetrated" and _near(r.after_mm,20),"P60 / 40 -> penetrate with 20")
	r = _resolve(80,0,60)
	_ok(r.result == "stopped" and not r.continue_flight,"P60 / 80 -> stop")
	r = _resolve(40,60,60)
	_ok(r.result == "stopped" and _near(r.effective_mm,80),"40 @60deg -> 80 LOS")
	r = _resolve(40,0,70,40)
	_ok(r.result == "stopped" and _near(r.before_mm,30),"P70 already consumed40 does not recover at next40")
	r = _resolve(40,0,40)
	_ok(r.result == "perforated_stop" and _near(r.after_mm,0),"exact budget perforates then stops")
	for angle in [74.9,75.0,75.1]:
		r = _resolve(1,angle,100)
		_ok(r.result == ("penetrated" if angle < 75 else "ricochet"),"ricochet threshold %.1f" % angle)
	r = _resolve(40,90,60)
	_ok(r.result == "grazing_unresolved" and is_finite(float(r.effective_mm)),"90deg is bounded unresolved")
	r = _resolve(-1,80,60)
	_ok(r.result == "unknown_armor","unknown checked before ricochet; not zero")
	r = _resolve(40,0,60,0,1,0,Vector3.BACK)
	_ok(r.result == "penetrated" and r.backface and _near(r.after_mm,20),"backface pays same thickness")
	r = _resolve(1,80,100,40)
	_ok(r.result == "ricochet" and _near(r.scale,0.5) and _near(r.consumed_mm,20) and _near(r.after_mm,30),"bounce scales k AND consumed; residual60 becomes30")
	_ok(_near((r.direction as Vector3).length(),1) and _near(r.speed_scale,0.6),"reflection normalized and speed scale0.6")
	_ok(float(r.effective_mm) > 5.7 and float(r.effective_mm) < 5.8,"ricochet detail retains geometric LOS thickness")
	_ok((r.direction as Vector3).dot(_contact(1,80).normal_world) > 0,"reflection leaves surface")
	r = _resolve(1,80,100,0,1,1)
	_ok(r.result == "ricochet_limit" and not r.continue_flight,"second ricochet stops")
	_ok(_resolve(40,0,60,0,1,0,Vector3.ZERO).result == "invalid","zero direction rejected")
	_ok(_resolve(40,0,INF).result == "invalid","nonfinite budget rejected")
	var bad := _contact(40)
	bad.normal_world = Vector3(0,0,2)
	_ok(ArmorResolver.resolve(bad,Vector3.FORWARD,{"base_mm":60}).result == "invalid","nonunit normal rejected")
	var budget := {"base_mm":70.0,"consumed_mm":10.0,"scale":1.0,"ricochets":0}
	var original := budget.duplicate(true)
	ArmorResolver.resolve(_contact(20),Vector3.FORWARD,budget)
	_ok(budget == original,"resolver does not mutate input budget")

func _spawn(power: float = 70, speed: float = 600, pos: Vector3 = Vector3(0,20,0)) -> ProjectileState:
	shot += 1
	var spec := {"round_id":1,"shooter_id":"shooter","shooter_life_id":1,"shot_id":shot,
		"shell_id":"test_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,power)]),
		"position_world":pos,"velocity_world":Vector3(0,0,-speed),"gravity_world":Vector3.ZERO,
		"max_age_s":10.0,"max_distance_m":1000.0}
	var result := mgr.try_spawn(spec)
	_ok(result.get("ok",false),"real manager accepts armor shot")
	return mgr.get_projectile_state(int(result.get("projectile_id",0)))

func _plates(specs: Array) -> Array:
	var plates: Array = []
	for i in specs.size():
		var s: Dictionary = specs[i].duplicate()
		s.center = Vector3(float(s.get("x",0)),20,-float(s.get("distance",i+1)))
		plates.append(s)
	return [ArmorTrainingTargets.build(plates)]

func _step(st: ProjectileState, snapshots: Array, dt: float = 1.0/60.0) -> void:
	mgr.advance_projectile(st,dt,snapshots,world.get_world_3d().direct_space_state)

func _clear() -> void:
	mgr.cancel_all("cancelled_reset")
	records.clear()
	contacts.clear()

func _integration() -> void:
	var st := _spawn(60)
	_step(st,_plates([{"thickness":40}]))
	_ok(st.contacts.size() == 1 and _near(st.consumed_mm,40),"two triangles on one plate cost once")
	_ok(_near(st.travelled_m,10) and _near(st.age_s,1.0/60),"penetration consumes remaining time, ends at10m")
	_ok(not st.is_terminal(),"thin plate continues as same projectile")
	_clear()
	st = _spawn(70)
	_step(st,_plates([{"thickness":40},{"thickness":40}]))
	_ok(st.is_terminal() and st.terminal_reason == "armor_stopped","same-step 40+40 stops second")
	_ok(st.contacts.size() == 2 and _near(st.contacts[0].after_mm,30) and _near(st.contacts[1].before_mm,30),"cumulative budget70 ->30 ->0")
	_ok(_near(st.travelled_m,2) and _near(st.age_s,2.0/600),"second plate exact travel and time")
	_ok(records.size() == 1 and contacts.size() == 2,"two contacts, one terminal")
	_ok(contacts[0].first_for_target and not contacts[1].first_for_target,"one first-contact score per target life")
	_ok(st.contacts[0].part_world_transform is Transform3D,"record preserves actual contact pose")
	_clear()
	st = _spawn(70)
	st.penetration_curve = PackedVector2Array([Vector2(0,70),Vector2(10,20)])
	_step(st,_plates([{"thickness":40},{"thickness":25,"distance":2}]))
	_ok(st.terminal_reason == "armor_stopped" and _near(st.contacts[0].before_mm,65) and _near(st.contacts[1].before_mm,20),"distance loss plus consumed budget remain cumulative")
	_clear()
	st = _spawn()
	_step(st,_plates([{"thickness":-1}]))
	_ok(st.terminal_reason == "armor_unknown_armor" and st.contacts.size() == 1,"unknown plate conservatively stops actual flight")
	_clear()
	st = _spawn(70,60)
	var endpoint := _plates([{"thickness":10,"distance":1}])
	_step(st,endpoint)
	_step(st,endpoint)
	_ok(st.contacts.size() == 1 and _near(st.travelled_m,2),"next tick does not recharge same endpoint plate")
	_clear()
	st = _spawn(70)
	_step(st,_plates([{"thickness":10,"distance":1},{"thickness":10,"distance":1},{"thickness":10,"distance":1}]))
	_ok(st.contacts.size() == 3 and _near(st.consumed_mm,30),"co-located distinct plates each cost once without loop")
	_clear()
	st = _spawn(70)
	_step(st,_plates([{"thickness":10,"distance":1},{"thickness":10,"distance":1.0001}]))
	_ok(st.contacts.size() == 2 and _near(st.consumed_mm,20),"0.1mm-separated layers not skipped by position nudge")
	_clear()
	st = _spawn(70)
	_step(st,_plates([{"thickness":1,"angle":78,"distance":1}]))
	_ok(st.ricochets == 1 and st.contacts.size() == 1,"actual ricochet resolves once")
	_ok(_near(st.velocity_world.length(),360) and _near(st.travelled_m,6.4,0.002),"remaining15ms at360 after first1m -> total6.4m")
	_ok(_near(st.age_s,1.0/60) and st.position_world.x > 0.1,"reflected remaining trajectory uses new direction")
	_clear()
	st = _spawn(1000)
	var many: Array = []
	for i in 9:
		many.append({"thickness":1,"distance":0.1 + i*0.1})
	_step(st,_plates(many))
	_ok(st.terminal_reason == "contact_budget" and st.contacts.size() == 8,"8 per-step contact limit terminates explicitly")
	_clear()
	st = _spawn(1000,60)
	many.clear()
	for i in 33:
		many.append({"thickness":1,"distance":i+1.0})
	var snap := _plates(many)
	for i in 7:
		_step(st,snap,0.1)
	_ok(st.terminal_reason == "contact_budget" and st.contacts.size() == 32,"32 per-shot limit across ticks")
	_ok(records.size() == 1,"budget termination exactly once")
	_clear()
	var cancel_callback := func(_event: Dictionary) -> void: mgr.cancel_all("cancelled_reset")
	mgr.projectile_contact.connect(cancel_callback)
	st = _spawn()
	_step(st,_plates([{"thickness":10},{"thickness":10}]))
	_ok(st.terminal_reason == "cancelled_reset" and st.contacts.size() == 1 and records.size() == 1,"contact callback reset stops continuation and duplicate terminal")
	mgr.projectile_contact.disconnect(cancel_callback)
	_clear()
	var wall := StaticBody3D.new()
	wall.collision_layer = GameConfig.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20,20,0.2)
	cs.shape = shape
	wall.add_child(cs)
	world.add_child(wall)
	wall.position = Vector3(0,20,-1.1)
	await physics_frame
	await physics_frame
	st = _spawn()
	_step(st,_plates([{"thickness":10,"distance":2}]))
	_ok(st.terminal_reason == "impact_world" and st.contacts.is_empty(),"real world wall blocks armor behind")
	wall.position.z = -3.1
	await physics_frame
	await physics_frame
	_clear()
	st = _spawn()
	_step(st,_plates([{"thickness":10,"distance":1}]))
	_ok(st.terminal_reason == "impact_world" and st.contacts.size() == 1 and _near(st.travelled_m,3,0.001),"penetrated armor then real backwall stops same shot")
	wall.queue_free()
	await physics_frame
	_clear()
	st = _spawn()
	var old_pos := st.position_world
	var old_age := st.age_s
	mgr.set_physics_process(true)
	paused = true
	await process_frame
	await process_frame
	_ok(st.position_world == old_pos and st.age_s == old_age,"paused scene freezes armor projectile")
	paused = false
	await physics_frame
	await physics_frame
	await physics_frame
	_ok(st.age_s > old_age and st.position_world != old_pos,"real physics resumes armor flight after pause")
	mgr.set_physics_process(false)
	_clear()

func _player_path() -> void:
	world.queue_free()
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	await process_frame
	main._pause()
	_ok(main.hud.armor_training_button.visible,"armor entry available in pause menu")
	main.hud.armor_training_button.pressed.emit()
	await process_frame
	await process_frame
	var range_scene := current_scene as ArmorRange
	_ok(range_scene != null and range_scene._initialized,"normal menu entry reaches real ArmorRange")
	if range_scene == null:
		return
	for i in 30:
		await process_frame
	# Input goes through PlayerController -> VehicleActor command -> Gunner.
	var rounds := range_scene.actor.gunner.rounds_remaining
	Input.action_press("fire")
	for i in 4:
		await process_frame
	Input.action_release("fire")
	for i in 120:
		await physics_frame
		if not range_scene.last_contact.is_empty():
			break
	_ok(range_scene.actor.gunner.rounds_remaining == rounds-1,"player input fires once and consumes one round")
	_ok(not range_scene.last_contact.is_empty() and range_scene.last_contact.result == "penetrated","player shot reaches actual thin-plate resolver")
	_ok(range_scene.contact_history.size() == 1,"player shot contact displayed")
	var shared: ShellDefinition = load("res://configs/ap_75_shell.tres")
	_ok(shared.armor_policy == "legacy_contact_only","training does not mutate shared legacy shell")
	range_scene._pause()
	range_scene._return_to_range()
	await process_frame
	await process_frame
	_ok(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn","armor training returns to main through menu")
	current_scene.queue_free()
	await process_frame

func _run() -> void:
	_unit()
	world = Node3D.new()
	root.add_child(world)
	mgr = ProjectileManager.new()
	world.add_child(mgr)
	mgr.set_physics_process(false)
	mgr.projectile_finished.connect(func(r: Dictionary) -> void: records.append(r))
	mgr.projectile_contact.connect(func(r: Dictionary) -> void: contacts.append(r))
	await physics_frame
	await _integration()
	await _player_path()
	print("=== 结果: %d 项检查, %d 失败 ===" % [count,failed])
	print("ARMOR_CHECKS_PASS" if failed == 0 else "ARMOR_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
