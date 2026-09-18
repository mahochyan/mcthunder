extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05 design point 1: the terminal vocabulary and what it means for continuing flight. The order
## asks for not_penetrated / perforated_stop / penetrated / ricochet and the like to be tied to actual continue-flight and
## after-effect behaviour, so this probe enumerates the resolver's verdicts against one synthetic event and then checks the
## manager's real behaviour for two contrasting shots.
##
## The judgment, declared before measuring, and CORRECTED once by physics rather than by convenience: the first version said
## only a penetration may continue the flight, and the resolver returned continue_flight true for a ricochet. That is not a
## defect - a ricocheting round bounces and flies on, which is why the resolver reflects its direction off the normal - so
## the declaration was wrong, not the code. The physically correct invariant is that a PENETRATION and a RICOCHET continue,
## and that everything else - stopped, perforated_stop, unknown material, invalid layer, unresolved - does not. The ricochet
## leg additionally checks the reflection itself, so "it continues" is backed by a reason rather than by preference.

const CD5_SEED := 11100
const CD5_STEP := 1.0/240.0

func _cd5_event(thickness_mm: float, material: String, angle_deg: float) -> Dictionary:
	var normal := Vector3(0,sin(deg_to_rad(angle_deg)),cos(deg_to_rad(angle_deg)))
	return {"has_thickness":true,"thickness_mm":thickness_mm,"thickness_status":"estimated","material_kind":material,
		"response_profile":{},"normal_world":normal}

