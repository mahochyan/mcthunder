extends SceneTree
## Explicit HUD state fixture via production damage events, not a natural battle proof.
var checks := 0
var failed := 0
var event_index := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func item(data: Dictionary, id: String) -> Dictionary:
	for row in data.get("items",[]):
		if row.id==id: return row
	return {}
func hit(actor: VehicleActor, id: String, fraction: float, crew: bool = false) -> void:
	event_index+=1
	var event := {"kind":"crew" if crew else "module","entity_id":actor.entity_id,"life_id":actor.life_id,
		"target_generation":actor.state.generation,"event_id":"damage_hud_%d"%event_index,"round_id":current_scene.get_round_id()}
	event["crew_id" if crew else "module_id"]=id
	var budget := 1.0 if crew else float(actor.state.module_states[id].resistance_mm)*fraction
	actor.apply_projectile_damage(event,budget)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("user://tests/vehicle_damage_hud")
	DirAccess.make_dir_recursive_absolute(path)
	var error := root.get_texture().get_image().save_png(path+"/"+name+".png")
	check(error==OK,"actual HUD capture: "+name)
	print("DAMAGE_HUD_CAPTURE="+path+"/"+name+".png")

func run() -> void:
	if DisplayServer.get_name()=="headless": root.size=Vector2i(1280,720)
	create_timer(180,true,false,true).timeout.connect(func()->void: print("DAMAGE_HUD_TIMEOUT"); quit(2))
	var vehicle_ids: Array=Array(VehicleCatalog.IDS)+Array(VehicleCatalog.ENGINEERING_IDS)
	for id in vehicle_ids:
		var scene: RiverTeamRange=load(MapRegistry.scene_path("river_junction_team")).instantiate()
		scene.selected_vehicle_id=id
		if id in VehicleCatalog.ENGINEERING_IDS:
			scene.opposing_engineering_id="germ_leopard_2a4" if id=="ussr_t_80b" else "ussr_t_80b"
		root.add_child(scene); current_scene=scene
		await frames(200)
		check(scene.team_ready,id+": actual river and normal HUD initialise")
		if not scene.team_ready: scene.free(); continue
		scene.director.set_physics_process(false)
		for actor in scene.combat_actors(): actor.set_physics_process(false)
		var actor := scene.actor
		var before := actor.state.damage_snapshot()
		var view := VehicleDamageView.sample(actor)
		check(view.items.size()==actor.damage_layout_override.modules.size()+actor.damage_layout_override.crew_stations.size(),id+": every real module and crew station is represented")
		check(view.shell.size()==actor.damage_layout_override.armor_patches.size(),id+": hull outline comes from actual armor patches")
		for i in 25: VehicleDamageView.sample(actor)
		check(actor.state.damage_snapshot()==before,id+": presentation is read-only")
		var hud := scene.battle_ui.overlay
		await frames(12)
		check(hud.damage_diagram.is_visible_in_tree() and hud.damage_diagram.snapshot.vehicle_id==id,id+": cutaway is present in ordinary battle HUD")
		await capture(id+"_intact")
		for row in [["engine",.15,"light"],["breech",.5,"heavy"],["transmission",.8,"critical"],["track_left",1.0,"disabled"]]:
			hit(actor,row[0],row[1])
			check(item(VehicleDamageView.sample(actor),row[0]).condition==row[2],id+": production damage maps "+row[0]+" to "+row[2])
		var gunner_id := ""
		for station in actor.damage_layout_override.crew_stations:
			if station.role=="gunner": gunner_id=station.id
		check(not gunner_id.is_empty(),id+": actual gunner station exists")
		if not gunner_id.is_empty():
			hit(actor,gunner_id,1,true)
			check(item(VehicleDamageView.sample(actor),gunner_id).condition=="disabled",id+": crew incapacity follows real assignment state")
		await frames(12)
		check(item(hud.damage_diagram.snapshot,"track_left").condition=="disabled",id+": displayed diagram refreshes after actual damage")
		var viewport_size := hud.get_viewport_rect().size
		print("HUD_BOUNDS panel=",hud.own_panel.get_global_rect()," viewport=",viewport_size)
		check(hud.own_panel.get_global_rect().end.y<=viewport_size.y and hud.own_panel.get_global_rect().position.y>viewport_size.y*.25,id+": HUD panel remains within the battle viewport")
		await capture(id+"_damaged")
		actor.reset_vehicle(); await frames(12)
		check(item(hud.damage_diagram.snapshot,"engine").condition=="intact" and item(hud.damage_diagram.snapshot,gunner_id).condition=="crew",id+": reset clears old module and crew damage colours")
		var initial := VehicleDamageView.sample(actor)
		actor.turret.set_aim_point(actor.turret.global_position+Vector3(30,0,-30))
		actor.turret.snap_to_aim()
		var turned := VehicleDamageView.sample(actor)
		check(not item(initial,"breech").points[0].is_equal_approx(item(turned,"breech").points[0]) and item(initial,"engine").points[0].is_equal_approx(item(turned,"engine").points[0]),id+": real turret turn moves breech geometry without moving hull modules")
		hit(actor,"track_left",1)
		var repair := VehicleCommand.new(); repair.repair_requested=true
		actor._apply_command_once(repair,1.0/60.0)
		check(item(VehicleDamageView.sample(actor),"track_left").repairing,id+": active repair marks its actual module")
		for i in 900: actor._apply_command_once(VehicleCommand.new(),1.0/60.0)
		var repaired := item(VehicleDamageView.sample(actor),"track_left")
		check(is_equal_approx(repaired.fraction,RecoveryRules.REPAIR_TARGET) and repaired.condition=="heavy" and not repaired.repairing,id+": production field repair shows actual half integrity, not fictitious full health")
		AccessibilitySettings.ui_scale=1.25
		scene.battle_ui.apply_settings(); await frames(12)
		check(hud.own_panel.get_global_rect().end.y<=hud.get_viewport_rect().size.y,id+": large text keeps damage display on screen")
		await capture(id+"_large_text")
		AccessibilitySettings.ui_scale=1.0
		scene.free(); await frames(3)
	check(checks>=18*vehicle_ids.size(),"all six vehicle fixtures reach their final checks")
	print("=== result: %d checks, %d failed ==="%[checks,failed])
	print("DAMAGE_HUD_CHECKS_PASS" if failed==0 else "DAMAGE_HUD_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
