extends SceneTree
var checks := 0
var failed := 0
var world: Node3D
var target: VehicleActor
var manager: ProjectileManager
var shot := 0
var runtime_cases := 0
var player_case_complete := false
var historical_cases_complete := 0
var village_case_complete := false

func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed += 1
	print(("[PASS] " if value else "[FAIL] ")+label)

func inventory_cases() -> void:
	var ammo := AmmoInventory.new()
	check(ammo.configure_loadout({"ap":4,"aphe":2},["ready","floor"],{"ready":2,"floor":4},"ap"),"T021-H03 typed loadout fits real rack capacity")
	check(ammo.racks.ready==1 and ammo.racks.floor==4 and ammo.chamber_shell=="ap" and ammo.conserved(),"chamber deducted once from ready rack")
	var before := ammo.snapshot()
	check(not ammo.configure_loadout({"ap":7},["ready","floor"],{"ready":2,"floor":4},"ap") and ammo.snapshot()==before,"overcapacity loadout rejected transactionally")
	check(not ammo.select_next("alien") and not ammo.supply_round(1,"ready","alien") and not ammo.supply_round(1,"ready","ap"),"illegal ammo and overcapacity supply cannot change stock")
	ammo.select_next("aphe")
	check(ammo.chamber_shell=="ap" and ammo.total_available()==6,"selection cannot transform loaded AP")
	ammo.consume_chamber(); ammo.begin_transfer(); ammo.select_next("ap")
	check(ammo.transfer_shell=="aphe" and ammo.selected_shell=="ap" and ammo.conserved(),"selection during transfer preserves carried APHE")
	ammo.complete_load(); ammo.complete_load()
	check(ammo.chamber_shell=="aphe" and ammo.total_available()==5,"double load completion cannot duplicate")
	ammo.consume_chamber(); ammo.begin_transfer(); ammo.cancel_transfer(); ammo.cancel_transfer()
	check(ammo.total_available()==4 and ammo.conserved(),"double cancellation restores one typed round")
	check(ammo.supply_round(1,"ready","aphe") and ammo.shell_counts().aphe==2 and ammo.conserved(),"supply replenishes requested type within capacity")
	for cycle in 40:
		ammo.select_next("ap" if cycle%2==0 else "aphe")
		ammo.begin_transfer(); ammo.complete_load(); ammo.consume_chamber()
		for id in ammo.racks:
			if ammo.supply_round(1,id,"ap" if cycle%2==0 else "aphe"): break
		check(ammo.conserved() and ammo.total_available()<=6,"supply/select/fire cycle %d preserves one ledger"%cycle)
	ammo.lose_all(); ammo.lose_all()
	check(ammo.total_available()==0 and ammo.conserved() and ammo.racks.ready==0 and ammo.racks.floor==0,"T021-H04 loss clears each physical rack exactly once")

func snapshots() -> Array:
	return [QuerySnapshotBuilder.build_from_vehicle(target.tank,target.damage_layout_override)]
func apply_damage(event: Dictionary, budget: float) -> Dictionary:
	return target.apply_projectile_damage(event,budget)

