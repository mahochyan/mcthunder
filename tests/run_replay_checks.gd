extends SceneTree
var checks := 0
var failures := 0
var world: Node3D
var actor: VehicleActor
var manager: ProjectileManager
var view: ReplayView
var sequence := 0
var emitted: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _ok(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("[PASS] " if value else "[FAIL] ")+message)

func _layout(thickness: float, angle: float) -> VehicleLayoutDefinition:
	var layout: VehicleLayoutDefinition = ArmorTrainingTargets.build([{"center":Vector3(0,1,-1),"thickness":thickness,"angle":angle}]).layout
	var engine := ModuleVolumeDefinition.new()
	engine.id = "engine"
	engine.kind = "engine"
	engine.part_id = "hull"
	engine.local_box_transform.origin = Vector3(0,1,-2)
	engine.size_m = Vector3(0.5,0.5,0.5)
	layout.modules.append(engine)
	for i in 5:
		var crew := CrewStationDefinition.new()
		crew.id = "crew_"+str(i)
		crew.role = ["driver","gunner","loader","commander","assistant_driver_bow_gunner"][i]
		crew.part_id = "hull"
		crew.local_box_transform.origin = Vector3(1+i*0.4,1,-2)
		crew.size_m = Vector3(0.2,0.3,0.3)
		layout.crew_stations.append(crew)
	return layout

func _shoot(thickness: float = 40, angle: float = 0) -> Dictionary:
	manager.cancel_all("cancelled_reset")
	emitted.clear()
	actor.reset_vehicle()
	actor.set_damage_layout(_layout(thickness,angle))
	sequence += 1
	var spawn := manager.try_spawn({"round_id":1,"shooter_id":"replay_source","shooter_life_id":5,
		"shot_id":sequence,"shell_id":"ap70","armor_policy":"resolve","seed":42,
		"penetration_curve":PackedVector2Array([Vector2(0,70)]),"position_world":Vector3(0,1,0),
		"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":2,"max_distance_m":10})
	_ok(spawn.ok,"actual manager accepts recorded shot")
	var st := manager.get_projectile_state(spawn.projectile_id)
	for i in 10:
		if st.is_terminal(): break
		manager.advance_projectile(st,1.0/60,[QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)],world.get_world_3d().direct_space_state)
	_ok(st.is_terminal() and emitted.size() == 1,"actual terminal produces one frozen shot record")
	_ok(manager.shot_records.count() == 1,"manager stores one bounded record")
	return emitted[0] if not emitted.is_empty() else {}

