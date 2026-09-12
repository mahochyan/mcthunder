extends SceneTree
## WT010 bounded translation: actual authority snapshots, unchanged thin
## geometry, time-correlated queries and real ProjectileManager advancement.
## Rotation and a projectile with a finite radius are not asserted complete.

const DT := 1.0 / 60.0

class MotionStage extends Node:
	var target: TankVehicle
	var manager: ProjectileManager
	var spec: Dictionary
	var end_x := 0.0
	var reset_generation := false
	var phase := 0
	var seed_tick := -1
	var birth_tick := -1
	var move_tick := -1
	var born_unchanged := false
	var done := false
	var spawned: Dictionary = {}
	var state: ProjectileState
	func _physics_process(_delta: float) -> void:
		match phase:
			0:
				seed_tick = Engine.get_physics_frames()
			1:
				birth_tick = Engine.get_physics_frames()
				spawned = manager.try_spawn(spec)
				if spawned.get("ok", false):
					state = manager.get_projectile_state(spawned.projectile_id)
			2:
				move_tick = Engine.get_physics_frames()
				born_unchanged = state != null and state.position_world == Vector3.ZERO and state.age_s == 0.0
				target.position.x = end_x
				if reset_generation:
					target.state_generation += 1
			3:
				manager.set_physics_process(false)
				done = true
				set_physics_process(false)
		phase += 1

var checks := 0
var failures := 0
var layout: VehicleLayoutDefinition

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)

func tick() -> void:
	await physics_frame
	await process_frame

func make_layout(boxes: bool = false) -> VehicleLayoutDefinition:
	var result := VehicleLayoutDefinition.new()
	result.id = "TEST_moving_thin_target"
	result.content_tier = "test"
	var part := LayoutPartDefinition.new()
	part.id = "hull"
	result.parts.append(part)
	var patch := ArmorPatchDefinition.new()
	patch.id = "thin_front"
	patch.part_id = "hull"
	patch.plate_group_id = "TEST_ONLY"
	patch.vertices_local_m = PackedVector3Array([Vector3(-0.03, -1, 0), Vector3(0.03, -1, 0), Vector3(0.03, 1, 0), Vector3(-0.03, 1, 0)])
	patch.triangles = PackedInt32Array([0, 1, 2, 0, 2, 3])
	patch.outward_normal_local = Vector3.BACK
	patch.evidence_keys = PackedStringArray(["EV-TEST-FIXTURE"])
	result.armor_patches.append(patch)
	if boxes:
		var module := ModuleVolumeDefinition.new()
		module.id = "thin_module"
		module.kind = "engine"
		module.part_id = "hull"
		module.size_m = Vector3(0.06, 2, 0.08)
		result.modules.append(module)
		var crew := CrewStationDefinition.new()
		crew.id = "thin_crew"
		crew.part_id = "hull"
		crew.role = "gunner"
		crew.size_m = Vector3(0.06, 2, 0.08)
		result.crew_stations.append(crew)
	return result

func snapshot(x: float, z: float = -6.3, generation: int = 0, basis: Basis = Basis.IDENTITY, source_layout: VehicleLayoutDefinition = null) -> Dictionary:
	var geometry := layout if source_layout == null else source_layout
	var result := QuerySnapshotBuilder.build_identity_snapshot("target", 10, "TEST", geometry, {"hull": Transform3D(basis, Vector3(x, 0, z))})
	result.target_generation = generation
	return result

func request(from: Vector3 = Vector3.ZERO, to: Vector3 = Vector3(0, 0, -10), fractions: Vector2 = Vector2(0, 1)) -> Dictionary:
	return {"query_id": "moving_contact", "from_world": from, "to_world": to, "motion_fraction": fractions, "include_modules": true, "include_crew": true}

func run() -> void:
	layout = make_layout()
	check_query_motion()
	check_static_compatibility()
	check_relative_stationary_boxes()
	check_identity_boundaries()
	await check_real_manager()
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks, failures])
	print("MOVING_CONTACT_CHECKS_PASS" if failures == 0 else "MOVING_CONTACT_CHECKS_FAIL")
	quit(0 if failures == 0 else 1)

