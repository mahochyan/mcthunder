extends SceneTree
## WT-040-R1: probe the two PROJECT GLBs in assets/vehicles/modern_bound with the project's OWN probe,
## so the binding is derived from the real artefact rather than guessed. Reuses ModelBindingProbe, which
## resolves each role against real node names and reports a missing or ambiguous role by name.
const IDS := ["ussr_t_80b","germ_leopard_2a4"]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var out := {}
	for id in IDS:
		var path := "res://assets/vehicles/modern_bound/%s.glb" % id
		var report: Dictionary = ModelBindingProbe.probe(path)
		var interesting: Array = []
		for row in report.get("nodes",[]):
			var nm := str(row.get("name",""))
			if nm.begins_with("Attachment_") or nm in ["HullArmour","TurretPivot","GunPivot","Muzzle","RunningLeft","RunningRight","VehicleRoot","MainGun","MainGunAndMuzzleBrake"]:
				interesting.append(str(row.get("path","")))
		report.erase("nodes")
		report["interesting_paths"] = interesting
		out[id] = report
	print("[probe] ", JSON.stringify(out,"  "))
	print("MODERN_BOUND_PROBE_DONE")
	quit(0)