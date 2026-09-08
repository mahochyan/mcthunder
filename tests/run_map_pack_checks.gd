extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var ok := true
	for id in MapRegistry.IDS:
		var packed := load(MapRegistry.scene_path(id)) as PackedScene
		if packed == null: print("[FAIL] packed map missing "+id); quit(1); return
		var scene := packed.instantiate() as VillageRange
		scene.selected_vehicle_id = VehicleCatalog.IDS[0]
		root.add_child(scene)
		current_scene = scene
		for i in 12: await physics_frame
		var loaded := scene.team_ready and scene.combat_actors().size() == 8 and scene.nav.valid and scene.battle_ui != null and scene.terrain != null and scene.definition.id == MapRegistry.definition(id).id
		ok = ok and loaded
		print(("[PASS] " if loaded else "[FAIL] ")+"exported PCK loads "+id+", eight historical actors, navigation, Chinese HUD and terrain")
		scene.free()
		for i in 3: await physics_frame
	print("MAP_PACK_CHECKS_PASS" if ok else "MAP_PACK_CHECKS_FAIL")
	quit(0 if ok else 1)
