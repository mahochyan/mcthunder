extends SceneTree
## WT-040-R1: time the production admission path PER VEHICLE, printing as it goes, so a slow or hanging
## vehicle is named instead of leaving an empty log. The previous attempt printed only after load_all and
## therefore produced nothing at all when it timed out.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	print("[t] start")
	var defs := VehicleDefs.new()
	var t0 := Time.get_ticks_msec()
	var catalog := VehicleCatalog.new()
	print("[t] catalog.new = ",Time.get_ticks_msec()-t0," ms; registry errors=",catalog.model_source_errors.size())
	for id in VehicleCatalog.IDS:
		var t1 := Time.get_ticks_msec()
		var f := FileAccess.open("res://configs/vehicles/historical/"+id+".json",FileAccess.READ)
		if f == null: print("[t] historical ",id," MISSING"); continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		var r: Dictionary = catalog.register(parsed,defs)
		print("[t] historical ",id," = ",Time.get_ticks_msec()-t1," ms ok=",r.get("ok",false)," errors=",(r.get("errors",[]) as Array).size())
		for e in r.get("errors",[]): print("      ! ",str(e))
	for id in VehicleCatalog.ENGINEERING_IDS:
		var t2 := Time.get_ticks_msec()
		var f2 := FileAccess.open(VehicleCatalog.ENGINEERING_DIR+id+".json",FileAccess.READ)
		if f2 == null: print("[t] engineering ",id," MISSING"); continue
		var p2: Variant = JSON.parse_string(f2.get_as_text())
		var r2: Dictionary = catalog.register(p2,defs)
		print("[t] engineering ",id," = ",Time.get_ticks_msec()-t2," ms ok=",r2.get("ok",false)," errors=",(r2.get("errors",[]) as Array).size())
		for e in r2.get("errors",[]): print("      ! ",str(e))
	print("[t] admitted ids: ",defs.vehicles.keys())
	print("ENGINEERING_TIMING_DONE")
	quit(0)