func check_query_motion() -> void:
	var old := snapshot(-1.26)
	var current := snapshot(0.74)
	var old_query := ShotQueryService.query(request(), [old])
	var end_query := ShotQueryService.query(request(), [current])
	check(old_query.complete and end_query.complete and old_query.events.is_empty() and end_query.events.is_empty(), "both endpoint-only snapshots miss the unexpanded 6cm-wide target")
	var bound := TranslationSweep.bind([old], [current], true, DT)
	var swept := ShotQueryService.query(request(), bound)
	var selected := ExternalContactSelector.select_contact(swept)
	check(selected.status == "vehicle", "time-correlated translation detects target crossing between both missed endpoint poses")
	if selected.status == "vehicle":
		var event: Dictionary = selected.event
		check(absf(event.t - 0.63) < 0.00001 and event.point_world.distance_to(Vector3(0, 0, -6.3)) < 0.0001, "contact time and world point describe the same actual crossing")
		check(absf(event.distance_m - 6.3) < 0.0001, "contact distance remains projectile world travel, not the longer relative-motion line")
		check(absf(event.part_world_transform.origin.x) < 0.0001 and absf(event.motion_fraction - 0.63) < 0.00001, "event carries the target authority transform at impact rather than step end")
	var wrong_time := TranslationSweep.bind([snapshot(-0.5)], [snapshot(1.5)], true, DT)
	check(ShotQueryService.query(request(), wrong_time).events.is_empty(), "target crossing the same spatial path at the wrong time does not create a hit")
	var first_half := ShotQueryService.query(request(Vector3.ZERO, Vector3(0, 0, -5), Vector2(0, 0.5)), bound)
	var last_half := ShotQueryService.query(request(Vector3(0, 0, -5), Vector3(0, 0, -10), Vector2(0.5, 1)), bound)
	check(first_half.events.is_empty() and not last_half.events.is_empty() and absf(last_half.events[0].distance_m + 5.0 - 6.3) < 0.0001, "splitting projectile chords preserves crossing time and accumulated world distance")
	var occluded := request()
	occluded.world_stop_distance_m = 2.0
	var blocked := ShotQueryService.query(occluded, bound)
	check(ExternalContactSelector.select_contact(blocked).status == "world" and blocked.events[0].occluded_by_world, "earlier static world wall still wins over a later moving armor contact")
	var box_layout := make_layout(true)
	var boxes := TranslationSweep.bind([snapshot(-1.26, -6.3, 0, Basis.IDENTITY, box_layout)], [snapshot(0.74, -6.3, 0, Basis.IDENTITY, box_layout)], true, DT)
	var volumes := ShotQueryService.query(request(), boxes)
	check(volumes.complete and volumes.volume_intervals.size() == 2, "unchanged module and crew boxes use the same translational time interval")
	for interval in volumes.volume_intervals:
		check(interval.box_size_m == Vector3(0.06, 2, 0.08) and interval.distance_enter_m < 6.3 and interval.distance_exit_m > 6.3 and absf(interval.box_world_transform.origin.x) < 0.03, "moving volume entry/exit retains exact size and contact-time pose: " + str(interval.kind))
	var frozen := TranslationSweep.frame_at(bound, 0.63)
	check(absf(frozen[0].part_world_transforms.hull.origin.x) < 0.0001 and frozen[0].part_world_transforms.hull.origin.z == current.part_world_transforms.hull.origin.z, "replay snapshot is frozen at actual contact time")
	old.part_world_transforms.hull = Transform3D(Basis.IDENTITY, Vector3(999, 0, 0))
	current.part_world_transforms.hull = Transform3D(Basis.IDENTITY, Vector3(999, 0, 0))
	check(ExternalContactSelector.select_contact(ShotQueryService.query(request(), bound)).status == "vehicle", "later producer mutation cannot change a bound pair of snapshots")
	for fraction in [Vector2(-0.1, 0.5), Vector2(0.8, 0.2), Vector2(0, 1.1), Vector2(NAN, 1)]:
		check(not ShotQueryService.query(request(Vector3.ZERO, Vector3(0, 0, -10), fraction), bound).ok, "invalid motion interval is rejected")

func check_static_compatibility() -> void:
	var unchanged := snapshot(0.0)
	var bound := TranslationSweep.bind([unchanged], [unchanged], true, DT)
	check(bound[0].motion_previous_transforms.is_empty(), "unchanged target is not registered as translated motion")
	var early := ShotQueryService.query(request(Vector3.ZERO, Vector3(0, 0, -10), Vector2(0, 0.5)), bound)
	var late := ShotQueryService.query(request(Vector3.ZERO, Vector3(0, 0, -10), Vector2(0.5, 1)), bound)
	check(early.events.size() == 1 and late.events.size() == 1, "static geometry still produces its original single deduplicated surface event")
	if early.events.is_empty() or late.events.is_empty():
		return
	check(not early.events[0].has("motion_fraction") and not late.events[0].has("motion_fraction"), "static events preserve original fields instead of acquiring artificial motion fractions")
	var state := ProjectileState.new()
	var first := ShotRecordBuilder.capture_frame(state, early.events[0], bound)
	var second := ShotRecordBuilder.capture_frame(state, late.events[0], bound)
	check(first >= 0 and first == second and state.replay_frames.size() == 1, "static same-tick contacts retain shared replay frames and do not consume the motion frame budget")

