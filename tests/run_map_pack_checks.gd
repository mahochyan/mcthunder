extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var packed := load("res://scenes/maps/map_hill_village.tscn") as PackedScene
	if packed == null: print("[FAIL] packed village scene missing"); quit(1); return
	var scene := packed.instantiate() as VillageRange
	root.add_child(scene)
	current_scene = scene
	for i in 12: await physics_frame
	var ok := scene.team_ready and scene.combat_actors().size() == 8 and scene.nav.valid and scene.battle_ui != null and scene.terrain != null
	print(("[PASS] " if ok else "[FAIL] ")+"exported PCK loads village, eight actors, navigation, Chinese HUD and terrain")
	scene.free()
	print("MAP_PACK_CHECKS_PASS" if ok else "MAP_PACK_CHECKS_FAIL")
	quit(0 if ok else 1)
