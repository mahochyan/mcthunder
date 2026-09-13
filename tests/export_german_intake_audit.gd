extends SceneTree
## WT-030D-R2: read-only intake audit of the author-side German model set.
##
## Enumerates `<root>\*\vehicle.glb`, and per vehicle records the measured bytes, SHA-256,
## triangle count, envelope, unit candidate and how many of the six binding roles resolve.
## It copies nothing, modifies nothing and never writes into the source tree; its only output
## is a JSON report plus a printed summary, so "what is registration-ready and what still
## needs author work" becomes a per-vehicle list instead of a guess.
const DEFAULT_ROOT := "E:/AIprogram/aimodel/德国"
const REPORT_PATH := "res://logs/WT-030D-r2/german_intake_audit.json"
const TRIANGLE_BUDGET := 15000
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var source_root: String = args[0] if args.size() > 0 else DEFAULT_ROOT
	print("[intake] source root=",source_root)
	var dir := DirAccess.open(source_root)
	if dir == null:
		print("[intake] FAILED: cannot open source root")
		quit(1); return
	var rows: Array[Dictionary] = []
	var missing: Array[String] = []
	var triangles_over := 0
	var roles_full := 0
	var roles_partial := 0
	var roles_none := 0
	var total_bytes := 0
	var total_triangles := 0
	var folders := dir.get_directories()
	folders.sort()
	for folder in folders:
		var path := "%s/%s/vehicle.glb" % [source_root,folder]
		if not FileAccess.file_exists(path):
			missing.append(folder)
			continue
		var report := ModelBindingProbe.probe(path)
		if not report.get("ok",false):
			missing.append(folder+"(unparsable:"+str(report.get("reason",""))+")")
			continue
		var resolved: int = ModelBindingValidator.ROLES.size()-report.unresolved_roles.size()
		if resolved == 0: roles_none += 1
		elif resolved == ModelBindingValidator.ROLES.size(): roles_full += 1
		else: roles_partial += 1
		var triangles := int(report.triangles)
		if triangles > TRIANGLE_BUDGET: triangles_over += 1
		total_bytes += int(report.bytes)
		total_triangles += triangles
		rows.append({"folder":folder,"bytes":int(report.bytes),"sha256":str(report.sha256),
			"triangles":triangles,"nodes":int(report.node_count),"meshes":int(report.mesh_count),
			"longest_m":float(report.longest_m),"unit":str(report.unit_candidate),
			"roles_resolved":resolved,"roles_unresolved":report.unresolved_roles.duplicate()})
	print("[intake] folders=",folders.size()," audited=",rows.size()," missing_or_unparsable=",missing.size())
	print("[intake] bytes=%.1f MB triangles total=%d avg=%d" % [float(total_bytes)/1048576.0,total_triangles,
		int(total_triangles/maxf(1.0,float(rows.size())))])
	print("[intake] triangle budget <=%d : over=%d ; roles 6/6=%d partial=%d none=%d"%[TRIANGLE_BUDGET,triangles_over,roles_full,roles_partial,roles_none])
	var worst: Array = rows.duplicate()
	worst.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.triangles) > int(b.triangles))
	for i in min(5,worst.size()):
		print("[intake]   top triangles: %s %d (%d roles resolved)"%[str(worst[i].folder),int(worst[i].triangles),int(worst[i].roles_resolved)])
	if not missing.is_empty():
		print("[intake] missing_or_unparsable list (first 10): ",missing.slice(0,10))
	var payload := {"schema":1,"source_root":source_root,"folders":folders.size(),"audited":rows.size(),
		"missing_or_unparsable":missing,"total_bytes":total_bytes,"total_triangles":total_triangles,
		"triangle_budget":TRIANGLE_BUDGET,"triangles_over_budget":triangles_over,
		"roles_full":roles_full,"roles_partial":roles_partial,"roles_none":roles_none,
		"note":"read-only: no source file was created, modified, moved or deleted","rows":rows}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-030D-r2"))
	var file := FileAccess.open(REPORT_PATH,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload,"  ")+"\n")
		file.close()
		print("[intake] wrote ",REPORT_PATH)
	print("GERMAN_INTAKE_AUDIT_DONE")
	quit(0)