func _cd5_budget(base_mm: float, kind: String) -> Dictionary:
	var profile := {"version":ArmorImpactProfile.VERSION,"family":("APHE" if kind=="internal_burst" else "AP"),
		"provenance":"game_rule","reason":"CD05-T05 probe fixture: terminal vocabulary audit",
		"normalization_deg":4.0,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}
	return {"base_mm":base_mm,"impact_profile":profile,"effect_policy":kind,"caliber_mm":120.0}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_t05_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 T05 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	# ── The resolver's verdict table, straight from the resolver, one synthetic event per case.
	var cases := [
		{"tag":"penetrated (thin plate)","base":400.0,"thickness":100.0,"material":"rolled","angle":0.0},
		{"tag":"stopped (weak budget)","base":50.0,"thickness":100.0,"material":"rolled","angle":0.0},
		{"tag":"perforated_stop (exact equality)","base":100.0,"thickness":100.0,"material":"rolled","angle":0.0},
		{"tag":"ricochet (steep)","base":400.0,"thickness":100.0,"material":"rolled","angle":75.0},
		{"tag":"unknown material","base":400.0,"thickness":100.0,"material":"unobtainium","angle":0.0},
	]
	print("[CD05 T05] resolver verdict table (judgment: penetration AND ricochet continue; everything else does not)")
	var bad_continue := 0
	var ricochet_reflected := false
	for row in cases:
		var event := _cd5_event(float(row.thickness),str(row.material),float(row.angle))
		var result := ArmorResolver.resolve(event,Vector3.FORWARD,_cd5_budget(float(row.base),str(row.kind if row.has("kind") else "kinetic")))
		var verdict := str(result.get("result",""))
		var cont := bool(result.get("continue_flight",false))
		var may_continue := verdict in ["penetrated","ricochet"]
		print("[CD05 T05]   %-34s => verdict=%-18s continue_flight=%-5s effective=%.3f consumed=%.3f" % [
			str(row.tag),verdict,str(cont),float(result.get("effective_mm",-1.0)),float(result.get("consumed_mm",-1.0))])
		if cont and not may_continue: bad_continue += 1
		if not cont and may_continue: bad_continue += 1
		if verdict == "ricochet":
			var reflected: Vector3 = result.get("direction",Vector3.ZERO)
			# A ricochet must be a proper mirror reflection: the component along the normal reverses and the tangential part
			# is preserved. My first version simply asked for a positive Z, which is wrong because this mirror is mostly the
			# Y axis, and the returned (0, 0.5, -0.866) is exactly d - 2(d.n)n for the incoming (0,0,-1).
			var incoming := Vector3.FORWARD
			var normal := (event.normal_world as Vector3).normalized()
			var normal_flipped: bool = incoming.dot(normal) < 0.0 and reflected.dot(normal) > 0.0
			var tangential_kept: bool = (incoming-incoming.dot(normal)*normal).normalized().dot((reflected-reflected.dot(normal)*normal).normalized()) > 0.999
			ricochet_reflected = normal_flipped and tangential_kept
			print("[CD05 T05]   ricochet direction=%s ; d.n=%.4f reflected.n=%.4f ; tangential dot=%.6f" % [
				str(reflected),incoming.dot(normal),reflected.dot(normal),
				(incoming-incoming.dot(normal)*normal).normalized().dot((reflected-reflected.dot(normal)*normal).normalized())])
	check(bad_continue==0,
		"CD05 T05 continue_flight is exactly penetration-or-ricochet: %d verdicts disagreed" % bad_continue)
	check(ricochet_reflected,
		"CD05 T05 the ricochet is a real bounce rather than a continue flag with no motion: its direction reverses along the normal")

	# ── The manager's real behaviour, two contrasting shots at a plate the resolver is asked about first.
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd005_t05_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD05 T05 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd005_t05",1,Transform3D.IDENTITY,2,null).ok,"CD05 T05 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	for entry in [{"tag":"strong budget","curve":PackedVector2Array([Vector2(0,900),Vector2(2000,900)]),"expect_continue":true},
			{"tag":"weak budget","curve":PackedVector2Array([Vector2(0,30),Vector2(2000,30)]),"expect_continue":false}]:
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		manager.damage_handler = Callable(actor,"apply_projectile_damage")
		var shell: ShellDefinition = actor.gunner.shell_options[0]
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,_single_plate_layout(1))
		snapshot["entity_id"] = "cd005_t05_target"; snapshot["life_id"] = 41
		var plate_basis := Basis(Vector3.UP,deg_to_rad(90.0))
		snapshot["part_world_transforms"]["hull"] = Transform3D(plate_basis,Vector3(0,2.0,-10.0))
		var spec := {"round_id":CD5_SEED+int(entry.curve[0].y),"shooter_id":"cd005_t05","shooter_life_id":1,
			"shot_id":CD5_SEED+int(entry.curve[0].y),"shell_id":shell.id+"_cd5",
			"effect_policy":"kinetic","armor_policy":"resolve","impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
			"caliber_mm":shell.caliber_mm,"penetration_curve":entry.curve,
			"position_world":Vector3(0,2,-5),"velocity_world":Vector3(0,0,-900),"gravity_world":Vector3(0,-9.81,0),
			"max_age_s":0.2,"max_distance_m":100.0}
		var spawned := manager.try_spawn(spec)
		if not spawned.get("ok",false):
			print("[CD05 T05] %s launch refused: %s" % [str(entry.tag),str(spawned.get("reason",""))])
			manager.queue_free(); continue
		var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
		var space := world.get_world_3d().direct_space_state
		var z_at_contact := 0.0
		var verdict := ""
		for i in 60:
			if state.is_terminal(): break
			manager.advance_projectile(state,CD5_STEP,[snapshot],space)
			if len(state.contacts) > 0 and verdict.is_empty():
				verdict = str(state.contacts[0].get("result",""))
				z_at_contact = state.position_world.z
		var continued := absf(state.position_world.z) > absf(z_at_contact)+0.05
		print("[CD05 T05] manager %-14s => verdict=%-12s terminal=%s reason=%-18s travelled_after_contact=%.4f m" % [
			str(entry.tag),verdict,str(state.is_terminal()),str(state.terminal_reason),absf(state.position_world.z)-absf(z_at_contact)])
		check(verdict==("penetrated" if bool(entry.expect_continue) else "stopped"),
			"CD05 T05 the %s shot's verdict is the one the curve implies: %s" % [str(entry.tag),verdict])
		check(continued==bool(entry.expect_continue),
			"CD05 T05 the manager's real behaviour matches continue_flight for the %s shot: continued=%s expected=%s" % [str(entry.tag),str(continued),str(entry.expect_continue)])
		manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_TERMINAL_VOCABULARY_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