func _record_cases(record: Dictionary) -> void:
	_ok(ShotRecordBuilder.validate(record).ok,"real shot record validates schema and geometry")
	_ok(record.is_read_only() and record.frames[0].patches[0].vertices_world.is_read_only(),"record and nested geometry are frozen")
	_ok(record.identity.seed == 42 and record.identity.shooter_id == "replay_source","record preserves frozen seed and shooter identity")
	_ok(record.contacts.size() == 1 and record.damage.size() == 1 and record.damage[0].item_id == "engine","record includes actual engine hit and no invented crew damage")
	_ok(record.damage[0].before.integrity == 100 and record.damage[0].after.integrity == 0,"record damage before/after matches actual outcome")
	var copy := manager.shot_records.get_record(0)
	copy.frames[0].patches[0].vertices_world[0] = Vector3(999,999,999)
	_ok(manager.shot_records.get_record(0).frames[0].patches[0].vertices_world[0] != Vector3(999,999,999),"consumer copy cannot rewrite stored history")
	var encoded := ShotRecordCodec.encode(record)
	_ok(encoded.ok and encoded.json.contains('"$type": "vec3"'),"JSON explicitly encodes vectors as tagged numeric arrays")
	var decoded := ShotRecordCodec.decode(encoded.json)
	_ok(decoded.ok,"real record JSON roundtrip validates")
	if decoded.ok:
		_ok(decoded.record.path.back().point_world == record.path.back().point_world,"JSON roundtrip preserves path endpoint")
		_ok(decoded.record.frames[0].boxes[0].box_world_transform == record.frames[0].boxes[0].box_world_transform,"JSON roundtrip preserves hit-time box transform")
	var invalid := record.duplicate(true)
	invalid.schema_version = 999
	_ok(not ShotRecordCodec.decode(ShotRecordCodec.encode(invalid).json).ok,"unknown schema is refused")
	invalid = record.duplicate(true)
	invalid.rules_versions.damage = "future"
	_ok(not ShotRecordCodec.decode(ShotRecordCodec.encode(invalid).json).ok,"unknown rules version is refused")
	invalid = record.duplicate(true)
	invalid.frames[0].patches[0].triangles[0] = 999
	_ok(not ShotRecordCodec.decode(ShotRecordCodec.encode(invalid).json).ok,"invalid triangle index is refused before rendering")
	invalid = record.duplicate(true)
	invalid.path[0].point_world = Vector3(INF,0,0)
	_ok(not ShotRecordCodec.encode(invalid).ok,"non-finite coordinates cannot be exported")
	invalid = record.duplicate(true)
	invalid["forbidden_node"] = actor
	_ok(not ShotRecordCodec.encode(invalid).ok,"Node references cannot enter JSON records")
	_ok(not ShotRecordCodec.decode('{"$type":"Object","v":[]}').ok,"object-style input is not deserialized")
	_ok(not ShotRecordCodec.decode("[".repeat(40)+"0"+"]".repeat(40)).ok,"excessive nesting is refused")
	var store := ShotRecordStore.new()
	for i in 25:
		var entry := record.duplicate(true)
		entry.identity.shot_id = i
		entry.record_id = ShotRecordBuilder.identity_key(entry.identity)
		store.push_bounded(entry)
	_ok(store.count() == 16 and store.get_record(0).identity.shot_id == 9,"ring buffer retains only latest 16 records")
	store.clear()
	_ok(store.count() == 0,"explicit clearing releases record buffer")

func _view_cases(record: Dictionary) -> void:
	var state_before := actor.state.damage_snapshot()
	var ammo_before := actor.gunner.inventory.snapshot()
	var hits := actor.tank.hits_taken
	var positions: Array[Vector3] = []
	for i in 10:
		_ok(view.present(record,false).ok,"replay accepts immutable real record")
		view.seek(float(record.terminal.flight_time_s))
		positions.append(view.current_position)
		_ok(view.highlighted_items == ["module:engine"],"replay highlights only actual damaged engine")
		view.close_view()
	_ok(positions.all(func(p: Vector3) -> bool: return p == positions[0]),"ten replays follow identical recorded position")
	_ok(actor.state.damage_snapshot() == state_before and actor.gunner.inventory.snapshot() == ammo_before and actor.tank.hits_taken == hits,"ten replays do not alter real damage, ammunition or hits")
	_ok(view.viewport.own_world_3d and view.viewport.world_3d != actor.get_world_3d(),"replay has an independent 3D world")
	_ok(view.find_children("*","CollisionObject3D",true,false).is_empty() and view.find_children("*","VehicleActor",true,false).is_empty(),"replay contains no collision or vehicle executors")
	var original_pose: Transform3D = record.frames[0].part_world_transforms.turret
	actor.tank.position = Vector3(50,0,40)
	actor.turret.rotation.y = PI/2
	actor.damage_layout_override.armor_patches[0].vertices_local_m[0] = Vector3(700,700,700)
	view.present(record,false)
	view.seek(float(record.terminal.flight_time_s))
	_ok(view.record.frames[0].part_world_transforms.turret == original_pose,"later target translation and turret rotation do not alter hit pose")
	_ok(view.record.frames[0].patches[0].vertices_world[0] != Vector3(700,700,700),"later shared-resource edit cannot rewrite replay geometry")
	actor.tank.position = Vector3.ZERO
	var invalid := record.duplicate(true)
	invalid.schema_version = 9
	_ok(not view.present(invalid).ok and view.error_reason == "unsupported_schema","invalid replay shows an explicit unavailable reason")

