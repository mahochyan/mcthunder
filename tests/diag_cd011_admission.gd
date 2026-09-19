extends SceneTree
## A throwaway diagnostic: why do the two engineering packets refuse to admit after a drive profile was added?
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var defs := VehicleDefs.new()
	var r := defs.load_defaults()
	print("[diag] defs load ok=%s errors=%s" % [str(r.get("ok",false)),str(r.get("errors",[]))])
	var catalog := VehicleCatalog.new()
	var la := catalog.load_all(defs)
	print("[diag] load_all ok=%s" % str(la.get("ok",false)))
	for e in Array(la.get("errors",[])): print("[diag]   load_all error: %s" % str(e))
	var le := catalog.load_engineering(defs)
	print("[diag] load_engineering ok=%s errors=%s" % [str(le.get("ok",false)),str(le.get("errors",[]))])
	for e in Array(le.get("errors",[])): print("[diag]   engineering error: %s" % str(e))
	for vid in VehicleCatalog.ENGINEERING_IDS:
		var packet: Dictionary = catalog.packages.get(str(vid),{})
		print("[diag] %s packet keys=%s" % [str(vid),str(packet.keys())])
		var gate := HistoricalEvidenceGate.new()
		var g: Dictionary = gate.evaluate(packet)
		print("[diag] %s gate ok=%s errors=%s" % [str(vid),str(g.get("ok",false)),str(g.get("errors",[]))])
		var actor := VehicleActor.new(); root.add_child(actor)
		var s: Dictionary = actor.setup(defs,str(vid),"diag",1,Transform3D.IDENTITY,2,null)
		print("[diag] %s setup ok=%s errors=%s reason=%s" % [str(vid),str(s.get("ok",false)),str(s.get("errors",[])),str(s.get("reason",""))])
		actor.queue_free()
	quit(0)
