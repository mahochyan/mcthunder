extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var ok := true
	var art_loaded: bool=ArtPalette.definition().get("schema_version",0)==1 and AssetManifestValidator.world_art().ok
	for id in VehicleCatalog.IDS:
		art_loaded=art_loaded and AssetManifestValidator.vehicle(id).ok
	ok=ok and art_loaded
	print(("[PASS] " if art_loaded else "[FAIL] ")+"exported PCK loads shared palette and all four relative GLB assets without Blender sources")
	var sounds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	var audio_loaded: bool=sounds.get("clips",{}).size()==13
	for clip in sounds.get("clips",{}).values(): audio_loaded=audio_loaded and load(clip.path) is AudioStreamWAV
	ok=ok and audio_loaded
	print(("[PASS] " if audio_loaded else "[FAIL] ")+"all thirteen original audio streams load from the isolated PCK")
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
		var structures:=scene.find_children("*","DestructibleSection",true,false)
		var structures_loaded:=structures.size()==8
		ok=ok and structures_loaded
		print(("[PASS] " if structures_loaded else "[FAIL] ")+id+": packaged map has eight intact destructible sections")
		print(("[PASS] " if loaded else "[FAIL] ")+"exported PCK loads "+id+", eight historical actors, navigation, Chinese HUD and terrain")
		scene.free()
		for i in 3: await physics_frame
	print("MAP_PACK_CHECKS_PASS" if ok else "MAP_PACK_CHECKS_FAIL")
	quit(0 if ok else 1)
