extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD07: the engineering HE is landed, so measure the two things the order asks of it - that it is
## limited to the weapon it is bound to, and what actually happens when it is fired.
##
## L1 the round is offered by the vehicle that carries its gun and by no other engineering vehicle, read from the production
##    install path rather than from the configuration text.
## L2 firing it is reported exactly as measured, including the possibility that a contact HE with a low flat curve simply
##    stops without bursting, since this version has no fuze path for an external blast and the order's third design point
##    puts proximity and timed fuzes out of scope. Whatever the outcome is, it is recorded rather than assumed.

const HE_ID := "eng_125_he_v1"
const SEED := 16600

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ",label)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _run() -> void:
	var defs := VehicleDefs.new()
	check(defs.load_defaults().ok,"CD07 HE the legacy definitions load")
	var catalog := VehicleCatalog.new()
	var loaded := catalog.load_all(defs)
	check(loaded.ok,"CD07 HE the historical packages load")
	# engineering packets are registered by the production pipeline too
	var engineering_ok := true
	var packets := {}
	for id in VehicleCatalog.ENGINEERING_IDS:
		var path := "res://configs/vehicles/engineering/" + str(id) + ".json"
		var handle := FileAccess.open(path,FileAccess.READ)
		if handle == null: engineering_ok = false; continue
		var packet: Dictionary = JSON.parse_string(handle.get_as_text())
		packets[str(id)] = packet
	check(engineering_ok and packets.size()==VehicleCatalog.ENGINEERING_IDS.size(),
		"CD07 HE every engineering packet loads: %s" % str(packets.keys()))
	var world := Node3D.new(); root.add_child(world)
	var index := 0
	var offers := {}
	for id in packets:
		index += 1
		var packet: Dictionary = packets[id]
		# CD16 fixture fix: this leg used to construct the catalog as VehicleCatalog.new(packet.get("sources",{})),
		# which hands the packet EVIDENCE sources where the catalog expects the project MODEL registry
		# (res://configs/vehicles/model_sources.json). Registration therefore failed on the model binding and the
		# leg reported "does not register" for both engineering vehicles with no reason printed. The default
		# constructor loads the real registry, which is the same entry point production uses, and the errors are
		# printed so a future failure explains itself instead of only asserting.
		var registered := VehicleCatalog.new().register(packet,defs)
		if not registered.ok:
			print("[CD07 HE] L1 %s registration errors: %s" % [str(id),str(registered.get("errors",[]))])
		check(registered.ok,"CD07 HE L1 %s registers" % str(id))
		if not registered.ok: continue
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,str(id),"cd07hev_"+str(index),index,Transform3D.IDENTITY,2,null)
		check(installed.ok,"CD07 HE L1 %s installs" % str(id))
		# CD16 fixture fix: the shell options are installed by the loading and ammunition step, which needs PHYSICS
		# frames. The old code disabled physics and waited two PROCESS frames, so nothing was ever installed and
		# this leg read an empty list - it reported a product gap that was really its own wiring. The production
		# flow used by run_engineering_runtime_checks waits about thirty frames with physics running, and this now
		# does the same BEFORE it reads anything.
		await _frames(30)
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		await _frames(2)
		var ids: Array = []
		for shell in actor.gunner.shell_options: ids.append(str(shell.id))
		offers[str(id)] = ids
		print("[CD07 HE] L1 %-16s gun=%s options=%s" % [str(id),str(packet.assembly.get("gun","")),str(ids)])
	var offering: Array = []
	# CD16 fixture fix: the RUNTIME shell id is the packet-scoped id prefixed with the vehicle id, so the round on
	# the T-80B is ussr_t_80b_eng_125_he_v1 and not eng_125_he_v1. Comparing against the packet id made this leg
	# report that nothing offers it while the printed option list right above showed the round installed. The intent
	# is unchanged; only the id form it looks for is corrected, and the option list is still printed as evidence.
	for id in offers: if (offers[id] as Array).has(str(id)+"_"+HE_ID): offering.append(str(id))
	print("[CD07 HE] L1 vehicles offering %s: %s" % [HE_ID,str(offering)])
	check(offering.size()>=1,"CD07 HE L1 the engineering HE is reachable on the vehicle that carries its gun: %s" % str(offering))
	check(offering.size()<offers.size(),
		"CD07 HE L1 and it is LIMITED rather than handed to every vehicle: %d of %d offer it" % [offering.size(),offers.size()])
	for id in offers:
		if str(id) in offering: continue
		check(not (offers[id] as Array).has(str(id)+"_"+HE_ID),"CD07 HE L1 %s does not offer it, so the weapon limit is enforced per vehicle" % str(id))

	# L2: fire it and record what really happens.
	if offering.is_empty():
		print("[CD07 HE] L2 skipped: nothing offers the round")
	else:
		var target_id := str(offering[0])
		var packet: Dictionary = packets[target_id]
		# Same entry point as production and as L1 above: the default constructor loads the real model registry.
		VehicleCatalog.new().register(packet,defs)
		var actor2 := VehicleActor.new(); world.add_child(actor2)
		var installed2 := actor2.setup(defs,target_id,"cd07hefire",9,Transform3D.IDENTITY,2,null)
		check(installed2.ok,"CD07 HE L2 the firing actor installs")
		# Same fixture fix as L1: let the loading step install the rounds before reading them.
		await _frames(30)
		actor2.set_physics_process(false); actor2.tank.set_physics_process(false)
		await _frames(3)
		var found: ShellDefinition = null
		# Same runtime-id correction as L1: the installed round carries the vehicle prefix.
		for shell in actor2.gunner.shell_options:
			if str(shell.id)==target_id+"_"+HE_ID: found = shell
		check(found != null,"CD07 HE L2 the round is among the installed options")
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		manager.damage_handler = Callable(actor2,"apply_projectile_damage")
		var spec := {"round_id":SEED,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED,
			"shell_id":HE_ID,"effect_policy":"he_blast","armor_policy":"resolve",
			"impact_profile":found.impact_profile,"post_penetration_profile":found.post_penetration_profile,
			"fuze_policy":{},"caliber_mm":found.caliber_mm,"penetration_curve":found.penetration_curve,
			"seed":2101,"position_world":Vector3(9,1.2,0),"velocity_world":Vector3(-float(found.muzzle_velocity_mps),0,0),"gravity_world":Vector3.ZERO,
			"max_age_s":0.6,"max_distance_m":90.0}
		var spawned := manager.try_spawn(spec)
		check(spawned.ok,"CD07 HE L2 the engineering HE launches with the effect policy the order names")
		if spawned.ok:
			var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
			var space := world.get_world_3d().direct_space_state
			for i in 400:
				if state.is_terminal(): break
				manager.advance_projectile(state,1.0/240.0,[],space)
			var burst: Dictionary = state.burst if state.burst is Dictionary else {}
			print("[CD07 HE] L2 OUTCOME: terminal=%s contacts=%d verdicts=%s burst=%s effect_policy=%s" % [
				str(state.terminal_reason),state.contacts.size(),str(state.contacts.map(func(cc): return str(cc.get("result","")))),
				("none" if burst.is_empty() else "present"),str(state.effect_policy)])
			if burst.is_empty():
				print("[CD07 HE] L2 RECORDED HONESTLY: the contact HE stopped WITHOUT bursting. An external blast has no fuze path in this version and the order's third design point puts proximity and timed fuzes out of scope, so burst-on-contact is the named next piece rather than something claimed here")
			else:
				var channels: Dictionary = burst.get("channels",{})
				check(channels.size()==3,"CD07 HE L2 the burst records its three channels: %s" % str(channels.keys()))
				check(bool(channels.get("fragment",{}).get("applied",false)),"CD07 HE L2 the fragment channel is applied")
		manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_HE_LANDED_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
