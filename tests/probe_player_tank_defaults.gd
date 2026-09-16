extends SceneTree
## WT-040-R1: run the DEFAULT definitions load in THIS tree and print the verdict verbatim, so a failure in
## the package can be told apart from a failure that already exists in the source. No assumptions: the same
## load_defaults() the game calls is what runs here.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var defs := VehicleDefs.new()
	var result: Dictionary = defs.load_defaults()
	print("[probe] load_defaults ok=", result.get("ok",false))
	for e in result.get("errors",[]): print("[probe]   ! ", str(e))
	var v: Variant = load("res://configs/player_tank_vehicle.tres")
	print("[probe] resource loaded=", v != null)
	if v != null:
		print("[probe] validate=", v.validate().ok, " errors=", v.validate().errors)
		print("[probe] loading_profile=", v.loading_profile, " fire_control=", v.fire_control_profile,
			" optics=", v.optics_profile, " drive=", v.drive_profile)
	print("PLAYER_TANK_DEFAULTS_PROBE_DONE")
	quit(0)