func check_relative_stationary_boxes() -> void:
	var boxes := make_layout(true)
	boxes.armor_patches.clear()
	var earlier := snapshot(2.0, 0.0, 0, Basis.IDENTITY, boxes)
	var later := snapshot(2.0, -4.0, 0, Basis.IDENTITY, boxes)
	var outside := TranslationSweep.bind([earlier], [later], true, DT)
	var miss := ShotQueryService.query(request(Vector3.ZERO, Vector3(0, 0, -4)), outside)
	check(miss.ok and miss.complete and miss.events.is_empty() and miss.volume_intervals.is_empty(), "same-velocity remote boxes remain a clear miss instead of a zero-relative-segment query failure")
	earlier = snapshot(0.0, 0.0, 0, Basis.IDENTITY, boxes)
	later = snapshot(0.0, -4.0, 0, Basis.IDENTITY, boxes)
	var inside := TranslationSweep.bind([earlier], [later], true, DT)
	var contained := ShotQueryService.query(request(Vector3.ZERO, Vector3(0, 0, -4)), inside)
	check(contained.ok and contained.complete and contained.events.is_empty() and contained.volume_intervals.size() == 2, "same-velocity interior occupancy has continuous intervals without fabricated entry or exit boundaries")
	for interval in contained.volume_intervals:
		check(interval.starts_inside and interval.t_enter == 0.0 and interval.t_exit == 1.0 and interval.distance_exit_m == 4.0, "co-moving interior interval retains projectile world distance: " + str(interval.kind))

func check_identity_boundaries() -> void:
	var old := snapshot(-1.26)
	for boundary in ["life", "generation", "layout_revision", "layout_resource", "tick_gap", "long_step", "teleport", "rotation"]:
		var current := snapshot(0.74)
		var adjacent := true
		var delta := DT
		match boundary:
			"life": current.life_id = 11
			"generation": current.target_generation = 1
			"layout_revision": current.layout_revision = 2
			"layout_resource": current.layout = make_layout()
			"tick_gap": adjacent = false
			"long_step": delta = 0.2
			"teleport": current.part_world_transforms.hull = Transform3D(Basis.IDENTITY, Vector3(20, 0, -6.3))
			"rotation": current.part_world_transforms.hull = Transform3D(Basis(Vector3.UP, 0.1), Vector3(0.74, 0, -6.3))
		var bound := TranslationSweep.bind([old], [current], adjacent, delta)
		check(bound[0].motion_previous_transforms.is_empty(), "unsupported or discontinuous target pose is not joined by an invented sweep: " + boundary)
		if boundary in ["rotation", "teleport"]:
			check(not bound[0].motion_diagnostics.is_empty(), "static fallback states its incomplete continuous coverage: " + boundary)

func scenario(start_x: float, end_x: float, z: float = -6.3, max_age: float = 1.0, max_distance: float = 30.0, blocking_wall: bool = false, reset_generation: bool = false, effect_policy: String = "kinetic") -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var target := TankVehicle.new()
	target.presentation_enabled = false
	target.entity_id = "target"
	target.life_id = 10
	holder.add_child(target)
	target.collision_layer = 0
	target.position = Vector3(start_x, 0, z)
	# Deliberately unrelated visual position: the real snapshot builder reads
	# HullFrame/vehicle authority, never this presentation descendant.
	var visual := Node3D.new()
	target.hull_frame.add_child(visual)
	visual.position = Vector3(1000, 1000, 1000)
	var manager := ProjectileManager.new()
	manager.presentation_enabled = false
	holder.add_child(manager)
	manager.set_physics_process(false)
	manager.snapshot_provider = func() -> Array: return [QuerySnapshotBuilder.build_from_vehicle(target, layout)]
	var terminals: Array[Dictionary] = []
	manager.projectile_finished.connect(func(record: Dictionary) -> void: terminals.append(record.duplicate(true)))
	if blocking_wall:
		TerrainFixtures.box(holder, Vector3(0, 0, -2.05), Vector3(4, 4, 0.1))
	await tick()
	# Real priority stages run for every physics tick, including catch-up ticks
	# in one render frame. A manual await/process callback can skip those ticks.
	var stage := MotionStage.new()
	stage.target = target
	stage.manager = manager
	stage.end_x = end_x
	stage.reset_generation = reset_generation
	stage.process_physics_priority = SimulationPhases.VEHICLES
	stage.spec = {"round_id": 1, "shooter_id": "source", "shooter_life_id": 1, "shot_id": 1,
		"shell_id": "TEST_MOVING_CONTACT", "armor_policy": "resolve" if effect_policy == "internal_burst" else "legacy_contact_only", "test_only": true,
		"effect_policy": effect_policy, "penetration_curve": PackedVector2Array([Vector2(0, 100), Vector2(1000, 100)]),
		"position_world": Vector3.ZERO, "velocity_world": Vector3(0, 0, -600), "gravity_world": Vector3.ZERO,
		"max_age_s": max_age, "max_distance_m": max_distance}
	holder.add_child(stage)
	manager.set_physics_process(true)
	for _i in 10:
		await tick()
		if stage.done:
			break
	check(stage.done and stage.spawned.get("ok", false), "actual moving-contact fixture projectile is admitted")
	check(stage.born_unchanged, "birth tick does not advance or manufacture a hit")
	check(stage.move_tick == stage.birth_tick + 1 and stage.birth_tick == stage.seed_tick + 1, "authority sample, birth and target motion execute on consecutive physics ticks")
	var result := {"terminals": terminals.duplicate(true), "state": stage.state}
	holder.free()
	await process_frame
	return result

