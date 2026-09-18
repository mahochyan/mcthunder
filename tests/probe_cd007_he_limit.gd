extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD07: the two things the previous round named rather than claimed - that the engineering HE is
## limited to the weapon it is bound to, and what actually happens when it is fired.
##
## W1 each historical vehicle's own installed shell options are listed, so the limit is read off the production install path
##    instead of being asserted from the configuration text.
## W2 the engineering HE is then fired at a representative vehicle and its real outcome is recorded, whatever that outcome
##    turns out to be - including the possibility that it stops without bursting, which the previous round's fuze finding
##    would predict, because arming needs a plate the round actually penetrates.

const HE_ID := "he_75_m3_eng"
const SEED := 16500

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
	check(loaded.ok,"CD07 HE the production catalog loads every historical package")
	var world := Node3D.new(); root.add_child(world)

	# ── W1: what each vehicle can actually load, read from the production install path.
	var with_he: Array = []
	var options_by_vehicle := {}
	var index := 0
	for id in VehicleCatalog.IDS:
		if not catalog.packages.has(id): continue
		index += 1
		var packet: Dictionary = catalog.packages[id].packet
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,id,"cd007_he_"+str(index),index,Transform3D.IDENTITY,2,null)
		check(installed.ok,"CD07 HE W1 %s installs" % str(id))
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		await _frames(2)
		var ids: Array = []
		for shell in actor.gunner.shell_options: ids.append(str(shell.id))
		options_by_vehicle[str(id)] = ids
		if ids.has(HE_ID): with_he.append(str(id))
		print("[CD07 HE] W1 %-24s gun=%s ; options=%s" % [str(id),str(packet.assembly.get("gun","")),str(ids)])
	print("[CD07 HE] W1 vehicles offering %s: %s" % [HE_ID,str(with_he)])
	check(with_he.size()>=1,
		"CD07 HE W1 the engineering HE IS reachable on at least one delivered vehicle through the production install path: %s" % str(with_he))
	check(with_he.size()<VehicleCatalog.IDS.size(),
		"CD07 HE W1 and it is LIMITED rather than handed to every vehicle: %d of %d offer it, which is the order's requirement not to stuff incompatible rounds into every vehicle" % [
			with_he.size(),VehicleCatalog.IDS.size()])
	for id in options_by_vehicle:
		if str(id) in with_he: continue
		check(not (options_by_vehicle[id] as Array).has(HE_ID),
			"CD07 HE W1 %s does NOT offer the engineering HE, so the limit is real" % str(id))

	# ── W2: what actually happens when it is fired.
	if with_he.is_empty():
		print("[CD07 HE] W2 skipped: no vehicle offers the round, so there is nothing to fire yet")
	else:
		var target_id := str(with_he[0])
		var packet: Dictionary = catalog.packages[target_id].packet
		var layout: VehicleLayoutDefinition = catalog.packages[target_id].layout
		var actor := VehicleActor.new(); world.add_child(actor)
		var installed := actor.setup(defs,target_id,"cd007_fire",7,Transform3D.IDENTITY,2,null)
		check(installed.ok,"CD07 HE W2 the firing actor installs")
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		await _frames(2)
		var manager := ProjectileManager.new(); manager.presentation_enabled=false
		world.add_child(manager); manager.set_physics_process(false)
		manager.damage_handler = Callable(actor,"apply_projectile_damage")
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
		snapshot["entity_id"] = target_id; snapshot["life_id"] = 7
		var found := {}
		for shell in actor.gunner.shell_options:
			if str(shell.id)==HE_ID: found = {"shell":shell}
		check(not found.is_empty(),"CD07 HE W2 the round is found among the installed options")
		var shell: ShellDefinition = found.get("shell",null)
		var spec := {"round_id":SEED,"shooter_id":"cd007","shooter_life_id":1,"shot_id":SEED,
			"shell_id":shell.id,"effect_policy":"he_blast","armor_policy":"resolve",
			"impact_profile":shell.impact_profile,"post_penetration_profile":shell.post_penetration_profile,
			"fuze_policy":shell.fuze_policy,"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
			"seed":2101,"position_world":Vector3(7,1.2,0),"velocity_world":Vector3(-463,0,0),"gravity_world":Vector3.ZERO,
			"max_age_s":0.6,"max_distance_m":80.0}
		var spawned := manager.try_spawn(spec)
		check(spawned.ok,"CD07 HE W2 the engineering HE launches with its own profile and fuze")
		if spawned.ok:
			var state: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
			var space := world.get_world_3d().direct_space_state
			for i in 300:
				if state.is_terminal(): break
				manager.advance_projectile(state,1.0/240.0,[snapshot],space)
			var burst: Dictionary = state.burst if state.burst is Dictionary else {}
			var channels: Dictionary = burst.get("channels",{})
			var frag: Dictionary = channels.get("fragment",{})
			print("[CD07 HE] W2 fired => terminal=%s verdicts=%s armed=%s burst=%s channels=%s" % [
				str(state.terminal_reason),str(state.contacts.map(func(c): return str(c.get("result","")))),
				str(state.fuze_due_age_s>=0.0),("none" if burst.is_empty() else "present"),str(channels.keys())])
			print("[CD07 HE] W2 profile actually used by the fragment channel: %s" % JSON.stringify(frag))
			check(not burst.is_empty() or str(state.terminal_reason).contains("stopped"),
				"CD07 HE W2 the shot reaches a definite terminal state rather than hanging: %s" % str(state.terminal_reason))
			if burst.is_empty():
				print("[CD07 HE] W2 OUTCOME RECORDED HONESTLY: the round stopped WITHOUT bursting, which is what the fuze finding predicts - arming needs a plate the round penetrates, and a contact HE with a low flat curve stops outside instead")
			else:
				check(channels.size()==3,"CD07 HE W2 the burst records its three channels: %s" % str(channels.keys()))
				check(bool(frag.get("applied",false)),"CD07 HE W2 the fragment channel is applied")
				check(str(frag.get("version",""))==ShellEffectPolicy.VERSION or str(frag.get("version",""))!="",
					"CD07 HE W2 and it names the rule version it used: %s" % str(frag.get("version","")))
		manager.queue_free()
	world.queue_free(); await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD07_HE_LIMIT_AND_FIRE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