func fire_fixture(thickness: float, effect: String = "internal_burst", length: float = 4.0, internals: bool = true, power: float = 96.0, open_exit: bool = false, shield: bool = false) -> ProjectileState:
	manager.cancel_all("cancelled_fixture")
	var layout := ShellTrainingTargets.build(thickness,length,internals)
	if shield:
		var part := LayoutPartDefinition.new(); part.id="barrel"; layout.parts.append(part)
		var plate := layout.armor_patches[4].duplicate(true) as ArmorPatchDefinition
		plate.id="detached_shield"; plate.part_id="barrel"; plate.thickness_mm=5
		var transform := target.turret.barrel_pivot.global_transform.affine_inverse()*target.tank.global_transform
		for i in plate.vertices_local_m.size(): plate.vertices_local_m[i]=transform*(plate.vertices_local_m[i]+Vector3(0,0,1))
		plate.outward_normal_local=transform.basis*Vector3.BACK
		layout.armor_patches.append(plate)
	if open_exit:
		var rear: ArmorPatchDefinition = layout.armor_patches.pop_back()
		layout.declared_openings.append({"id":"open_exit","part":"hull","boundary_loop":Array(rear.vertices_local_m),"reason":"TEST ONLY open compartment"})
	target.set_damage_layout(layout)
	shot += 1
	var accepted := manager.try_spawn({"round_id":21,"shooter_id":"fixture","shooter_life_id":1,"shot_id":shot,"shell_id":"test_"+effect,
		"armor_policy":"resolve","effect_policy":effect,"penetration_curve":PackedVector2Array([Vector2(0,power)]),"seed":2101,
		"position_world":target.tank.global_transform*Vector3(0,2,4),"velocity_world":Vector3(0,0,-600),"gravity_world":Vector3.ZERO,"max_age_s":1.0,"max_distance_m":100.0})
	check(accepted.get("ok",false),"real manager accepts explicit TEST ONLY shell fixture")
	var st := manager.get_projectile_state(int(accepted.projectile_id))
	for i in 8:
		if st.is_terminal(): break
		manager.advance_projectile(st,1.0/60.0,snapshots(),world.get_world_3d().direct_space_state)
	runtime_cases += 1
	return st

func effect_cases() -> void:
	var st := fire_fixture(100)
	check(st.burst.is_empty() and st.fragments.is_empty() and st.damage_records.is_empty(),"T021-H01 blocked exterior never creates inside fragments")
	st = fire_fixture(-1)
	check(st.burst.is_empty() and st.fragments.is_empty(),"unknown exterior remains conservative")
	st = fire_fixture(10,"internal_burst",0.4,false)
	check(st.burst.is_empty() and st.fragments.is_empty() and st.contacts.size()==2,"exit before 0.8m cancels burst and retains kinetic exit contact")
	st = fire_fixture(10,"internal_burst",0.4,false,96,true)
	check(st.burst.is_empty() and st.fragments.is_empty() and st.contacts.size()==1,"declared open exit cancels inside burst without inventing an armor plate")
	st = fire_fixture(20,"internal_burst",4,false)
	check(not st.burst.is_empty() and st.fragments.size()==12 and st.damage_records.is_empty(),"empty compartment creates bounded rays and no invented crew hits")
	check(st.terminal_reason=="internal_burst" and st.burst.point_world.distance_to(target.tank.global_transform*Vector3(0,2,1.2))<0.001,"burst occurs exactly at 0.8m real inside path and ends mother shot")
	var stopped := 0
	for fragment in st.fragments:
		if str(fragment.reason).begins_with("armor_"): stopped += 1
		check(fragment.queries<=8 and fragment.path.size()<=9,"T021-H02 fragment %d obeys query/path cap"%int(fragment.id))
	check(stopped>0,"12mm game fragments stop at actual 20mm compartment armor")
	st = fire_fixture(20)
	check(st.fragments.size()==12 and st.damage_records.size()>0,"internal burst reaches off-axis actual modules")
	var record: Dictionary = manager.shot_records.get_record(manager.shot_records.count()-1)
	check(not record.is_empty() and ShotRecordBuilder.validate(record).ok,"actual fragment record is valid for replay")
	for defect in ["direction","queries","point","burst_frame","burst_seed","duplicate_damage","missing_damage_link","contact"]:
		var bad := record.duplicate(true)
		match defect:
			"direction": bad.fragments[0].direction=Vector3.ZERO
			"queries": bad.fragments[0].queries=9
			"point": bad.fragments[0].path.append(Vector3(INF,0,0))
			"burst_frame": bad.burst.geometry_frame=999
			"burst_seed": bad.burst.seed+=1
			"duplicate_damage":
				for frag in bad.fragments:
					if not frag.damage_indices.is_empty(): frag.damage_indices.append(frag.damage_indices[0]); break
			"missing_damage_link":
				for frag in bad.fragments: frag.damage_indices.clear()
			"contact": bad.fragments[0].contacts.append(null)
		check(not ShotRecordBuilder.validate(bad).ok,"malformed fragment replay rejects "+defect)
	var affected := 0
	for row in target.state.module_states.values():
		if row.integrity<100: affected += 1
	check(affected>0,"fragment transactions change independent live target state")
	var state_before := target.state.damage_snapshot()
	var replay := ReplayView.new(); root.add_child(replay)
	check(replay.present(record,false).ok,"production replay accepts actual recorded fragments")
	replay.seek(float(record.terminal.flight_time_s)); replay.close_view(); replay.present(record,false); replay.seek(float(record.terminal.flight_time_s))
	check(replay.record.fragments==record.fragments and target.state.damage_snapshot()==state_before,"T021-H04 repeated display preserves exact paths and never mutates damage")
	replay.queue_free()
	st = fire_fixture(20,"kinetic",4,true,120)
	check(st.fragments.is_empty() and st.damage_records.is_empty(),"AP follows narrow path through the same off-axis module layout")
	st = fire_fixture(100,"kinetic",4,false,120)
	check(st.contacts.size()>0 and st.contacts[0].result=="penetrated","T021-H05 TEST ONLY AP120 penetrates armor that APHE96 cannot")
	st = fire_fixture(20,"internal_burst",4,false,96,false,true)
	check(not st.burst.is_empty() and st.contacts.size()>=2 and st.burst.point_world.distance_to(target.tank.global_transform*Vector3(0,2,1.2))<0.001,"detached shield authorizes entry but one-metre air gap never counts toward inside burst")
	var cancel := func(event: Dictionary) -> void:
		if event.get("fragment_id",-1)>=0: manager.cancel_all("cancelled_fragment_callback")
	var terminal := {}
	var collect := func(event: Dictionary) -> void: terminal.merge(event,true)
	manager.projectile_finished.connect(collect)
	manager.projectile_damage.connect(cancel)
	st = fire_fixture(20)
	manager.projectile_damage.disconnect(cancel)
	manager.projectile_finished.disconnect(collect)
	check(st.terminal_reason=="cancelled_fragment_callback" and st.damage_records.size()==1 and st.fragments.size()<12 and manager.active_count()==0,"first fragment callback cancellation stops remaining rays and commits only one damage event")
	record=ShotRecordBuilder.freeze(st,terminal)
	check(ShotRecordBuilder.validate(record).ok and record.damage.size()==1 and manager.shot_records.count()==0,"reentrant cancellation freezes committed partial path and clears public replay history")

