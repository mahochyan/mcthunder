extends SceneTree
var count := 0
var fails := 0
var world: Node3D
var a: VehicleActor
var b: VehicleActor
var mgr: ProjectileManager
var shot := 0
var damage_events: Array[Dictionary] = []
var finishes: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _ok(ok: bool, message: String) -> void:
	count += 1
	if not ok: fails += 1
	print(("[PASS] " if ok else "[FAIL] ") + message)

func _layout(kind: String = "engine", thickness: float = 40, external: bool = false) -> VehicleLayoutDefinition:
	var snapshot := ArmorTrainingTargets.build([{"center":Vector3(0,1,-1),"thickness":thickness}])
	var layout: VehicleLayoutDefinition = snapshot.layout
	var m := ModuleVolumeDefinition.new()
	m.id = "component"
	m.kind = kind
	m.part_id = "hull"
	m.external = external
	m.local_box_transform = Transform3D(Basis.IDENTITY,Vector3(0,1,-2))
	m.size_m = Vector3(0.5,0.5,0.5)
	layout.modules.append(m)
	return layout

func _snapshot(actor: VehicleActor) -> Dictionary:
	return QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)

func _spawn(power: float = 70, offset: Vector3 = Vector3.ZERO) -> ProjectileState:
	shot += 1
	var origin := b.tank.global_transform * (Vector3(0,1,0)+offset)
	var spec := {"round_id":1,"shooter_id":"test_source","shooter_life_id":1,"shot_id":shot,
		"shell_id":"test_ap","armor_policy":"resolve","penetration_curve":PackedVector2Array([Vector2(0,power)]),
		"position_world":origin,"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,
		"max_age_s":2.0,"max_distance_m":100.0}
	var result := mgr.try_spawn(spec)
	_ok(result.get("ok",false),"actual manager accepts damage shot")
	return mgr.get_projectile_state(result.projectile_id)

func _step(st: ProjectileState, snapshots: Array = []) -> void:
	mgr.advance_projectile(st,1.0/60.0, snapshots if not snapshots.is_empty() else [_snapshot(b)],world.get_world_3d().direct_space_state)

func _apply(event: Dictionary, budget: float) -> Dictionary:
	for target in [a,b]:
		if target.entity_id == event.entity_id and target.life_id == int(event.life_id):
			return target.apply_projectile_damage(event,budget)
	return {"ok":false,"reason":"missing_target"}

func _clear() -> void:
	mgr.cancel_all("cancelled_reset")
	damage_events.clear()
	finishes.clear()

