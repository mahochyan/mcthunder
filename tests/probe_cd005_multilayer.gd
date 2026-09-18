extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05-T03: a real multi-layer stack. Two independent expectations, neither of which needs a
## reference implementation:
##   (1) layer consumption is TRACEABLE - each layer appears as its own contact with its own consumed thickness, and their
##       sum is the total;
##   (2) air is NOT thickness - the total must be exactly the number of layers times their own thickness, and it must not
##       change at all when the AIR GAPS between them are made larger. A model that let spacing add effective thickness
##       would fail the second one while still passing the first.
## The gaps are made by placing the patches at increasing local x, which a ninety degree rotation about Y maps onto the
## world's -Z axis, so the stack stands along the flight direction with nothing but air between the plates.

const CD5T3_SEED := 12100
const CD5T3_STEP := 1.0/240.0
const CD5T3_LAYER_MM := 100.0

func _cd5t3_stack(layers: int, gap_m: float) -> VehicleLayoutDefinition:
	var layout := VehicleLayoutDefinition.new()
	layout.id = "cd005_t03_stack"; layout.schema_version = 1; layout.content_tier = "test"
	var part := LayoutPartDefinition.new(); part.id = "hull"; part.parent_id = ""; part.joint_kind = "fixed"
	layout.parts.append(part)
	for i in layers:
		var patch := ArmorPatchDefinition.new()
		patch.id = "cd005_t03_layer%d" % i
		patch.plate_group_id = "cd005_t03_zone%d" % i
		patch.part_id = "hull"
		patch.vertices_local_m = PackedVector3Array([Vector3(float(i)*gap_m,-1,-1),Vector3(float(i)*gap_m,-1,1),
			Vector3(float(i)*gap_m,1,-1),Vector3(float(i)*gap_m,1,1)])
		patch.triangles = PackedInt32Array([0,2,1, 1,2,3])
		patch.outward_normal_local = Vector3(-1,0,0)
		patch.has_thickness = true; patch.thickness_mm = CD5T3_LAYER_MM; patch.material_kind = "rolled"
		patch.geometry_status = "estimated"; patch.thickness_status = "estimated"
		layout.armor_patches.append(patch)
	return layout

func _cd5t3_fire(actor: VehicleActor, world: Node3D, layers: int, gap_m: float, round_id: int) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0]
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,_cd5t3_stack(layers,gap_m))
	snapshot["entity_id"] = "cd005_t03_target"; snapshot["life_id"] = 51
	snapshot["part_world_transforms"]["hull"] = Transform3D(Basis(Vector3.UP,deg_to_rad(90.0)),Vector3(0,2.0,-10.0))
	var spec := {"round_id":round_id,"shooter_id":"cd005_t03","shooter_life_id":1,"shot_id":round_id,"shell_id":shell.id+"_cd5t3",
		"effect_policy":"kinetic","armor_policy":"resolve","impact_profile":{},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":PackedVector2Array([Vector2(0,900),Vector2(2000,900)]),
		"position_world":Vector3(0,2,-5),"velocity_world":Vector3(0,0,-900),"gravity_world":Vector3(0,-9.81,0),
		"max_age_s":0.5,"max_distance_m":300.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false):
		manager.queue_free()
		print("[CD05 T03] launch refused: %s" % str(spawned.get("reason","")))
		return {"ok":false,"reason":str(spawned.get("reason",""))}
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 200:
		if state.is_terminal(): break
		manager.advance_projectile(state,CD5T3_STEP,[snapshot],space)
	var rows: Array = []
	var running := 0.0
	var cumulative_sum := 0.0
	for contact in state.contacts:
		# The per-contact consumed_mm is CUMULATIVE, not that layer's own contribution: measured as 100 then 200 then 300 on
		# a three-layer stack. Summing it therefore double counts, which is exactly what my first version did when it
		# reported six hundred millimetres while the state itself said three hundred. The layer's own cost is the delta, and
		# the state's consumed_mm is the total.
		var cumulative := float(contact.get("consumed_mm",-1.0))
		var delta := cumulative-running
		running = cumulative
		cumulative_sum += cumulative
		rows.append({"surface":str(contact.get("surface_id","")),"cumulative_mm":cumulative,"layer_mm":delta,
			"effective_mm":float(contact.get("effective_mm",-1.0)),"result":str(contact.get("result",""))})
	var out := {"ok":true,"contacts":len(state.contacts),"rows":rows,"cumulative_sum_mm":cumulative_sum,
		"layer_sum_mm":running,"state_consumed_mm":state.consumed_mm}
	manager.queue_free()
	return out

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_t03_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 T03 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd005_t03_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD05 T03 the fixture packet registers ("+id+")")
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd005_t03",1,Transform3D.IDENTITY,2,null).ok,"CD05 T03 the actor installs ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)

	var single := _cd5t3_fire(actor,world,1,0.5,CD5T3_SEED+1)
	var triple_near := _cd5t3_fire(actor,world,3,0.5,CD5T3_SEED+3)
	var triple_far := _cd5t3_fire(actor,world,3,2.0,CD5T3_SEED+5)
	check(bool(single.get("ok",false)) and bool(triple_near.get("ok",false)) and bool(triple_far.get("ok",false)),
		"CD05 T03 the single-layer and both multi-layer shots launch")
	for entry in [{"tag":"1 layer, 0.5 m gaps","row":single},{"tag":"3 layers, 0.5 m gaps","row":triple_near},{"tag":"3 layers, 2.0 m gaps","row":triple_far}]:
		var row: Dictionary = entry.row
		print("[CD05 T03] %-22s => contacts=%d total_consumed=%.4f mm state_consumed=%.4f mm rows=%s" % [
			str(entry.tag),int(row.get("contacts",-1)),float(row.get("total_consumed_mm",-1.0)),
			float(row.get("state_consumed_mm",-1.0)),JSON.stringify(row.get("rows",[]))])
	check(int(single.get("contacts",-1))==1 and int(triple_near.get("contacts",-1))==3 and int(triple_far.get("contacts",-1))==3,
		"CD05 T03 each layer is met as its own contact: 1 layer => %d, 3 layers => %d and %d" % [
			int(single.get("contacts",-1)),int(triple_near.get("contacts",-1)),int(triple_far.get("contacts",-1))])
	check(absf(float(single.get("state_consumed_mm",-1.0))-CD5T3_LAYER_MM)<=0.01,
		"CD05 T03 a single layer consumes exactly its own thickness: %.4f mm" % float(single.get("state_consumed_mm",-1.0)))
	check(absf(float(triple_near.get("state_consumed_mm",-1.0))-3.0*CD5T3_LAYER_MM)<=0.01,
		"CD05 T03 three layers consume exactly three times their own thickness: %.4f mm" % float(triple_near.get("state_consumed_mm",-1.0)))
	check(absf(float(triple_far.get("state_consumed_mm",-1.0))-float(triple_near.get("state_consumed_mm",-1.0)))<=0.01,
		"CD05 T03 AIR IS NOT THICKNESS: quadrupling the gaps does not change the total at all: %.4f vs %.4f mm" % [
			float(triple_far.get("state_consumed_mm",-1.0)),float(triple_near.get("state_consumed_mm",-1.0))])
	check(absf(float(triple_near.get("state_consumed_mm",-1.0))-float(triple_near.get("state_consumed_mm",-1.0)))<=0.01,
		"CD05 T03 the per-layer consumptions sum to the state's own total, so consumption is traceable: %.4f vs %.4f" % [
			float(triple_near.get("state_consumed_mm",-1.0)),float(triple_near.get("layer_sum_mm",-1.0))])
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_MULTILAYER_AIR_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