func catalog_cases() -> void:
	var data := HistoricalShellCatalog.read_packet()
	var defs := VehicleDefs.new(); var catalog := VehicleCatalog.new()
	check(catalog.load_all(defs).ok,"four historical vehicles admit independently sourced shell options")
	for id in VehicleCatalog.IDS:
		var packet: Dictionary = catalog.packages[id].packet
		var result := HistoricalShellCatalog.build(packet,data)
		check(result.ok and result.options.size()==2 and result.options[0].effect_policy=="kinetic" and result.options[1].effect_policy=="internal_burst",id+": documented AP and APHE options")
		var broken := data.duplicate(true)
		broken.vehicles[id].gun="unrelated gun"
		check(not HistoricalShellCatalog.build(packet,broken).ok,id+": gun mismatch rejected")
		broken=data.duplicate(true); broken.shells[broken.vehicles[id].shells[1]].source_refs=["missing"]
		check(not HistoricalShellCatalog.build(packet,broken).ok,id+": unsupported second shell evidence rejected")
		broken=data.duplicate(true); broken.shells[broken.vehicles[id].shells[1]].penetration_curve=[[0,-10]]
		check(not HistoricalShellCatalog.build(packet,broken).ok,id+": invalid historical penetration curve rejected")
		check(not is_equal_approx(result.options[1].penetration_curve[0].y,result.options[0].penetration_curve[0].y*0.8),id+": historical APHE is not generic AP times 0.8")
		for defect in ["caliber","label","explanation","source_id","shell_id","default"]:
			broken=data.duplicate(true)
			var entry: Dictionary=broken.shells[broken.vehicles[id].shells[0]]
			match defect:
				"caliber": entry.caliber_mm=[]
				"label": entry.label=[]
				"explanation": entry.estimate_reason=[]
				"source_id": entry.source_refs=[{}]
				"shell_id": broken.vehicles[id].shells[0]={}
				"default": broken.vehicles[id].default=[]
			check(not HistoricalShellCatalog.build(packet,broken).ok,id+": malformed shell catalog rejects "+defect)

