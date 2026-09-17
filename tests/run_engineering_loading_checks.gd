extends SceneTree
## Actual registered packets and Actor/Gunner. Damage is an explicit module
## fixture; fire, loading, repair and conservation use production transactions.
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func run() -> void:
	get_root().size = Vector2i(1280,720)
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	var admitted := catalog.load_engineering(defs)
	check(admitted.ok,"production engineering packets pass evidence and model binding gates: "+str(admitted.errors))
	if not admitted.ok: quit(1); return
	for id in VehicleCatalog.ENGINEERING_IDS:
		var world := Node3D.new()
		root.add_child(world)
		TerrainFixtures.box(world,Vector3(0,-.5,0),Vector3(100,1,100))
		var actor := VehicleActor.new()
		actor.presentation_enabled = false
		world.add_child(actor)
		var setup := actor.setup(defs,id,"A",1,Transform3D(Basis.IDENTITY,Vector3(0,.8,0)),4,null)
		check(setup.ok,id+": actual Actor setup")
		if not setup.ok: world.free(); continue
		var manager := ProjectileManager.new()
		manager.presentation_enabled = false
		world.add_child(manager)
		manager.exclude_provider = func(_id: String, _life: int) -> Array[RID]: return [actor.tank.get_rid()]
		var gun := actor.gunner
		gun.projectile_manager = manager
		gun.round_provider = func() -> int: return 4041
		gun.aim_preview_enabled = false
		await frames(35)
		var automatic: bool = id == "ussr_t_80b"
		var caps := actor.capabilities()
		print("LOADING_BASELINE ",id," mode=",caps.loading_mode," rate=",caps.reload_rate," nominal_s=",actor.weapon.reload_time," roles=",actor.state.crew_assignments.keys()," racks=",gun.inventory.racks)
		check(caps.loading_mode == ("automatic" if automatic else "crew") and is_equal_approx(caps.reload_rate,1),id+": healthy authored equipment has no missing-crew penalty")
		check(not HUDPresenter.present(actor,{}).weapon_text.contains("装填手失能"),id+": healthy HUD does not report a missing loader")
		if OS.get_cmdline_user_args().has("--baseline"):
			world.free(); await frames(2); continue
		if automatic:
			check(actor.state.module_states.has("autoloader") and gun.inventory.racks.has("ammo_reserve"),"T-80B installs bound mechanism and separate reserve")
			if not actor.state.module_states.has("autoloader"): world.free(); continue
			check(gun.inventory.rack_capacities.ammo_ready == 28 and gun.inventory.rack_capacities.ammo_reserve == 10,"T-80B restores authored 28/10 layout with unchanged 38 total capacity")
		var stock := gun.rounds_remaining
		check(gun.request_fire(),id+": actual chambered round launches")
		var elapsed := 0.0
		while gun.cooldown_left > 0 and elapsed < actor.weapon.reload_time+1:
			await physics_frame
			elapsed += 1.0/Engine.physics_ticks_per_second
		print("NATURAL_LOADING ",id," elapsed_s=",elapsed," remaining_s=",gun.cooldown_left)
		check(gun.cooldown_left == 0 and gun.inventory.chamber == 1 and elapsed <= actor.weapon.reload_time+.1,id+": actual healthy cycle completes at authored shot reload time")
		check(gun.rounds_remaining == stock-1 and gun.inventory.conserved(),id+": complete shot/loading conserves finite ammunition")
		if automatic:
			check(gun.request_fire(),"second real shot starts an automatic load")
			await frames(8)
			var damage := actor.apply_projectile_damage({"kind":"module","module_id":"autoloader","entity_id":"A","life_id":actor.life_id,"event_id":"loading_fixture","round_id":4041},120)
			check(damage.ok and not actor.capabilities().can_load,"explicit mechanism damage disables actual automatic feed")
			var remaining := gun.cooldown_left
			var inventory := gun.inventory.snapshot()
			await frames(60)
			check(is_equal_approx(remaining,gun.cooldown_left) and inventory == gun.inventory.snapshot() and not gun.try_complete_load(),"disabled mechanism holds transfer and prevents completion bypass")
			check(HUDPresenter.present(actor,{}).weapon_text.contains(LocalizationService.text("loading_mechanism_disabled")),"HUD reports damaged mechanism rather than nonexistent crew")
			var repair := VehicleCommand.new()
			repair.repair_requested = true
			actor.submit_command(repair)
			await frames(ceili(RecoveryRules.REPAIR_SECONDS*Engine.physics_ticks_per_second)+4)
			check(actor.capabilities().can_load and actor.state.module_states.autoloader.integrity == 50,"normal repair restores automatic mechanism")
			await frames(ceili((actor.weapon.reload_time+1)*Engine.physics_ticks_per_second))
			check(gun.inventory.chamber == 1 and gun.inventory.conserved() and gun.rounds_remaining == stock-2,"repaired mechanism finishes held cycle without adding rounds")
			actor.reset_vehicle()
			check(actor.capabilities().loading_mode == "automatic" and actor.state.alive_crew_count() == 3 and gun.inventory.total_available() == stock,"reset preserves three-crew automatic equipment and original finite loadout")
		else:
			actor.apply_projectile_damage({"kind":"crew","crew_id":"loader","entity_id":"A","life_id":actor.life_id,"event_id":"manual_loader_fixture","round_id":4041},120)
			check(actor.capabilities().reload_rate < 1 and HUDPresenter.present(actor,{}).weapon_text.contains("装填手失能"),"Leopard manual-loader casualty still slows loading and reports actual lost role")
		world.free()
		await frames(2)
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("ENGINEERING_LOADING_CHECKS_PASS" if failed == 0 else "ENGINEERING_LOADING_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
