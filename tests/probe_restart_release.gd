extends SceneTree
## WT-036-R1: fast, targeted probe for the pre-existing red
## "restart frees old world and preserves selected map industrial_edge".
## It mirrors the industrial suite's setup, then reports exactly which clause fails and why, so the
## question "product defect or fixture timing" is answered in seconds instead of a 24 minute suite.
const APP_SCENE = preload("res://scenes/app.tscn")
var app: Node
func _initialize() -> void: call_deferred("_run")
func frames(n: int = 3) -> void:
	for i in n: await process_frame
func _run() -> void:
	var id := "industrial_edge"
	app = APP_SCENE.instantiate()
	root.add_child(app); current_scene = app
	await frames(20)
	app.garage.preparation.map_choice.select(MapRegistry.IDS.find(id))
	var selected: Dictionary = app.garage.preparation.build_match()
	print("[restart-probe] build_match ok=%s map=%s" % [str(selected.ok),str(selected.config.map_id()) if selected.ok else "-"])
	app.enter_laboratory("team")
	for i in 240:
		await process_frame
		if app.training != null and app.training is VillageRange and app.training.team_ready: break
	var scene: VillageRange = app.training as VillageRange
	if scene == null:
		print("[restart-probe] FAILED to reach a team range"); quit(1); return
	print("[restart-probe] entered map=%s actors=%d transitioning=%s" % [scene.definition.id,scene.combat_actors().size(),str(app._transitioning)])
	var old_id: Variant = scene.get_round_id()
	var previous: WeakRef = weakref(scene)
	app.restart_match()
	var waited := 0
	for i in 600:
		await process_frame
		waited = i
		if app.training != null and is_instance_valid(app.training) and app.training is VillageRange and app.training.team_ready:
			if app.training.get_round_id() != old_id: break
	var new_scene: VillageRange = app.training as VillageRange
	var released: bool = previous.get_ref() == null
	var new_round: bool = new_scene != null and is_instance_valid(new_scene) and new_scene.get_round_id() != old_id
	var map_kept: bool = new_scene != null and is_instance_valid(new_scene) and new_scene.definition.id == MapRegistry.definition(id).id
	print("[restart-probe] after %d frames: old_released=%s new_round=%s map_kept=%s transitioning=%s" % [waited,str(released),str(new_round),str(map_kept),str(app._transitioning)])
	print("[restart-probe] VERDICT old_released=%s" % str(released))
	app.free(); await frames(2)
	quit(0 if released else 1)