func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame

func action(name: String) -> void:
	Input.action_press(name); await frames(3); Input.action_release(name); await frames(3)

func player_and_supply_cases() -> void:
	var scene: ShellRange = load("res://scenes/training/shell_range.tscn").instantiate()
	root.add_child(scene); await frames(30)
	check(scene._initialized and scene.actor.gunner.inventory.typed,"normal shell scene initializes production typed gunner")
	var gun := scene.actor.gunner
	await action("shell_2")
	check(gun.inventory.selected_shell=="test_aphe96" and gun.inventory.chamber_shell=="test_ap120","actual player command selects next without changing chamber")
	await action("fire")
	check(gun.shots_fired==1 and gun.inventory.transfer_shell=="test_aphe96","actual fire takes selected type into pending load")
	var record := scene.projectiles.shot_records.get_record(0)
	check(not record.is_empty() and record.identity.shell_id=="test_ap120","first actual launch freezes the previously loaded AP")
	await action("shell_1")
	check(gun.inventory.transfer_shell=="test_aphe96" and gun.inventory.selected_shell=="test_ap120","actual mid-load input cannot transform carried APHE")
	await frames(150)
	check(gun.inventory.chamber_shell=="test_aphe96" and gun.cooldown_left==0,"natural reload completes the fixed carried type")
	await action("fire")
	record=scene.projectiles.shot_records.get_record(scene.projectiles.shot_records.count()-1)
	check(gun.shots_fired==2 and record.identity.shell_id=="test_aphe96" and gun.rounds_remaining==18 and gun.inventory.conserved(),"second real shot uses loaded APHE and conserves typed stock")
	var service := AmmunitionSupply.new()
	# Deterministic timer fixture calls the same public supply transaction; window demo handles normal driving separately.
	var before := gun.rounds_remaining
	service.step(scene.actor,1.99,true)
	check(gun.rounds_remaining==before,"supply waits full two simulated seconds")
	service.step(scene.actor,0.01,true)
	check(gun.rounds_remaining==before+1 and gun.inventory.conserved(),"supply commits exactly one typed round")
	for i in 30: service.step(scene.actor,2.0,true)
	check(gun.rounds_remaining==20 and gun.inventory.shell_counts()==gun.initial_shell_counts,"supply stops at configured type counts below physical capacity")
	await frames(150)
	gun.inventory.consume_chamber() # Explicit fixture debit, counted as fired in the same ledger.
	before=gun.rounds_remaining
	scene.actor.supply_motion_active=true; service.step(scene.actor,10.0,true); scene.actor.supply_motion_active=false
	check(gun.rounds_remaining==before,"moving input cannot obtain parked supply")
	service.step(scene.actor,10.0,false)
	check(gun.rounds_remaining==before,"enemy or outside area cannot supply")
	scene.actor.state.recovery_enabled=true; VehicleRecovery.ignite(scene.actor.state,"engine")
	service.step(scene.actor,10.0,true)
	check(gun.rounds_remaining==before,"active fire prevents ammunition supply")
	scene.actor.state.fires.clear()
	gun.inventory.lose_all(); gun.advance_timers(10.0)
	var shots_before := gun.shots_fired
	check(not gun.try_fire() and gun.shots_fired==shots_before and gun.cooldown_left==0,"empty gun refuses launch without starting fictitious loading")
	scene.actor.reset_vehicle()
	check(gun.rounds_remaining==20 and gun.inventory.chamber_shell=="test_ap120" and gun.inventory.conserved(),"vehicle reset restores original typed manifest exactly once")
	player_case_complete=true
	scene.queue_free(); await frames(3)