func check_real_manager() -> void:
	var crossed := await scenario(-1.26, 0.74)
	check(crossed.terminals.size() == 1 and crossed.terminals[0].reason == "impact_vehicle", "real manager first flight tick detects high-speed thin target crossing between endpoint misses")
	if not crossed.terminals.is_empty():
		var record: Dictionary = crossed.terminals[0]
		check(record.target_id == "target" and absf(record.flight_time_s - 6.3 / 600.0) < 0.00001 and absf(record.travelled_m - 6.3) < 0.0001, "real terminal identity, lifetime and path distance use the same physical crossing")
		check(record.impact_point.distance_to(Vector3(0, 0, -6.3)) < 0.0001, "real projectile impact is on the moving thin surface at contact time")
		var state: ProjectileState = crossed.state
		check(state.contacts.size() == 1 and state.replay_frames.size() == 1 and absf(state.replay_frames[0].part_world_transforms.hull.origin.x) < 0.0001, "actual contact and replay use authority pose at impact despite unrelated visual geometry")
	var missed := await scenario(-0.5, 1.5)
	check(missed.terminals.is_empty() and is_equal_approx(missed.state.travelled_m, 10.0), "real manager rejects different-time crossing instead of intersecting a spatial union")
	var walled := await scenario(-1.26, 0.74, -6.3, 1.0, 30.0, true)
	check(walled.terminals.size() == 1 and walled.terminals[0].reason == "impact_world" and walled.state.contacts.is_empty(), "real near wall prevents later moving-target damage")
	var lifetime := await scenario(-0.6, 1.4, -3.0, DT * 0.5)
	check(lifetime.terminals.size() == 1 and lifetime.terminals[0].reason == "impact_vehicle" and absf(lifetime.terminals[0].flight_time_s - 0.005) < 0.00001, "lifetime clipping keeps target time on the full authority tick rather than stretching its motion")
	var distance := await scenario(-0.6, 1.4, -3.0, 1.0, 4.0)
	check(distance.terminals.size() == 1 and distance.terminals[0].reason == "impact_vehicle" and absf(distance.terminals[0].travelled_m - 3.0) < 0.0001, "weapon path clipping preserves the substep's actual target time")
	var reset := await scenario(-1.26, 0.74, -6.3, 1.0, 30.0, false, true)
	check(reset.terminals.is_empty(), "actual generation change cannot sweep old life geometry across the new target")
	var burst := await scenario(-1.26, 0.74, -6.3, 1.0, 30.0, false, false, "internal_burst")
	check(burst.state.effect_policy == "internal_burst" and burst.terminals.is_empty(), "internal-burst policy retains the existing static path until its entire moving inside calculation is implemented")
	# The same target can have multiple distinct contact poses in one tick.
	var state := ProjectileState.new()
	var moving := TranslationSweep.bind([snapshot(-1.26)], [snapshot(0.74)], true, DT)
	var first := {"entity_id": "target", "life_id": 10, "target_generation": 0, "motion_fraction": 0.4}
	var second := first.duplicate(true)
	second.motion_fraction = 0.8
	var first_frame := ShotRecordBuilder.capture_frame(state, first, TranslationSweep.frame_at(moving, 0.4))
	var second_frame := ShotRecordBuilder.capture_frame(state, second, TranslationSweep.frame_at(moving, 0.8))
	check(first_frame >= 0 and second_frame >= 0 and first_frame != second_frame and state.replay_frames[first_frame].part_world_transforms.hull.origin != state.replay_frames[second_frame].part_world_transforms.hull.origin, "same-tick replay cache distinguishes separate moving contact times")
