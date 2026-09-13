extends SceneTree
## Read-only role-mapping audit over the author-side German model set (96 vehicles).
##
## For each `<root>\*\vehicle.glb` it resolves the six binding roles with the evidence-based
## hint table, then writes a per-vehicle report so "which vehicle still needs an authored
## role" is a list rather than an assumption. It installs nothing, registers nothing and
## writes only inside the repository's logs directory.
const DEFAULT_ROOT := "E:/AIprogram/aimodel/德国"
const REPORT_PATH := "res://logs/WT-031C-r2/german_role_mapping.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	# A script error must not leave the tree idling: the watchdog reports and exits.
	var watchdog := create_timer(600.0)
	watchdog.timeout.connect(func() -> void:
		print("[role] WATCHDOG timeout: aborting inconclusively")
		quit(3))
	var args := OS.get_cmdline_user_args()
	var source_root: String = args[0] if args.size() > 0 else DEFAULT_ROOT
	var dir := DirAccess.open(source_root)
	if dir == null:
		print("[role] cannot open ",source_root); quit(1); return
	var folders := dir.get_directories(); folders.sort()
	var rows: Array[Dictionary] = []
	var ready := 0
	var unparsable := 0
	var role_missing := {"hull":0,"turret":0,"gun":0,"muzzle":0,"running_left":0,"running_right":0}
	var role_ambiguous := {"hull":0,"turret":0,"gun":0,"muzzle":0,"running_left":0,"running_right":0}
	var role_node := {"hull":0,"turret":0,"gun":0,"muzzle":0,"running_left":0,"running_right":0}
	var role_measured := {"hull":0,"turret":0,"gun":0,"muzzle":0,"running_left":0,"running_right":0}
	var class_counts := {}
	var class_ready_counts := {}
	var class_not_ready := {}
	var missing_by_role := {}
	var adapter_needed := 0
	var axis_turret_bad := 0
	var axis_gun_bad := 0
	var axis_turret_ok := 0
	var axis_gun_ok := 0
	var axis_turret_na := 0
	var axis_gun_na := 0
	var shape_clean := 0
	var pending_any := 0
	var path_inside := 0
	var licence_blocked := 0
	var registration_ready := 0
	for folder in folders:
		var path := "%s/%s/vehicle.glb" % [source_root,folder]
		if not FileAccess.file_exists(path): continue
		var probe := ModelBindingProbe.probe(path)
		var result := RoleMappingAudit.resolve(probe)
		if not result.get("ok",false):
			unparsable += 1
			rows.append({"folder":folder,"ok":false,"reason":result.get("reason","unparsable")})
			continue
		if bool(result.binding_ready): ready += 1
		var blockers := RoleMappingAudit.registration_blockers(source_root,folder,probe,result)
		if (blockers.shape_errors as Array).is_empty() and int(blockers.node_roles_resolved) > 0: shape_clean += 1
		if not (blockers.pending_author_steps as Array).is_empty(): pending_any += 1
		if bool(blockers.path_inside_repo): path_inside += 1
		if str(blockers.licence_gate) == "blocked_pending_source": licence_blocked += 1
		if bool(blockers.registration_ready): registration_ready += 1
		for role in ModelBindingValidator.ROLES:
			var kind := str(result.roles.get(role,{}).get("kind","missing"))
			match kind:
				"node": role_node[role] = int(role_node[role])+1
				"measured_frame": role_measured[role] = int(role_measured[role])+1
				"ambiguous": role_ambiguous[role] = int(role_ambiguous[role])+1
				"missing": role_missing[role] = int(role_missing[role])+1
		class_counts[str(result.vehicle_class)] = int(class_counts.get(str(result.vehicle_class),0))+1
		if bool(result.class_ready):
			class_ready_counts[str(result.vehicle_class)] = int(class_ready_counts.get(str(result.vehicle_class),0))+1
		else:
			class_not_ready[str(result.vehicle_class)] = int(class_not_ready.get(str(result.vehicle_class),0))+1
		if bool(blockers.adapter_artifact_required): adapter_needed += 1
		for role in result.missing_role_names: missing_by_role[str(role)] = int(missing_by_role.get(str(role),0))+1
		var turret_axis: Variant = result.axis_checks.get("turret",false)
		if turret_axis is bool:
			if bool(turret_axis): axis_turret_ok += 1
			else: axis_turret_bad += 1
		else: axis_turret_na += 1
		var gun_axis: Variant = result.axis_checks.get("gun",false)
		if gun_axis is bool:
			if bool(gun_axis): axis_gun_ok += 1
			else: axis_gun_bad += 1
		else: axis_gun_na += 1
		rows.append({"folder":folder,"ok":true,"ready":bool(result.binding_ready),
			"vehicle_class":str(result.vehicle_class),"muzzle_state":str(result.muzzle_state),
			"expected_roles":result.expected_roles,"class_missing_roles":result.class_missing_roles,
			"class_ready":bool(result.class_ready),"launcher_nodes":int(result.launcher_nodes),
			"axis_checks":result.axis_checks,"missing_role_names":result.missing_role_names,
			"node_roles":int(result.node_roles),"measured_roles":int(result.measured_roles),
			"ambiguous_roles":int(result.ambiguous_roles),"missing_roles":int(result.missing_roles),
			"triangles":int(probe.get("triangles",0)),"sha256":str(probe.get("sha256","")),
			"shape_errors":blockers.shape_errors,"pending_author_steps":blockers.pending_author_steps,
			"node_roles_resolved":int(blockers.node_roles_resolved),"path_gate":str(blockers.path_gate),
			"licence_gate":str(blockers.licence_gate),
			"adapter_artifact_required":bool(blockers.adapter_artifact_required),
			"check_scene_run":bool(blockers.check_scene_run),"check_file_run":bool(blockers.check_file_run),
			"registration_ready":bool(blockers.registration_ready),
			"roles":result.roles})
		print("[role] ",RoleMappingAudit.summary_line(folder,result))
	print("[role] folders=%d rows=%d binding_ready=%d unparsable=%d"%[folders.size(),rows.size(),ready,unparsable])
	print("[role] per role node/measured/ambiguous/missing:")
	for role in ModelBindingValidator.ROLES:
		print("[role]   %s: node=%d measured=%d ambiguous=%d missing=%d"%[role,int(role_node[role]),int(role_measured[role]),int(role_ambiguous[role]),int(role_missing[role])])
	print("[role] vehicle classes: ",class_counts)
	print("[role] class-ready (judged by each class's own roles): ",class_ready_counts)
	print("[role] class-not-ready: ",class_not_ready)
	print("[role] missing by role: ",missing_by_role)
	print("[role] axis convention: turret ok=%d bad=%d n/a=%d ; gun ok=%d bad=%d n/a=%d ; adapter artifact needed=%d"%[
		axis_turret_ok,axis_turret_bad,axis_turret_na,axis_gun_ok,axis_gun_bad,axis_gun_na,adapter_needed])
	var payload := {"schema":1,"source_root":source_root,"rows":rows,"binding_ready":ready,
		"unparsable":unparsable,"per_role":{"node":role_node,"ambiguous":role_ambiguous,"missing":role_missing},
		"draft_binding":{"shape_clean":shape_clean,"pending_author_steps":pending_any,
			"path_inside_repo":path_inside,"licence_blocked":licence_blocked,"registration_ready":registration_ready},
		"note":"read-only audit: nothing installed, nothing registered, no asset modified"}
	print("[role] draft binding: shape_clean=%d pending_author_steps=%d path_inside_repo=%d licence_blocked=%d registration_ready=%d"%[
		shape_clean,pending_any,path_inside,licence_blocked,registration_ready])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-031C-r2"))
	var file := FileAccess.open(REPORT_PATH,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload,"  ")+"\n")
		file.close()
		print("[role] wrote ",REPORT_PATH)
	print("GERMAN_ROLE_MAPPING_DONE")
	quit(0)
