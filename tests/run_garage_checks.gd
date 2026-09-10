extends SceneTree
var count := 0
var failed := 0
var service: GarageService
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func _config(store: ProfileStore, ids: Array = [ResearchGraph.STARTER], mode: String = "normal") -> Dictionary:
	var settings: Dictionary = store.snapshot().garage
	settings.mode = mode; settings.lineup = ids; settings.selected_vehicle_id = ids[0]
	return MatchConfig.build(settings,service,store.snapshot().unlocked)
func _run() -> void:
	root.size = Vector2i(1280,720)
	service = GarageService.new()
	_check(service.ready,"historical catalogs admitted by garage service")
	for id in VehicleCatalog.IDS:
		var original := service.default_loadout(id)
		var built := service.build_loadout(original)
		_check(built.ok and built.inventory.available == built.inventory.capacity,"default manifest fills actual capacity: "+id)
		var keys: Array = original.counts.keys()
		var partial := original.duplicate(true)
		partial.counts[keys[0]] = 1; partial.counts[keys[1]] = 0; partial.first_shell = keys[0]
		var sparse := service.build_loadout(partial)
		_check(sparse.ok and sparse.inventory.chamber == 1 and sparse.inventory.racks.values().all(func(n: int) -> bool: return n == 0),"single chamber round leaves every real rack empty: "+id)
		for bad_kind in ["zero","negative","fraction","over","foreign","first_empty","wrong_vehicle"]:
			var bad := partial.duplicate(true)
			match bad_kind:
				"zero": bad.counts[keys[0]] = 0
				"negative": bad.counts[keys[1]] = -1
				"fraction": bad.counts[keys[1]] = 1.5
				"over": bad.counts[keys[0]] = built.inventory.capacity+1
				"foreign": bad.counts["alien_shell"] = 1
				"first_empty": bad.first_shell = keys[1]
				"wrong_vehicle": bad.vehicle_id = "test_vehicle"
			_check(not service.build_loadout(bad).ok,"reject "+bad_kind+": "+id)
	var store := ProfileStore.new("",service)
	_check(store.validate(store.snapshot()).ok,"fresh profile is schema valid")
	_check(not _config(store,[VehicleCatalog.IDS[1]]).ok,"formal mode rejects locked vehicle")
	_check(_config(store,VehicleCatalog.IDS.slice(1),"training").ok,"training permits all three locked vehicles")
	for ids in [[],[ResearchGraph.STARTER,ResearchGraph.STARTER],VehicleCatalog.IDS,["alien"]]:
		_check(not Lineup.validate(ids,ResearchGraph.STARTER,"training",[]).ok,"lineup invalid fixture "+str(ids))
	var before := store.snapshot()
	_check(not ResearchGraph.unlock(store,VehicleCatalog.IDS[2]).ok and store.snapshot() == before,"research dependency rejection is transactional")
	_check(ResearchGraph.unlock(store,VehicleCatalog.IDS[1]).ok and store.snapshot().research_points == 20,"real unlock subtracts 80 once")
	before = store.snapshot()
	_check(not ResearchGraph.unlock(store,VehicleCatalog.IDS[1]).ok and store.snapshot() == before,"duplicate unlock cannot spend again")
	_check(not ResearchGraph.unlock(store,VehicleCatalog.IDS[3]).ok and store.snapshot() == before,"insufficient research points preserve state")
	var valid := _config(store,[ResearchGraph.STARTER,VehicleCatalog.IDS[1]])
	var config: MatchConfig = valid.config
	var exposed := config.snapshot(); exposed.loadouts[ResearchGraph.STARTER].counts.clear(); exposed.lineup.clear()
	_check(config.vehicle_ids().size()==2 and not config.loadout(ResearchGraph.STARTER).counts.is_empty(),"match snapshot cannot be mutated by returned dictionaries")
	for kind in ["negative_points","fractional_points","dependency","unknown","duplicate","foreign_profile","negative_revision","bad_loadout","receipt","pending"]:
		var bad := store.snapshot()
		match kind:
			"negative_points": bad.research_points = -1
			"fractional_points": bad.research_points = 0.5
			"dependency": bad.unlocked.append(VehicleCatalog.IDS[2])
			"unknown": bad.unlocked.append("foreign")
			"duplicate": bad.unlocked.append(ResearchGraph.STARTER)
			"foreign_profile": bad.profile_id = "hello"
			"negative_revision": bad.revision = -1
			"bad_loadout": bad.garage.loadouts[ResearchGraph.STARTER].counts.clear()
			"receipt": bad.receipts[bad.profile_id+":0"] = {"outcome":"victory","points":999}
			"pending": bad.pending[bad.profile_id+":0"] = {"mode":"training","vehicle_id":ResearchGraph.STARTER}
		_check(not store.commit(bad).ok and store.snapshot()==before,"invalid profile rejected without mutation: "+kind)
	await _persistence()
	await _rewards(store,config)
	await _battle_flow()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed == 0: print("GARAGE_CHECKS_PASS")
	quit(0 if failed == 0 else 1)

