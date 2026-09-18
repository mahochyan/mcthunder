extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD04 design point 4, as an audit rather than an assertion:
##   L1 the air leg and the contact leg are recorded SEPARATELY - the distance flown and the thickness consumed come from
##      different fields and are not the same number wearing two names.
##   L2 long range is not double penalised: with drag declared the armour verdict and the effective thickness at a given
##      range must be IDENTICAL to the vacuum case, because the available penetration comes from the range curve alone; only
##      the residual speed may differ. If a speed-derived reduction were also folded into the budget, these would diverge.
##   L3 gravity changing the speed is not free energy: with the same gravity, a drag round must always be slower than the
##      vacuum round at the same instant, level and descending alike.

const T04D_SEED := 9100
const T04D_DRAG_K := 1.40e-4
const T04D_STEP := 1.0/240.0

func _t04d_layout(origin_z: float, y: float) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd004_t04d_plate"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	var patch := ArmorPatchDefinition.new()
	patch.id = "cd004_t04d_single"; patch.plate_group_id = "cd004_t04d_zone"; patch.part_id = "hull"
	patch.vertices_local_m = PackedVector3Array([Vector3(0,-1,-1),Vector3(0,-1,1),Vector3(0,1,-1),Vector3(0,1,1)])
	patch.triangles = PackedInt32Array([0,2,1, 1,2,3])
	patch.outward_normal_local = Vector3(-1,0,0)
	patch.has_thickness = true; patch.thickness_mm = 100.0; patch.material_kind = "rolled"
	patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
	layout.armor_patches.append(patch)
	return layout

