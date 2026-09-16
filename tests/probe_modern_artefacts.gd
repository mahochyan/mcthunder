extends SceneTree
## WT-040-R1: probe BOTH candidate artefacts for each modern vehicle with the project's own probe, so the
## binding target is chosen from evidence rather than assumed. assets/vehicles/adapters is what the
## geometry pipeline measured; assets/vehicles/modern_bound is the model currently bound. They are two
## different artefacts and only one of them can be both measured and bound.
const CANDIDATES := [
	"res://assets/vehicles/adapters/ussr_t_80b/vehicle_adapter.glb",
	"res://assets/vehicles/modern_bound/ussr_t_80b.glb",
	"res://assets/vehicles/adapters/germ_leopard_2a4/vehicle_adapter.glb",
	"res://assets/vehicles/modern_bound/germ_leopard_2a4.glb",
]
const WANT := ["HullArmour","TurretPivot","GunPivot","Muzzle","MuzzlePoint","RunningLeft","RunningRight","Attachment_breech","Attachment_gunner","Attachment_driver"]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for path in CANDIDATES:
		var report: Dictionary = ModelBindingProbe.probe(path)
		if not report.get("ok",false):
			print("[cmp] ",path," MISSING_OR_UNREADABLE reason=",report.get("reason",""))
			continue
		var have: Array = []
		for row in report.get("nodes",[]):
			if str(row.get("name","")) in WANT: have.append(str(row.get("name","")))
		var missing: Array = []
		for want in WANT:
			if not have.has(want): missing.append(want)
		var states := {}
		for role in report.get("roles",{}).keys():
			states[role] = report.roles[role].state
		print("[cmp] ",path)
		print("      bytes=",report.bytes," tris=",report.triangles," nodes=",report.node_count,
			" unit=",report.unit_candidate," envelope=",report.envelope_m," sha=",str(report.sha256).substr(0,16))
		print("      roles=",states," unresolved=",report.unresolved_roles)
		print("      missing_wanted_nodes=",missing)
	print("MODERN_ARTEFACT_COMPARISON_DONE")
	quit(0)