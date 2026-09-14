extends SceneTree
## WT-036-R1: fast, targeted probe for the pre-existing red
## "restart frees old world and preserves selected map industrial_edge".
## Setup now mirrors the industrial suite's transitions() exactly: AppFlow built directly, the
## vehicle choice selected AND emitted before building the match, then the map choice selected.
const IDS := ["industrial_edge","hill_village","industrial_edge"]
var app: Node
func _initialize() -> void: call_deferred("_run")
func frames(n: int = 3) -> void:
	for i in n: await process_frame
func _run() -> void:
	app = AppFlow.new(); root.add_child(app); current_scene = app
	await frames(4)
	var previous: WeakRef
	for id in IDS:
		app.garage.vehicle_choice.select(1)
		app.garage.vehicle_choice.item_selected.emit(1)
		app.garage.preparation.map_choice.select(MapRegistry.IDS.find(id))
		var selected: Dictionary = app.garage.preparation.build_match()
		var frozen: bool = bool(selected.get("ok",false)) and str(selected.config.map_id()) == id
		print("[restart-probe] id=%s build_match ok=%s frozen_map=%s" % [id,str(selected.get("ok",false)),str(frozen)])
		app.enter_laboratory("team"); await frames(8)
		var scene: VillageRange = app.training as VillageRange
		var entered: String = scene.definition.id if scene != null else "<none>"
		var old_id: Variant = scene.get_round_id() if scene != null else null
		if previous != null:
			print("[restart-probe]   previous_freed=%s" % str(previous.get_ref() == null))
		var before: WeakRef = weakref(scene)
		app.restart_match(); await frames(8)
		var now: VillageRange = app.training as VillageRange
		var released: bool = before.get_ref() == null
		var new_round: bool = now != null and is_instance_valid(now) and now.get_round_id() != old_id
		var map_kept: bool = now != null and is_instance_valid(now) and now.definition.id == MapRegistry.definition(id).id
		print("[restart-probe]   entered=%s released=%s new_round=%s map_kept=%s (want entered=%s)" % [
			entered,str(released),str(new_round),str(map_kept),id])
		previous = weakref(app.training)
		app.return_to_garage(); await frames(8)
	print("[restart-probe] DONE")
	app.free(); await frames(2)
	quit(0)