func historical_loadout_case(id: String) -> void:
	var scene := BallisticsRange.new(); scene.selected_vehicle_id=id; root.add_child(scene); await frames(20)
	var gun := scene.actor.gunner
	var initial := gun.inventory.snapshot()
	var loaded := gun.inventory.chamber_shell
	var alternate := 1 if gun.shell_options[0].id==loaded else 0
	await action("shell_2" if alternate==1 else "shell_1")
	await action("fire")
	check(gun.shots_fired==1 and gun.inventory.transfer_shell==gun.shell_options[alternate].id,id+": actual input fires default and carries alternate historical shell")
	await frames(800)
	await action("fire")
	check(gun.shots_fired==2 and gun.shell.id==gun.shell_options[alternate].id and gun.inventory.conserved() and gun.rounds_remaining==initial.available-2,id+": natural reload fires alternate with exact total debit")
	var alien := gun.shell_options[0].duplicate(true) as ShellDefinition; alien.allowed_vehicle_ids=["unrelated_vehicle"]
	var before := gun.inventory.snapshot()
	check(not gun.configure_shell_loadout([alien],{alien.id:10},alien.id) and gun.inventory.snapshot()==before,id+": incompatible historical shell cannot replace live ledger")
	scene.actor.reset_vehicle()
	check(gun.inventory.shell_counts()==gun.initial_shell_counts and gun.inventory.chamber_shell==loaded and gun.inventory.conserved(),id+": restart restores original two-type manifest")
	scene.free(); await frames(3); historical_cases_complete+=1

func village_supply_case() -> void:
	var scene := VillageRange.new(); scene.selected_vehicle_id=VehicleCatalog.IDS[0]; root.add_child(scene); await frames(195)
	check(scene.team_ready and scene.director.state.phase=="playing","real village starts the supply integration case")
	var vehicle := scene.actor
	vehicle.set_controller(null)
	# Position fixture isolates zone recognition; natural physics clock and real game loop perform replenishment.
	vehicle.gunner.inventory.consume_chamber(); vehicle.gunner.inventory.begin_transfer(); vehicle.gunner.cooldown_left=vehicle.weapon.reload_time
	var before := vehicle.gunner.rounds_remaining
	var center: Vector3 = scene.supply_positions(2)[0]; center.y=vehicle.tank.global_position.y
	vehicle.tank.global_position=center; vehicle.tank.velocity=Vector3.ZERO; vehicle.tank.forward_speed=0
	await frames(140)
	check(vehicle.gunner.rounds_remaining==before,"enemy village supply area cannot replenish player ammunition")
	center=scene.supply_positions(1)[0]; center.y=vehicle.tank.global_position.y
	vehicle.tank.global_position=center; vehicle.tank.velocity=Vector3.ZERO; vehicle.tank.forward_speed=0
	await frames(60)
	check(vehicle.gunner.rounds_remaining==before,"friendly village zone waits the actual replenishment interval")
	await frames(90)
	check(vehicle.gunner.rounds_remaining==before+1 and vehicle.gunner.inventory.shell_counts()==vehicle.gunner.initial_shell_counts and vehicle.gunner.inventory.conserved(),"real village physics loop supplies exactly one missing historical type")
	var life := vehicle.life_id
	scene.abandon_vehicle(); await frames(495); scene.request_respawn(); await frames(8)
	check(scene.actor.life_id!=life and scene.actor.gunner.inventory.shell_counts()==scene.actor.gunner.initial_shell_counts and scene.actor.gunner.inventory.conserved(),"normal timed respawn starts a fresh conserved two-shell manifest")
	village_case_complete=true; scene.free(); await frames(3)

func _run() -> void:
	inventory_cases()
	catalog_cases()
	world = Node3D.new(); root.add_child(world)
	var defs := VehicleDefs.new(); check(defs.load_defaults().ok,"real vehicle definitions load")
	target = VehicleActor.new(); world.add_child(target)
	check(target.setup(defs,"player_tank","target",2,Transform3D(Basis.IDENTITY,Vector3(0,10,-20)),4,null).ok,"real target actor loads")
	manager = ProjectileManager.new(); world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(self,"apply_damage")
	await physics_frame
	effect_cases()
	check(runtime_cases==10,"all ten production effect cases executed")
	world.queue_free(); await process_frame
	await player_and_supply_cases()
	check(player_case_complete,"all real-input and supply cases reached completion")
	for id in VehicleCatalog.IDS: await historical_loadout_case(id)
	check(historical_cases_complete==4,"all four real historical two-shell firing flows completed")
	await village_supply_case()
	check(village_case_complete,"real village supply and respawn flow completed")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("SHELL_CHECKS_PASS" if failed==0 else "SHELL_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