func _damage_cases() -> void:
	b.set_damage_layout(_layout())
	a.set_damage_layout(_layout())
	var st := _spawn()
	_step(st)
	_ok(b.state.module_states.component.integrity == 0,"penetrated path destroys actual engine state")
	_ok(not b.capabilities().drive and b.capabilities().fire,"engine disables propulsion but not weapon")
	_ok(a.state.module_states.component.integrity == 100,"same definition other vehicle stays healthy")
	_ok(st.damage_records.size() == 1 and st.contacts.size() == 1,"one armor contact plus one actual module event")
	_ok(absf(st.consumed_mm-50) < 0.001,"module resistance consumes remaining penetration")
	_step(st)
	_ok(st.damage_records.size() == 1,"same projectile does not damage one module twice")
	_ok(damage_events[0].before.integrity == 100 and damage_events[0].after.integrity == 0,"record preserves before/after truth")
	# Capabilities affect real drive calls rather than HUD alone.
	for i in 20:
		b.tank.apply_drive(1,1,1.0/60)
	_ok(b.tank.forward_speed == 0,"destroyed engine blocks active real driving")
	_ok(b.capabilities().fire,"engine damage does not disable breech")
	_clear()
	b.set_damage_layout(_layout("breech"))
	st = _spawn()
	_step(st)
	var rounds := b.gunner.rounds_remaining
	b.gunner.projectile_manager = mgr
	_ok(not b.gunner.try_fire() and b.gunner.rounds_remaining == rounds,"destroyed breech rejects real fire without spending ammunition")
	_ok(b.capabilities().drive,"breech destruction leaves drive available")
	b.tank.apply_drive(1,0,1.0/60)
	_ok(b.tank.forward_speed > 0,"breech-damaged real vehicle can accelerate")
	_clear()
	for thickness in [80.0,-1.0]:
		b.set_damage_layout(_layout("engine",thickness))
		st = _spawn()
		_step(st)
		_ok(b.state.module_states.component.integrity == 100 and st.damage_records.is_empty(),"unpenetrated/unknown exterior protects internal engine")
		_clear()
	b.set_damage_layout(_layout())
	st = _spawn(70,Vector3(0.3,0,0))
	_step(st)
	_ok(b.state.module_states.component.integrity == 100,"actual path 5cm outside module misses it")
	_clear()
	st = _spawn(70,Vector3(0.25,0,0))
	_step(st)
	_ok(b.state.module_states.component.integrity == 100,"grazing exact box boundary does not damage")
	_clear()
	var ext := _layout("track",80,true)
	ext.armor_patches.clear()
	b.set_damage_layout(ext)
	st = _spawn()
	_step(st)
	_ok(b.state.module_states.component.integrity == 0 and not b.capabilities().drive,"external track can be damaged without armor penetration")
	_clear()
	var none := _layout()
	none.armor_patches.clear()
	b.set_damage_layout(none)
	st = _spawn()
	_step(st)
	_ok(b.state.module_states.component.integrity == 100 and st.damage_records.is_empty(),"projectile born in open internal path without exterior authorization cannot damage")
	_clear()
	# Penetrating entity A does not authorize unrelated B at the same path.
	var first := _layout()
	first.modules.clear()
	a.set_damage_layout(first)
	b.set_damage_layout(none)
	var first_snapshot := ArmorTrainingTargets.build([{"center":b.tank.global_transform*Vector3(0,1,-1),"thickness":10}],a.entity_id,a.life_id)
	st = _spawn()
	_step(st,[first_snapshot,_snapshot(b)])
	_ok(st.contacts.size() == 1 and b.state.module_states.component.integrity == 100,"per-target exterior permission cannot leak from A to B")
	_clear()
	b.set_damage_layout(_layout())
	st = _spawn(45)
	_step(st)
	_ok(absf(b.state.module_states.component.integrity-50)<0.001,"only 5mm residual yields proportional internal damage")
	_ok(st.terminal_reason == "damage_budget_exhausted","internal resistance can stop the same projectile")
	_clear()
	b.reset_vehicle()
	_ok(b.state.module_states.component.integrity == 100 and b.capabilities().drive,"reset recreates independent healthy module state")
	var original := DamageTrainingLayout.build()
	b.set_damage_layout(original)
	_ok(b.state.crew_states.size() == 5,"training roster comes from five actual stations")
	_ok(b.state.alive_crew_count() == 5 and not b.state.destroyed,"five crew start healthy")
	var death_count := 0
	for person in ["assistant_driver","commander","loader","gunner","driver"]:
		var ev := {"kind":"crew","crew_id":person}
		var delta := DamageResolver.resolve(ev,70,b.state.damage_snapshot())
		var commit := b.state.apply_damage_delta("crew_" + person,delta)
		if commit.get("newly_destroyed",false):
			death_count += 1
		if person == "loader":
			_ok(b.state.alive_crew_count() == 2 and not b.state.destroyed,"two crew do not trigger count-based defeat")
			_ok(is_equal_approx(b.capabilities().reload_rate,1.0/1.6),"incapacitated loader makes reload duration 1.6 times normal")
		if person == "gunner":
			_ok(b.state.alive_crew_count() == 1 and b.state.destroyed,"one remaining crew triggers defeat")
	_ok(death_count == 1,"low-crew defeat committed exactly once")
	_ok(not b.state.assign_crew("driver","commander"),"incapacitated crew cannot be assigned")
	b.reset_vehicle()
	_ok(b.state.assign_crew("driver","commander"),"living person can occupy another role")
	_ok(b.state.crew_assignments.commander == "" and b.state.crew_assignments.driver == "commander","one person never occupies two roles")
	b.state.module_states.engine.integrity = 0 # Pure snapshot isolation test, not a shot claim.
	_ok(original.modules[0].max_integrity == 100,"mutable instance damage does not rewrite shared layout")
	_clear()