func _counter_cases() -> void:
	var stopped := _shoot(80)
	if stopped.is_empty(): return
	view.present(stopped,false)
	view.seek(float(stopped.terminal.flight_time_s))
	_ok(stopped.damage.is_empty() and view.highlighted_items.is_empty(),"unpenetrated shot has no invented internal casualty")
	_ok(view.current_position == stopped.contacts[0].impact_point,"unpenetrated replay ends exactly on armor surface")
	var ricochet := _shoot(40,78)
	view.present(ricochet,false)
	view.seek(float(ricochet.terminal.flight_time_s))
	_ok(ricochet.contacts[0].result == "ricochet" and view.current_position == ricochet.path.back().point_world,"ricochet replay uses actual reflected path endpoint")
	_ok(absf(view.current_position.x)>0.1,"reflected replay visibly leaves original straight shot line")
	var before := actor.state.damage_snapshot()
	view.clear_display()
	_ok(actor.state.damage_snapshot() == before,"closing replay does not modify combat state")
	var attempts: Array = []
	var clear_callback := func() -> void:
		attempts.append(manager.try_spawn({"round_id":1,"shooter_id":"probe","shooter_life_id":1,"shot_id":900,
			"shell_id":"ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,70)]),
			"position_world":Vector3.ZERO,"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":1,"max_distance_m":10}))
		manager.clear_records()
	manager.shot_records_cleared.connect(clear_callback)
	manager.cancel_all("cancelled_reset")
	_ok(attempts.size() == 1 and attempts[0].get("reason","") == "manager_clearing","record-clear callback cannot bypass cancellation spawn gate or recurse indefinitely")
	manager.shot_records_cleared.disconnect(clear_callback)
	sequence += 1
	var spawn := manager.try_spawn({"round_id":1,"shooter_id":"slow_fixture","shooter_life_id":1,"shot_id":sequence,
		"shell_id":"ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,70)]),
		"position_world":Vector3(0,10,0),"velocity_world":Vector3(0,0,-0.1),"gravity_world":Vector3.ZERO,"max_age_s":6,"max_distance_m":10})
	var slow := manager.get_projectile_state(spawn.projectile_id)
	for i in 601:
		if slow.is_terminal(): break
		manager.advance_projectile(slow,0.01,[],world.get_world_3d().direct_space_state)
	_ok(slow.terminal_reason == "expired_time" and slow.position_world.distance_to(Vector3(0,10,-0.6))<0.001,"recording limit does not change real projectile simulation")
	var bounded := manager.shot_records.get_record(manager.shot_records.count()-1)
	_ok(not bounded.is_empty() and not bounded.complete and bounded.unavailable_reason == "path_record_limit","record overflow is explicit and bounded")
	_ok(not view.present(bounded).ok and view.error_reason == "path_record_limit","overflow shows unavailable instead of a truncated fake replay")

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	actor = VehicleActor.new()
	world.add_child(actor)
	var defs := VehicleDefs.new()
	defs.load_defaults()
	actor.setup(defs,"player_tank","B",2,Transform3D.IDENTITY,4,null)
	actor.set_physics_process(false)
	manager = ProjectileManager.new()
	world.add_child(manager)
	manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	manager.shot_record_ready.connect(func(record: Dictionary) -> void: emitted.append(record))
	view = ReplayView.new()
	root.add_child(view)
	view.set_process(false)
	await physics_frame
	var record := _shoot()
	if record.is_empty():
		quit(1)
		return
	_record_cases(record)
	_view_cases(record)
	_counter_cases()
	actor.queue_free()
	await process_frame
	_ok(view.present(record,false).ok,"record remains replayable after actual target deletion")
	view.seek(float(record.terminal.flight_time_s))
	_ok(view.highlighted_items == ["module:engine"],"deleted target replay retains original damage explanation")
	view.clear_display()
	_ok(view._geometry.get_child_count() == 0 and view.record.is_empty(),"clearing view releases generated display geometry")
	world.queue_free()
	view.queue_free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failures])
	print("REPLAY_CHECKS_PASS" if failures == 0 else "REPLAY_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)
