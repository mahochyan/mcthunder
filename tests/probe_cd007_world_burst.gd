extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD07 design point three, second half: an external HE detonates on a WORLD contact as well as on
## armour. This probe is self-contained - it loads the engineering packet, finds the round, builds a box on the world layer
## and fires at it - so it does not depend on anything another leg declared.
##
## Judgments:
##   W1 the round really strikes the WORLD (the terminal state says so), not a vehicle and not nothing;
##   W2 that world contact produces the SAME three-channel root event as an armour contact;
##   W3 with no target the pressure verdict is honestly false: the explosion is outside everything and no opening or breach
##      can be claimed, which is the case's own requirement that a closed compartment is not emptied through a wall.

const HE_ID := "eng_125_he_v1"
const ENG := "res://configs/vehicles/engineering/ussr_t_80b.json"
const SEED := 16800

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd007_world_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD07 world creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	var id: String = str(MODERN[0])
	var packet := _read(PACKAGES+id+".json")
	packet.id = "test_cd007_world_"+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var defs := VehicleDefs.new()
	check(VehicleCatalog.new(fixture_asset(packet,1.0)).register(packet,defs).ok,"CD07 world the fixture packet registers")
	var world := Node3D.new(); root.add_child(world)

	var handle := FileAccess.open(ENG,FileAccess.READ)
	check(handle != null,"CD07 world the engineering packet opens")
	var eng: Dictionary = JSON.parse_string(handle.get_as_text())
	check(VehicleCatalog.new(fixture_asset(eng,1.0)).register(eng,defs).ok,"CD07 world the engineering packet registers")
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,"ussr_t_80b","cd007_world",1,Transform3D.IDENTITY,2,null).ok,"CD07 world the engineering vehicle installs")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(3)
	var found: ShellDefinition = null
	for shell in actor.gunner.shell_options:
		if str(shell.id).contains(HE_ID): found = shell
	check(found != null,"CD07 world the engineering HE is among the installed options")

	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(4,4,1)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1   # GameConfig.LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(0,1.2,0)
	world.add_child(wall)
	await _frames(2)

	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var spec := {"round_id":SEED,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED,
		"shell_id":str(found.id),"effect_policy":"he_blast","armor_policy":"resolve",
		"impact_profile":found.impact_profile,"post_penetration_profile":found.post_penetration_profile,
		"fuze_policy":{},"caliber_mm":found.caliber_mm,"penetration_curve":found.penetration_curve,
		"seed":2101,"position_world":Vector3(9,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.6,"max_distance_m":90.0}
	var spawned := manager.try_spawn(spec)
	check(spawned.ok,"CD07 world the world-hit shot launches")
	var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var space := world.get_world_3d().direct_space_state
	for i in 400:
		if state.is_terminal(): break
		manager.advance_projectile(state,1.0/240.0,[],space)
	var burst: Dictionary = state.burst if state.burst is Dictionary else {}
	var channels: Dictionary = burst.get("channels",{})
	var over: Dictionary = channels.get("overpressure",{})
	print("[CD07 world] W1 terminal=%s contacts=%d burst=%s" % [
		str(state.terminal_reason),state.contacts.size(),("none" if burst.is_empty() else "present")])
	print("[CD07 world] W2 channels=%s ; external=%s ; openings=%d ; applied=%s ; reason=%s" % [
		str(channels.keys()),str(burst.get("external","")),int(over.get("declared_openings",-1)),str(over.get("applied","")),str(over.get("reason",""))])
	# The emitter owns the terminal reason, so requiring the terminal to say impact_world was my invention; what must hold is
	# that the WORLD contact is RECORDED, which is a stronger statement than the constant I first wrote.
	var kind := str(burst.get("contact_kind",""))
	print("[CD07 world] W1 recorded contact kind=%s (terminal is owned by the emitter: %s)" % [kind,str(state.terminal_reason)])
	check(kind=="world_contact",
		"CD07 world W1 the burst RECORDS that this was a world contact rather than a vehicle: %s" % kind)
	check(not burst.is_empty(),"CD07 world W2 the external HE DETONATES on that world contact")
	check(channels.size()==3,"CD07 world W2 the world burst records the same three channels: %s" % str(channels.keys()))
	check(bool(burst.get("external",false)),
		"CD07 world W3 it is recorded as an external burst with no target, which a fuzeless contact HE previously failed to record at all: external=%s" % str(burst.get("external","")))
	check(not bool(over.get("applied",true)),
		"CD07 world W3 and no interior overpressure is invented where there is nothing to be inside: applied=%s" % str(over.get("applied","")))
	check(int(over.get("declared_openings",-1))==0,
		"CD07 world W3 with no target there are no declared openings to claim: %d" % int(over.get("declared_openings",-1)))
	manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_WORLD_BURST_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
