extends SceneTree
## WT-040-R1 Stage 3: admit the two engineering vehicles through the PRODUCTION loader - not through the gap
## audit's own packet assembly - and report exactly what the catalog admitted or rejected. This is the step
## the ruling calls "the normal content loader reads it, then engineering admission": the same register()
## path the historical vehicles use, with the full pipeline validation and the model binding check against
## the delivered artefact. A vehicle that does not appear in defs.vehicles is a failure, not a note.
##
## Every vehicle is printed AS IT IS ADMITTED, so a slow or hanging one leaves evidence instead of an empty
## log; an earlier version printed only after load_all and produced nothing at all when it timed out.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var defs := VehicleDefs.new()
	var t0 := Time.get_ticks_msec()
	var catalog := VehicleCatalog.new()
	print("[admit] catalog.new = ",Time.get_ticks_msec()-t0," ms; registry errors=",catalog.model_source_errors.size())
	if not catalog.model_source_errors.is_empty():
		for error in catalog.model_source_errors: print("[admit]   ! ",str(error))
	var failed := 0
	for id in VehicleCatalog.IDS:
		var t1 := Time.get_ticks_msec()
		var file := FileAccess.open("res://configs/vehicles/historical/"+id+".json",FileAccess.READ)
		if file == null:
			print("[admit] historical ",id," MISSING"); failed += 1; continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		var result: Dictionary = catalog.register(parsed,defs)
		print("[admit] historical ",id," = ",Time.get_ticks_msec()-t1," ms ok=",result.get("ok",false))
		for error in result.get("errors",[]): print("[admit]   ! ",str(error))
	for id in VehicleCatalog.ENGINEERING_IDS:
		var t2 := Time.get_ticks_msec()
		var efile := FileAccess.open(VehicleCatalog.ENGINEERING_DIR+id+".json",FileAccess.READ)
		if efile == null:
			print("[admit] engineering ",id," MISSING PACKET"); failed += 1; continue
		var eparsed: Variant = JSON.parse_string(efile.get_as_text())
		var eresult: Dictionary = catalog.register(eparsed,defs)
		var elapsed := Time.get_ticks_msec()-t2
		var has_vehicle: bool = defs.vehicles.has(id)
		var has_packet: bool = defs.content_packets.has(id)
		var has_source: bool = defs.model_sources.has(id)
		var layout_id := ""
		if has_packet: layout_id = str((defs.content_packets[id] as Dictionary).get("id",""))+"_layout"
		var has_layout: bool = defs.layouts.has(layout_id)
		print("[admit] engineering ",id," = ",elapsed," ms ok=",eresult.get("ok",false),
			" vehicle=",has_vehicle," packet=",has_packet," model_source=",has_source," layout=",has_layout," (",layout_id,")")
		for error in eresult.get("errors",[]): print("[admit]   ! ",str(error))
		if has_vehicle:
			var v: Variant = defs.vehicles[id]
			# Only property accesses that certainly exist, and get() for the rest: an unguarded access threw,
			# which skipped quit() and left the process alive until it was killed - the real reason two earlier
			# runs timed out with an apparently empty log.
			print("        admitted definition: id=",v.id," display_name_key=",str(v.get("display_name_key"))," tier=",str(v.get("content_tier"))," admission=",str(v.get("admission_status")),
				" ; defs now hold weapons=",defs.weapons.size()," shells=",defs.shells.size()," layouts=",defs.layouts.size())
		else:
			failed += 1
		if catalog.rejected.has(id):
			print("        REJECTED: ",catalog.rejected[id])
			failed += 1
	print("[admit] all loaded ids: ",defs.vehicles.keys())
	print("[admit] rejected: ",catalog.rejected.keys())
	print("ENGINEERING_ADMISSION_PASS" if failed == 0 else "ENGINEERING_ADMISSION_FAIL")
	quit(0 if failed == 0 else 1)
