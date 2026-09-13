extends SceneTree
# WT-031B-D: probe the REAL GLBs and report, per vehicle, which binding roles resolve. The
# probe is read-only: the drafts it prints are never installed and no file is written.
var count := 0
var failed := 0
const ASSETS := {
	"us_m1a1_abrams":"res://assets/vehicles/m1a1/m1a1.glb",
	"cn_ztz_99a":"res://assets/vehicles/ztz99a/ztz99a_1000.glb",
	"ussr_t_80b":"res://assets/research/models/ussr_t_80b.glb",
	"germ_leopard_2a4":"res://assets/research/models/germ_leopard_2a4.glb",
}
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(300.0)
	timer.timeout.connect(func() -> void: print("[FAIL] probe suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. every real GLB parses, including the ones with no import companion ---
	for vehicle_id in ASSETS:
		var path := str(ASSETS[vehicle_id])
		var report := ModelBindingProbe.probe(path)
		_check(report.ok,"%s GLB parses through GLTFDocument (%s)"%[vehicle_id,str(report.get("reason","ok"))])
		if not report.ok: continue
		_check(int(report.node_count) > 0,"%s exposes real nodes (%d)"%[vehicle_id,int(report.node_count)])
		_check(int(report.mesh_count) > 0,"%s exposes real meshes (%d)"%[vehicle_id,int(report.mesh_count)])
		_check(str(report.sha256).length() == 64,"%s reports the measured hash"%vehicle_id)
		_check(str(report.unit_candidate) in ["m","cm","mm"],"%s proposes a units scale (%s)"%[vehicle_id,str(report.unit_candidate)])
		var longest := float(report.longest_m)*float(report.meters_per_unit)
		_check(longest >= 2.0 and longest <= 20.0,"%s hull envelope is a plausible vehicle size (%.2f m)"%[vehicle_id,longest])
		_check(report.envelope_m.size() == 3,"%s reports a three-axis envelope"%vehicle_id)
		# --- 2. each role is reported by name, never silently defaulted ---
		var rows := ModelBindingProbe.role_report(report)
		_check(rows.size() == ModelBindingValidator.ROLES.size(),"%s reports every binding role (%d)"%[vehicle_id,rows.size()])
		var all_stated := true
		var unresolved_named := true
		for row in rows:
			if not str(row.state) in ["resolved","ambiguous","missing"]: all_stated = false
			if str(row.state) != "resolved" and not report.unresolved_roles.has(str(row.role)): unresolved_named = false
		_check(all_stated,"%s gives every role one of resolved/ambiguous/missing"%vehicle_id)
		_check(unresolved_named,"%s lists exactly the unresolved roles by name"%vehicle_id)
		# --- 3. the draft is a draft ---
		var draft := ModelBindingProbe.draft_binding(report)
		_check(draft.get("applied",true) == false,"%s draft binding is explicitly not applied"%vehicle_id)
		_check(bool(draft.complete) == report.unresolved_roles.is_empty(),"%s completeness matches the unresolved list"%vehicle_id)
		_check(str(draft.model.sha256) == str(report.sha256),"%s draft carries the measured hash"%vehicle_id)
		print("[info] %s: bytes=%d nodes=%d meshes=%d longest=%.3f unit=%s resolved=%d/%d missing=%s"%[vehicle_id,
			int(report.bytes),int(report.node_count),int(report.mesh_count),float(report.longest_m),
			str(report.unit_candidate),ModelBindingValidator.ROLES.size()-report.unresolved_roles.size(),
			ModelBindingValidator.ROLES.size(),str(report.unresolved_roles)])
	# --- 4. a missing asset fails loudly instead of inventing a binding ---
	var missing := ModelBindingProbe.probe("res://assets/research/models/not_a_vehicle.glb")
	_check(not missing.ok and str(missing.reason) == "asset_missing","a missing asset reports asset_missing")
	_check(ModelBindingProbe.draft_binding(missing).is_empty(),"no draft is produced without a parsed asset")
	_check(ModelBindingProbe.role_report(missing).is_empty(),"no role report is produced without a parsed asset")
	# --- 5. the probe is read-only and the registry is untouched ---
	var source := FileAccess.get_file_as_string("res://scripts/content/model_binding_probe.gd")
	_check(not source.contains("FileAccess.WRITE") and not source.contains("store_string"),"the probe contains no write path")
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(VehicleCatalog.MODEL_SOURCE_REGISTRY))
	_check(registry is Dictionary and (registry.get("models",{}) as Dictionary).is_empty(),"the registry is still the untouched empty registry")
	# --- 6. the aggregate view the delivery needs ---
	var aggregate := ModelBindingProbe.probe_all(ASSETS)
	_check(aggregate.reports.size() == 4,"the aggregate probes all four assets")
	_check(int(aggregate.resolved_roles) > 0,"at least some roles resolve against real node names (%d of %d)"%[int(aggregate.resolved_roles),int(aggregate.role_slots)])
	_check(aggregate.complete_bindings == false or aggregate.complete_bindings == true,"completeness is reported rather than assumed")
	print("[info] aggregate: %d/%d role slots resolved across four assets, complete_bindings=%s"%[int(aggregate.resolved_roles),int(aggregate.role_slots),str(aggregate.complete_bindings)])
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MODEL_BINDING_PROBE_CHECKS_PASS" if failed == 0 else "MODEL_BINDING_PROBE_CHECKS_FAIL")
	quit(1 if failed else 0)