func _rotated_and_runtime_cases() -> void:
	b.reset_vehicle()
	var layout := _layout("breech")
	var mod: ModuleVolumeDefinition = layout.modules[0]
	mod.part_id = "turret"
	mod.local_box_transform.origin = Vector3(0,0,-2)
	var person := CrewStationDefinition.new()
	person.id = "gunner"
	person.role = "gunner"
	person.part_id = "turret"
	person.local_box_transform.origin = Vector3(1,0,-2)
	person.size_m = Vector3(0.3,0.3,0.3)
	layout.crew_stations.append(person)
	b.turret.rotation.y = PI/2
	var center := b.turret.global_transform * mod.local_box_transform.origin
	var local_center := b.tank.global_transform.affine_inverse()*center
	var patch_layout: VehicleLayoutDefinition = ArmorTrainingTargets.build([
		{"center":local_center+Vector3(0,0,1),"thickness":10}]).layout
	layout.armor_patches = patch_layout.armor_patches
	b.set_damage_layout(layout)
	var st := _spawn(70,local_center-Vector3(0,1,0)+Vector3(0,0,2))
	_step(st)
	_ok(b.state.module_states.component.integrity == 0,"90-degree turret uses actual rotated module box")
	_ok(not b.state.crew_states.gunner.alive,"90-degree turret uses actual rotated crew station")
	_ok(st.damage_records.size() == 2,"rotated module and crew each receive exactly one path event")
	if st.damage_records.size() == 2:
		_ok(st.damage_records[0].box_world_transform.origin.distance_to(center)<0.001,"damage record freezes actual part pose")
	_clear()
	b.reset_vehicle()
	b.set_damage_layout(_layout("turret_drive"))
	st = _spawn()
	_step(st)
	var before := b.turret.rotation
	b.turret.set_aim_point(b.tank.global_position+Vector3(50,20,0))
	b.turret._process(1.0)
	_ok(b.turret.rotation == before,"destroyed turret drive blocks actual tracking")
	_clear()
	b.reset_vehicle()
	b.set_damage_layout(DamageTrainingLayout.build())
	var delta := DamageResolver.resolve({"kind":"crew","crew_id":"loader"},70,b.state.damage_snapshot())
	b.state.apply_damage_delta("loader_timer",delta)
	b.gunner.cooldown_left = 2.0 # Deterministic timer fixture, separate from normal player demonstration.
	b.gunner.advance_timers(1.0)
	_ok(is_equal_approx(b.gunner.cooldown_left,1.375),"missing loader changes real cooldown clock")
	var dup := b.state.apply_damage_delta("loader_timer",delta)
	_ok(not dup.ok,"same damage event ID is rejected")
	_clear()
	b.set_damage_layout(_layout())
	var reset_on_damage := func(_r: Dictionary) -> void:
		mgr.cancel_all("cancelled_reset")
		b.reset_vehicle()
	mgr.projectile_damage.connect(reset_on_damage)
	st = _spawn()
	_step(st)
	_ok(st.is_terminal() and st.terminal_reason == "cancelled_reset","damage callback reset terminates once")
	_ok(b.state.module_states.component.integrity == 100 and finishes.size() == 1,"reset callback cannot leave late damage or duplicate finish")
	mgr.projectile_damage.disconnect(reset_on_damage)
	_clear()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var defs := VehicleDefs.new()
	_ok(defs.load_defaults().ok,"load real definitions")
	a = VehicleActor.new()
	b = VehicleActor.new()
	world.add_child(a)
	world.add_child(b)
	_ok(a.setup(defs,"player_tank","A",1,Transform3D(Basis.IDENTITY,Vector3(20,0,0)),2,null).ok,"create real actor A")
	_ok(b.setup(defs,"player_tank","B",2,Transform3D.IDENTITY,4,null).ok,"create real actor B")
	mgr = ProjectileManager.new()
	world.add_child(mgr)
	mgr.set_physics_process(false)
	mgr.damage_handler = Callable(self,"_apply")
	mgr.projectile_damage.connect(func(r: Dictionary) -> void: damage_events.append(r))
	mgr.projectile_finished.connect(func(r: Dictionary) -> void: finishes.append(r))
	await physics_frame
	_damage_cases()
	_rotated_and_runtime_cases()
	world.queue_free()
	await process_frame
	print("=== 结果: %d 项检查, %d 失败 ===" % [count,fails])
	print("DAMAGE_CHECKS_PASS" if fails == 0 else "DAMAGE_CHECKS_FAIL")
	quit(0 if fails == 0 else 1)