func _persistence() -> void:
	var path := "user://tests/garage_022_"+str(Time.get_ticks_usec())+"/commander"
	var disk := ProfileStore.new(path,service)
	var next := disk.snapshot()
	var id: String = ResearchGraph.STARTER
	var keys: Array = next.garage.loadouts[id].counts.keys()
	next.garage.loadouts[id].counts[keys[0]] = 2; next.garage.loadouts[id].counts[keys[1]] = 1
	next.garage.difficulty = "hard"
	_check(disk.commit(next).ok,"atomic slot writes actual custom loadout")
	var restored := ProfileStore.new(path,service)
	_check(restored.snapshot() == disk.snapshot(),"JSON save restores exact typed counts, settings and profile identity")
	_check(ResearchGraph.unlock(disk,VehicleCatalog.IDS[1]).ok,"second slot persists real research transaction")
	var stale := restored.snapshot(); stale.research_points += 1
	_check(not restored.commit(stale).ok,"stale concurrent instance cannot overwrite newer progress")
	var fresh := ProfileStore.new(path,service)
	_check(fresh.snapshot().research_points == 20 and VehicleCatalog.IDS[1] in fresh.snapshot().unlocked,"restart restores unlocked research and balance")
	var corrupt := FileAccess.open(path+".0.json",FileAccess.WRITE); corrupt.store_string("{broken"); corrupt.close()
	var recovered := ProfileStore.new(path,service)
	_check(recovered.snapshot().revision == 1 and not recovered.problem.is_empty(),"damaged latest slot visibly restores previous valid slot")
	corrupt = FileAccess.open(path+".1.json",FileAccess.WRITE); corrupt.store_string("{broken"); corrupt.close()
	var blocked := ProfileStore.new(path,service)
	_check(not blocked.writable and not blocked.commit(blocked.snapshot()).ok,"two corrupt slots preserved and writes blocked")
	var blocked_path := "user://tests/not_a_folder_"+str(Time.get_ticks_usec())
	var marker := FileAccess.open(blocked_path,FileAccess.WRITE); marker.store_string("fixture"); marker.close()
	var failing := ProfileStore.new(blocked_path+"/commander",service)
	var unchanged := failing.snapshot()
	_check(not ResearchGraph.unlock(failing,VehicleCatalog.IDS[1]).ok and failing.snapshot()==unchanged,"write failure cannot subtract points or unlock in memory")
	# 029 small item (GPT ruling round two): lock age NEVER authorizes takeover —
	# only suspected-stale messaging; only own-pid leaks reclaim; release checks ownership.
	var lock_root := "user://tests/lockfix_"+str(Time.get_ticks_usec())
	var lock_path := lock_root+"/commander"
	DirAccess.make_dir_recursive_absolute(lock_root+"/commander.lock")
	var old_dead := FileAccess.open(lock_root+"/commander.lock/owner.txt",FileAccess.WRITE)
	old_dead.store_string("999998 %d" % (int(Time.get_unix_time_from_system())-3600)); old_dead.close()
	var suspect := ProfileStore.new(lock_path,service)
	var suspect_bump := suspect.snapshot(); suspect_bump.research_points += 7
	var refused_old := suspect.commit(suspect_bump)
	_check(not refused_old.ok and refused_old.reason.contains("疑似遗留") and FileAccess.file_exists(lock_root+"/commander.lock/owner.txt"),"old foreign lock is refused as suspected-stale and never auto-deleted by age alone")
	# Own-pid leak (an earlier release that never ran inside this live process) is the one reclaimable state.
	var leak := FileAccess.open(lock_root+"/commander.lock/owner.txt",FileAccess.WRITE)
	leak.store_string("%d %d" % [OS.get_process_id(), int(Time.get_unix_time_from_system())-30]); leak.close()
	var revived := ProfileStore.new(lock_path,service)
	var bump := revived.snapshot(); bump.research_points += 7
	_check(revived.commit(bump).ok,"own-pid leaked lock is reclaimed and the save proceeds")
	var after := ProfileStore.new(lock_path,service)
	_check(after.snapshot().research_points == bump.research_points and DirAccess.open(lock_root+"/commander.lock") == null,"reclaimed commit persisted and the lock was released")
	# GPT counterexample: a REAL live second process holds the lock; the game side must refuse
	# untouched, and the holder must later finish and release cleanly for a valid commit.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(lock_root))
	var child_path := ProjectSettings.globalize_path("res://")
	var holder := OS.create_process(OS.get_executable_path(),["--headless","--path",child_path.trim_suffix("/"),"-s","res://tests/lock_holder_029.gd","--",lock_path,"12"])
	var stamp_seen := false
	var deadline := Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline and not stamp_seen:
		await process_frame
		stamp_seen = FileAccess.file_exists(lock_root+"/commander.lock/owner.txt")
	_check(stamp_seen and holder > 0,"real second process acquired the lock with a fresh stamp")
	var holder_store := ProfileStore.new(lock_path,service)
	var want := holder_store.snapshot(); want.research_points += 3
	var live_refused := holder_store.commit(want)
	_check(not live_refused.ok and FileAccess.file_exists(lock_root+"/commander.lock/owner.txt"),"live external holder lock is refused with the holder stamp untouched")
	var released := false
	deadline = Time.get_ticks_msec()+60000
	while Time.get_ticks_msec() < deadline and not released:
		await process_frame
		released = not FileAccess.file_exists(lock_root+"/commander.lock/owner.txt")
	_check(released and holder_store.commit(want).ok and ProfileStore.new(lock_path,service).snapshot().research_points == want.research_points,"holder exits cleanly and only then the save proceeds")
	await process_frame