func _t04d_fire(actor: VehicleActor, world: Node3D, drag_k: float, round_id: int) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var layout := _t04d_layout(0.0,2.0)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	snapshot["entity_id"] = "cd004_t04d_target"; snapshot["life_id"] = 31
	var plate_basis := Basis(Vector3.UP,deg_to_rad(90.0))
	snapshot["part_world_transforms"]["hull"] = Transform3D(plate_basis,Vector3(0,2.0,-10.0))
	var spec := {"round_id":round_id,"shooter_id":"cd004_t04d","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id+"_t04d",
		"effect_policy":"kinetic","armor_policy":"resolve","impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,"drag_k_per_m":drag_k,
		"position_world":Vector3(0,2,-5),"velocity_world":Vector3(0,0,-900),"gravity_world":Vector3(0,-9.81,0),
		"max_age_s":0.2,"max_distance_m":100.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		print("[CD004 T04d] launch refused: %s" % str(spawned.get("reason","")))
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 60:
		if state.is_terminal(): break
		manager.advance_projectile(state,T04D_STEP,[snapshot],space)
		if len(state.contacts) > 0: break
	var contacts := len(state.contacts)
	var out := {"ok":true,"contacts":contacts,"travelled_m":state.travelled_m,"consumed_mm":state.consumed_mm,
		"residual_speed":state.velocity_world.length(),
		"result":str(state.contacts[0].get("result","")) if contacts > 0 else "",
		"effective_mm":float(state.contacts[0].get("effective_mm",-1.0)) if contacts > 0 else -1.0,
		"contact_consumed_mm":float(state.contacts[0].get("consumed_mm",-1.0)) if contacts > 0 else -1.0}
	manager.queue_free()
	return out

## The same integration with and without drag, from an arbitrary launch, stopped at the same instant.
func _t04d_speed(muzzle: Vector3, launch: Vector3, gravity: Vector3, drag_k: float, total_time: float) -> float:
	var position := muzzle
	var velocity := launch
	var remaining := total_time
	while remaining > BallisticMath.TIME_EPS:
		var step := minf(T04D_STEP,remaining)
		var adv := BallisticMath.advance_profile(position,velocity,gravity,drag_k,step)
		if not adv.get("ok",false): break
		position = adv.position
		velocity = adv.velocity
		remaining -= step
	return velocity.length()

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd004_t04d_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD004 T04d creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd004_t04d_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD004 T04d the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd004_t04d",1,Transform3D.IDENTITY,2,null).ok,"CD004 T04d the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	var vacuum := _t04d_fire(actor,world,0.0,T04D_SEED+1)
	var drag := _t04d_fire(actor,world,T04D_DRAG_K,T04D_SEED+2)
	check(bool(vacuum.get("ok",false)) and bool(drag.get("ok",false)),"CD004 T04d both the vacuum and the drag shot launch")
	print("[CD004 T04d L1] vacuum: travelled=%.4f consumed=%.3f contact_consumed=%.3f ; drag: travelled=%.4f consumed=%.3f contact_consumed=%.3f" % [
		float(vacuum.get("travelled_m",-1.0)),float(vacuum.get("consumed_mm",-1.0)),float(vacuum.get("contact_consumed_mm",-1.0)),
		float(drag.get("travelled_m",-1.0)),float(drag.get("consumed_mm",-1.0)),float(drag.get("contact_consumed_mm",-1.0))])
	check(float(drag.get("travelled_m",0.0))>1.0 and float(drag.get("consumed_mm",0.0))>1.0,
		"CD004 T04d L1 the air leg and the contact leg are both recorded and both non-zero")
	check(absf(float(drag.get("travelled_m",0.0))-float(drag.get("consumed_mm",0.0)))>1.0,
		"CD004 T04d L1 they are different quantities, not one number wearing two names: travelled %.3f vs consumed %.3f" % [float(drag.get("travelled_m",-1.0)),float(drag.get("consumed_mm",-1.0))])

	print("[CD004 T04d L2] verdict vacuum=%s/%.3f mm ; drag=%s/%.3f mm ; residual vacuum=%.3f drag=%.3f" % [
		str(vacuum.get("result","")),float(vacuum.get("effective_mm",-1.0)),str(drag.get("result","")),float(drag.get("effective_mm",-1.0)),
		float(vacuum.get("residual_speed",-1.0)),float(drag.get("residual_speed",-1.0))])
	check(str(vacuum.get("result",""))==str(drag.get("result","")) and int(vacuum.get("contacts",-1))==int(drag.get("contacts",-1)),
		"CD004 T04d L2 drag does not change the armour VERDICT at the same range: %s vs %s" % [str(vacuum.get("result","")),str(drag.get("result",""))])
	check(absf(float(vacuum.get("effective_mm",-1.0))-float(drag.get("effective_mm",-1.0)))<=1e-6,
		"CD004 T04d L2 drag does not change the effective thickness at the same range: %.6f vs %.6f" % [float(vacuum.get("effective_mm",-1.0)),float(drag.get("effective_mm",-1.0))])
	check(absf(float(vacuum.get("contact_consumed_mm",-1.0))-float(drag.get("contact_consumed_mm",-1.0)))<=1e-6,
		"CD004 T04d L2 the contact leg consumes the same budget either way, so no speed penalty is folded in: %.6f vs %.6f" % [float(vacuum.get("contact_consumed_mm",-1.0)),float(drag.get("contact_consumed_mm",-1.0))])
	check(float(drag.get("residual_speed",0.0))<float(vacuum.get("residual_speed",0.0)),
		"CD004 T04d L2 only the residual speed differs, which is design point three's job: %.3f < %.3f" % [float(drag.get("residual_speed",-1.0)),float(vacuum.get("residual_speed",-1.0))])

	var level_vacuum := _t04d_speed(Vector3.ZERO,Vector3(0,0,-900),Vector3(0,-9.81,0),0.0,1.0)
	var level_drag := _t04d_speed(Vector3.ZERO,Vector3(0,0,-900),Vector3(0,-9.81,0),T04D_DRAG_K,1.0)
	var dive_vacuum := _t04d_speed(Vector3(0,600,0),Vector3(0,-200,-900),Vector3(0,-9.81,0),0.0,1.0)
	var dive_drag := _t04d_speed(Vector3(0,600,0),Vector3(0,-200,-900),Vector3(0,-9.81,0),T04D_DRAG_K,1.0)
	print("[CD004 T04d L3] level: vacuum=%.4f drag=%.4f ; diving: vacuum=%.4f drag=%.4f (same gravity both times)" % [
		level_vacuum,level_drag,dive_vacuum,dive_drag])
	check(level_drag<level_vacuum,"CD004 T04d L3 drag removes speed in the level case: %.4f < %.4f" % [level_drag,level_vacuum])
	check(dive_drag<dive_vacuum,"CD004 T04d L3 gravity gaining speed is not free energy - the drag round is still slower: %.4f < %.4f" % [dive_drag,dive_vacuum])
	check(dive_drag>level_drag,"CD004 T04d L3 the diving round is faster than the level one, so gravity's gain is real and separate: %.4f > %.4f" % [dive_drag,level_drag])
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_DESIGN4_AUDIT_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
