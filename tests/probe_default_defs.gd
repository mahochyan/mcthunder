extends SceneTree
## WT-040-R1 probe: does the CURRENT tree's code construct the default vehicle profiles successfully?
## The exported package from 2026-09-15 logs "loading_profile: missing" for player_tank, whose .tres
## carries no profile keys at all, so the profiles must come from script defaults. If this probe passes
## on the current tree, that defect belongs to the OLD package and not to the current code - which is
## why running it matters before anyone spends effort "fixing" something already fixed.
## Read-only: loads definitions, prints the result, touches nothing.
func _init() -> void:
	var defs: VehicleDefs = VehicleDefs.new()
	var lr: Dictionary = defs.load_defaults()
	print("[defs-probe] load_defaults ok=%s" % str(lr.get("ok", false)))
	var errs: Array = lr.get("errors", [])
	print("[defs-probe] error count=%d" % errs.size())
	for e in errs:
		print("[defs-probe]   ! %s" % str(e))
	var ids: Array = defs.vehicles.keys() if defs.vehicles != null else []
	ids.sort()
	for id in ids:
		var v: Variant = defs.vehicles[id]
		if v == null:
			print("[defs-probe] %s -> NULL definition" % str(id))
			continue
		print("[defs-probe] %s loading=%s fire_control=%s optics=%s" % [
			str(id),
			str(v.loading_profile != null),
			str(v.fire_control_profile != null),
			str(v.optics_profile != null)])
	print("DEFS_PROBE_DONE")
	quit(0 if bool(lr.get("ok", false)) and errs.is_empty() else 1)