func _rewards(store: ProfileStore, config: MatchConfig) -> void:
	var progression := ProgressionService.new(store)
	var registration := progression.register_match(config)
	_check(registration.ok and not registration.token.is_empty(),"normal match token persisted before battle")
	var director := TeamMatchDirector.new(); root.add_child(director); director.begin(); director.set_physics_process(false)
	_check(progression.bind_director(registration.token,director),"registered match bound to actual director")
	var before := store.snapshot()
	_check(not progression.apply_result_once(registration.token,{"outcome":"victory"}).ok and store.snapshot()==before,"premature fabricated outcome rejected")
	# Explicit mathematical fixture: real director advances through countdown and full 600s timeout.
	director.advance(3.0); director.advance(600.0)
	_check(director.state.phase=="finished" and director.state.result.outcome=="draw","actual director creates timeout result for equal tickets")
	var reward := progression.apply_result_once(registration.token,director.state.result)
	_check(reward.ok and reward.points==40 and store.snapshot().research_points==60,"authoritative draw awards exactly 40 in one transaction")
	before = store.snapshot()
	var again := progression.apply_result_once(registration.token,director.state.result)
	_check(again.ok and again.duplicate and again.points==0 and store.snapshot()==before,"reopened result has no duplicate award")
	var new_service := ProgressionService.new(store)
	_check(new_service.apply_result_once(registration.token,director.state.result).points==0 and store.snapshot()==before,"persisted receipt prevents award after service restart")
	_check(not progression.apply_result_once("unregistered",director.state.result).ok,"unknown match rejected")
	var second := progression.register_match(config)
	_check(second.ok and second.token != registration.token,"next session gets distinct persistent token")
	var other := TeamMatchDirector.new(); root.add_child(other); other.begin(); other.set_physics_process(false)
	progression.bind_director(second.token,other)
	other.finish_once("abandoned","player_returned")
	var abandoned := progression.apply_result_once(second.token,other.state.result)
	_check(abandoned.ok and abandoned.points==0 and store.snapshot().research_points==60,"early exit consumes pending match without reward")
	var third := progression.register_match(config)
	var final_director := TeamMatchDirector.new(); root.add_child(final_director); final_director.begin(); final_director.set_physics_process(false)
	progression.bind_director(third.token,final_director)
	final_director.advance(3); final_director.advance(600)
	store.writable = false; store.problem = "injected save outage"
	before = store.snapshot()
	_check(not progression.apply_result_once(third.token,final_director.state.result).ok and store.snapshot()==before,"reward save failure leaves pending and points untouched")
	var result: Dictionary = final_director.state.result.duplicate(true); final_director.free()
	store.writable = true; store.problem = ""
	_check(progression.apply_result_once(third.token,result).points == 40,"verified result can retry after scene freed without inventing a new result")
	director.free(); other.free(); await process_frame

func _battle_flow() -> void:
	var app: AppFlow = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	app.profile = ProfileStore.new("",service)
	root.add_child(app); current_scene = app
	await _frames()
	app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
	app.garage._view_mode = 1; app.garage._apply_preview_mode()
	for i in app.garage.inspection_choice.item_count:
		app.garage._select_inspection(i)
		var patch_id: String = app.garage.inspection_choice.get_item_metadata(i).id
		for patch in app.garage.preview.layout.armor_patches:
			if patch.id == patch_id:
				_check(app.garage.inspection_value.text.contains("%.1f mm"%patch.thickness_mm) if patch.has_thickness else app.garage.inspection_value.text.contains("厚度未知"),"selected armor display follows actual admitted data: "+patch_id)
	app.garage._view_mode = 2; app.garage._apply_preview_mode()
	_check(app.garage.inspection_choice.item_count == app.garage.preview.layout.modules.size()+app.garage.preview.layout.crew_stations.size(),"inspection exposes all real modules and crew stations")
	var preparation := app.garage.preparation
	var id: String = ResearchGraph.STARTER
	var keys: Array = preparation.loadouts[id].counts.keys()
	preparation.shell_spins[keys[0]].value = 0; preparation.shell_spins[keys[1]].value = 0
	app.enter_laboratory("team")
	_check(app.training==null and app.garage.error_label.text.contains("至少"),"invalid all-zero loadout stays in usable garage")
	app.garage.vehicle_choice.select(2); app.garage._select_vehicle(2)
	app.garage.vehicle_choice.select(1); app.garage._select_vehicle(1)
	_check(preparation.shell_spins.size()==2 and int(preparation.shell_spins[keys[0]].value)==0,"switching back to invalid edited loadout retains working controls for correction")
	preparation.shell_spins[keys[0]].value = 1; preparation.shell_spins[keys[1]].value = 0
	app.garage._view_mode = 2; app.garage._apply_preview_mode()
	var preview_racks: Dictionary = service.build_loadout(preparation.loadouts[id]).inventory.racks
	_check(preview_racks.keys().all(func(rack: String) -> bool: return not app.garage.preview._module_nodes[rack].visible),"garage interior hides precisely the empty physical racks")
	_check(not app.garage.preview.find_children("*","VehicleActor",true,false).size(),"preview has no live battle actor")
	preparation.mode_choice.select(1); preparation._mode_changed(1)
	app.garage.vehicle_choice.select(2); app.garage._select_vehicle(2)
	_check(not preparation.build_match().ok,"locked selected vehicle produces visible configuration rejection")
	preparation._research()
	_check(preparation.build_match().ok and app.profile.snapshot().research_points==20,"garage unlock makes selected M24 eligible")
	var m24: String = VehicleCatalog.IDS[1]
	var m24_keys: Array = preparation.loadouts[m24].counts.keys()
	preparation.shell_spins[m24_keys[0]].value = 2; preparation.shell_spins[m24_keys[1]].value = 3
	preparation.first_choice.select(1); preparation._ammo_changed()
	preparation.difficulty_choice.select(0)
	var confirmed := preparation.build_match().config as MatchConfig
	app.enter_laboratory("team"); await _frames(15)
	var battle := app.training as TeamRange
	_check(battle != null and battle.team_ready,"configured garage launches actual village battle")
	if battle == null: app.free(); return
	_check(battle.actor.definition.id==m24 and battle.actor.gunner.inventory.shell_counts()==confirmed.loadout(m24).counts and battle.actor.gunner.inventory.chamber_shell==confirmed.loadout(m24).first_shell,"initial actor uses confirmed vehicle, typed counts and first shell")
	_check(battle.prepared_match.snapshot()==confirmed.snapshot() and battle.vehicle_choice.item_count==2,"battle and respawn menu share frozen lineup")
	await _frames(190)
	var previous_life := battle.actor.life_id
	battle.abandon_vehicle()
	await _frames(500)
	for i in battle.vehicle_choice.item_count:
		if battle.vehicle_choice.get_item_metadata(i)==id: battle.vehicle_choice.select(i)
	battle.request_respawn(); await _frames(20)
	_check(battle.actor.life_id != previous_life and battle.actor.definition.id==id,"natural eight second respawn uses chosen second lineup vehicle")
	_check(battle.actor.gunner.inventory.shell_counts()==confirmed.loadout(id).counts and battle.actor.gunner.inventory.racks==preview_racks,"respawn ammo and empty rack allocations equal garage preview")
	var before: int = app.profile.snapshot().research_points
	battle.leave_match(); await _frames(5)
	_check(app.garage != null and app.profile.snapshot().research_points==before and app.last_result.progression.points==0,"actual early return shows zero reward and retains balance")
	_check(app.garage.preparation.loadouts==app.profile.snapshot().garage.loadouts,"return restores every saved per-vehicle loadout")
	app.free(); await _frames()
