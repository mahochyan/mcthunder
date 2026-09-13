class_name RoleMappingAudit
extends RefCounted
## WT-031C-D: read-only role resolution over an arbitrary model set.
##
## Corrections after review of 3fba101:
##   * resolution scans EVERY node, not only meshes - the author assets carry empty pivots
##     (`TurretPivot`, `GunPivot`) that a mesh-only scan misses, so the earlier "38 vehicles
##     have real author gaps" figure does not hold and is withdrawn;
##   * roles resolve to a FULL relative path with its parent recorded, and the local axis is
##     checked against the mechanism's convention instead of trusting a node name;
##   * the muzzle is measured per vehicle (a real muzzle node, else the forward extremity of
##     the gun mesh). The earlier constant offset labelled `provenance="author"` is withdrawn:
##     there was no per-vehicle measurement behind it;
##   * vehicles are classified (armed single turret / multi-launcher / unarmed) because a
##     six-role single-turret scheme must not be forced onto unarmed or multi-launcher hulls.
##
## Nothing is installed, registered or written into any asset; the muzzle frame an install
## would need is an adapter artifact that must be produced separately with its own hash.

const PIVOT_HINTS := {
	"turret":["turretpivot","turret_pivot","turretroot","turret_root","turretmount","turm"],
	"gun":["gunpivot","gun_pivot","gunroot","gun_root","gunmount","barrelpivot"],
}
const HINTS := {
	"hull":["hullarmour","hullarmor","sidearmour","hull","body","wanne"],
	"turret":["turretarmour","turret","turm","rotatingplatform","launcherpedestal","cupola"],
	"gun":["maingunandmuzzl","maingun","barrel","kanone","rohr","cannon","gun"],
	"muzzle":["muzzle"],
	"running_left":["track_l","trackleft","laufwerk_l","wheel_l","wheels_l","lefttrack"],
	"running_right":["track_r","trackright","laufwerk_r","wheel_r","wheels_r","righttrack"],
}
## Some chassis model the running gear as ONE node (e.g. `SixPneumaticWheelsAndSuspension`).
## That is a real authoring style, not a missing role: it is reported as an unsplit group that
## needs an authored left/right split instead of being counted as absent.
const RUNNING_GROUP_HINTS := ["sixpneumaticwheels","runninggear","laufwerk","suspension","kette",
	"wheelsand","tracksand","wheels","tracks"]
## Roles whose hint must match exactly or as a prefix: `muzzle` must really be a muzzle node,
## not the `...AndMuzzleBrake` compound gun mesh.
const STRICT_ROLES := ["muzzle"]
## Each class is judged by its own role set. Forcing the single-turret six roles onto
## unarmed trucks, radar/FCS vehicles or multi-launcher carriers produced phantom gaps.
const EXPECTED_BY_CLASS := {
	"single_turret":["hull","turret","gun","muzzle","running_left","running_right"],
	"multi_launcher":["hull","running_left","running_right"],
	"support_unarmed":["hull","running_left","running_right"],
	"unarmed":["hull","running_left","running_right"],
}
const LAUNCHER_HINTS := ["launcher","missile","container","radar","reflector"]
const GUN_MESH_HINTS := ["maingunandmuzzl","maingun","barrel","kanone","rohr","cannon"]
const AXIS_EPS := 0.02

static func _vec3(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() == 3: return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.ZERO

static func _candidates(nodes: Array, hints: Array, strict: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for hint in hints:
		found.clear()
		for row in nodes:
			var lowered := str(row.name).to_lower()
			var hit := false
			if strict: hit = lowered == str(hint) or lowered.begins_with(str(hint))
			else: hit = lowered.contains(str(hint))
			if hit: found.append(row)
		if not found.is_empty(): break
	return found

static func _entry_for(row: Dictionary) -> Dictionary:
	return {"kind":"node","node":str(row.name),"path":str(row.path),"parent":str(row.parent),
		"type":str(row.type),"origin":row.origin,"forward":row.forward,"up":row.up,
		"aabb_min":row.get("aabb_min",[0.0,0.0,0.0]),"aabb_max":row.get("aabb_max",[0.0,0.0,0.0])}

static func _basis_of(row: Dictionary) -> Basis:
	var up := _vec3(row.up)
	var forward := _vec3(row.forward)
	var right := forward.cross(up)
	if right.length() < 0.001: right = Vector3.RIGHT
	return Basis(right.normalized(),up.normalized(),-forward.normalized())

## Compose a point from a target node's local space up to a frame node's local space by
## walking the recorded parent chain, so a measured muzzle offset is expressed in the frame
## the binding actually uses instead of one arbitrary node's space.
static func _compose_point(rows_by_path: Dictionary, target_path: String, frame_path: String, local_point: Vector3) -> Dictionary:
	var chain: Array[String] = []
	var cursor := target_path
	var guard := 0
	while not cursor.is_empty() and guard < 64:
		guard += 1
		chain.push_front(cursor)
		if not frame_path.is_empty() and cursor == frame_path: break
		var row: Dictionary = rows_by_path.get(cursor,{})
		cursor = str(row.get("parent",""))
	var xform := Transform3D.IDENTITY
	for path in chain:
		var row: Dictionary = rows_by_path.get(path,{})
		xform = xform*Transform3D(_basis_of(row),_vec3(row.origin))
	var point := xform*local_point
	return {"point_m":[point.x,point.y,point.z],"chain":chain}

static func resolve(probe_report: Dictionary) -> Dictionary:
	var roles: Dictionary = {}
	if not probe_report.get("ok",false):
		return {"ok":false,"reason":str(probe_report.get("reason","unparsable")),"roles":roles,
			"node_roles":0,"ambiguous_roles":0,"missing_roles":ModelBindingValidator.ROLES.size(),
			"vehicle_class":"unknown","muzzle_state":"unknown"}
	var nodes: Array = probe_report.get("nodes",[])
	var counts := {"node":0,"ambiguous":0,"missing":0}
	for role in ModelBindingValidator.ROLES:
		# 1) an authored pivot wins (non-mesh nodes only), 2) then the name hints.
		var candidates := _candidates(nodes,PIVOT_HINTS.get(role,[]),false)
		if candidates.size() != 1:
			candidates = _candidates(nodes,HINTS.get(role,[]),STRICT_ROLES.has(role))
		if candidates.size() == 1:
			roles[role] = _entry_for(candidates[0])
		elif candidates.size() > 1:
			var paths: Array[String] = []
			for row in candidates: paths.append(str(row.path))
			roles[role] = {"kind":"ambiguous","candidates":paths.slice(0,8),"count":paths.size()}
		else:
			roles[role] = {"kind":"missing"}
		counts[str(roles[role].kind)] = int(counts.get(str(roles[role].kind),0))+1
	# measured muzzle: a real muzzle node, else the forward extremity of the BARREL MESH -
	# never the gun pivot's origin, which sits at the breech side and is not a muzzle.
	var muzzle_state := "unmeasured"
	if str(roles.muzzle.kind) == "node":
		muzzle_state = "authored_node"
	else:
		var barrels := _candidates(nodes,GUN_MESH_HINTS,false)
		var meshes: Array[Dictionary] = []
		for row in barrels:
			if str(row.type) == "mesh": meshes.append(row)
		if meshes.size() == 1:
			var barrel: Dictionary = meshes[0]
			var max_z := _vec3(barrel.aabb_max).z
			var min_z := _vec3(barrel.aabb_min).z
			var extremity := max_z if absf(max_z) >= absf(min_z) else min_z
			var rows_by_path := {}
			for row in nodes: rows_by_path[str(row.path)] = row
			var barrel_path := str(barrel.path)
			var in_root := _compose_point(rows_by_path,barrel_path,"",Vector3(0.0,0.0,extremity))
			var turret_path := ""
			if str(roles.turret.kind) == "node": turret_path = str(roles.turret.path)
			var in_turret := _compose_point(rows_by_path,barrel_path,turret_path,Vector3(0.0,0.0,extremity)) if not turret_path.is_empty() else {"point_m":[],"chain":[]}
			roles.muzzle = {"kind":"measured_frame","parent":barrel_path,
				"offset_in_root_m":in_root.point_m,"offset_in_turret_m":in_turret.point_m,
				"frame_chain_root":in_root.chain,"frame_chain_turret":in_turret.chain,
				"barrel_extent_z_m":extremity,"barrel_z_range_m":[min_z,max_z],
				"muzzle_within_envelope":absf(float(in_root.point_m[2])) <= float(probe_report.get("envelope_m",[0,0,0])[2])*0.5,
				"forward_convention":"barrel's longer side along local -Z (matches the mechanism's forward)",
				"basis":{"forward":barrel.forward,"up":barrel.up},
				"method":"barrel_mesh_extremity_composed_through_parent_chain","provenance":"measured"}
			muzzle_state = "measured_frame"
			counts["missing"] = int(counts.get("missing",0))-1
			counts["measured"] = int(counts.get("measured",0))+1
		else:
			roles.muzzle = {"kind":"missing","reason":"no_muzzle_node_and_no_single_barrel_mesh","barrel_candidates":meshes.size()}
	# local axis checks against the mechanism convention (turret +Y yaw, gun +X elevation).
	# Axis convention is only meaningful for a node that exists: an absent role is reported
	# as "n/a", never as a deviation, so "no gun" cannot masquerade as "bad gun axis".
	var axis_checks := {}
	axis_checks["turret"] = "n/a"
	axis_checks["gun"] = "n/a"
	var axis_notes: Array[String] = []
	if str(roles.turret.kind) == "node":
		var turret_ok := _vec3(roles.turret.up).distance_to(Vector3.UP) <= AXIS_EPS
		axis_checks["turret"] = turret_ok
		if not turret_ok: axis_notes.append("turret %s up=%s deviates from +Y" % [str(roles.turret.path),str(roles.turret.up)])
	if str(roles.gun.kind) == "node":
		var gun_ok := _vec3(roles.gun.forward).distance_to(Vector3.FORWARD) <= AXIS_EPS
		axis_checks["gun"] = gun_ok
		if not gun_ok: axis_notes.append("gun %s forward=%s deviates from -Z" % [str(roles.gun.path),str(roles.gun.forward)])
	var launcher_paths: Array[String] = []
	for row in nodes:
		for hint in LAUNCHER_HINTS:
			if str(row.name).to_lower().contains(str(hint)):
				launcher_paths.append(str(row.path))
				break
	# A single running-gear node is an authoring style, not an absent role: both sides then
	# point at that group and are reported as unsplit so the gap is "author a split", not
	# "author a missing role".
	if str(roles.running_left.kind) != "node" and str(roles.running_right.kind) != "node":
		var group_meshes: Array[Dictionary] = []
		for row in _candidates(nodes,RUNNING_GROUP_HINTS,false):
			if str(row.type) == "mesh": group_meshes.append(row)
		if group_meshes.size() == 1:
			for role in ["running_left","running_right"]:
				roles[role] = {"kind":"group_unsplit","node":str(group_meshes[0].name),
					"path":str(group_meshes[0].path),"parent":str(group_meshes[0].parent),
					"reason":"single_running_group_needs_authored_left_right_split"}
	var launchers := launcher_paths.size()
	var armed: bool = str(roles.gun.kind) == "node" or str(roles.gun.kind) == "measured_frame"
	var vehicle_class := "unarmed"
	if armed and launchers >= 2: vehicle_class = "multi_launcher"
	elif armed: vehicle_class = "single_turret"
	elif launchers >= 1: vehicle_class = "support_unarmed"
	var expected: Array = EXPECTED_BY_CLASS.get(vehicle_class,[])
	var class_missing: Array[String] = []
	for role in expected:
		var kind := str(roles.get(role,{}).get("kind","missing"))
		# A measured frame satisfies the role: the muzzle in these assets has no node and is
		# measured from the barrel, so demanding kind == "node" marked every tank incomplete.
		if kind != "node" and kind != "measured_frame": class_missing.append(str(role))
	var needs_launcher: bool = vehicle_class in ["multi_launcher","support_unarmed"]
	var class_ready: bool = class_missing.is_empty() and (launchers >= 1 or not needs_launcher)
	# Recompute the tallies from the final role table so an earlier incremental count cannot
	# leave a role counted as missing after it was resolved or measured.
	counts = {"node":0,"ambiguous":0,"missing":0,"measured":0,"group_unsplit":0}
	for role in ModelBindingValidator.ROLES:
		var kind := str(roles[role].kind)
		counts[kind] = int(counts.get(kind,0))+1
	var missing_roles: Array[String] = []
	for role in ModelBindingValidator.ROLES:
		if str(roles[role].kind) == "missing": missing_roles.append(role)
	return {"ok":true,"roles":roles,"counts":counts,"node_roles":int(counts.node),
		"measured_roles":int(counts.get("measured",0)),"ambiguous_roles":int(counts.ambiguous)+int(counts.get("group_unsplit",0)),
		"group_unsplit_roles":int(counts.get("group_unsplit",0)),
		"missing_roles":int(counts.missing),"missing_role_names":missing_roles,
		"vehicle_class":vehicle_class,"launcher_nodes":launchers,"launcher_paths":launcher_paths,
		"expected_roles":expected,"class_missing_roles":class_missing,"class_ready":class_ready,
		"axis_checks":axis_checks,"axis_notes":axis_notes,
		"muzzle_state":muzzle_state,
		"binding_ready":int(counts.get("missing",0)) == 0 and int(counts.get("ambiguous",0)) == 0,
		"note":"shape-only: hierarchy, muzzle direction, combat layout and internal modules still require check_scene()/check_file()"}

## Draft binding in the consumer's exact shape (see model_binding_validator.gd::_shape).
## Measured values only: the envelope, the source unit and the resolution come from the
## probe; the axis limits are game-design values and are labelled as such; nothing here
## claims author provenance.
const DRAFT_TURRET_LIMITS_DEG := [-180.0,180.0]
const DRAFT_GUN_LIMITS_DEG := [-8.0,20.0]

static func draft_binding(asset_root: String, folder: String, probe_report: Dictionary, result: Dictionary) -> Dictionary:
	var nodes := {}
	var pending: Array[String] = []
	if result.get("ok",false):
		for role in ModelBindingValidator.ROLES:
			var entry: Dictionary = result.roles.get(role,{})
			match str(entry.get("kind","")):
				"node": nodes[role] = str(entry.path)
				_: pending.append("%s(%s)"%[role,str(entry.get("kind","missing"))])
	var envelope: Array = probe_report.get("envelope_m",[0.0,0.0,0.0])
	return {"schema_version":1,"vehicle_id":folder,
		"model":{"path":"%s/%s/vehicle.glb"%[asset_root,folder],"sha256":str(probe_report.get("sha256","")),
			"source_vehicle_id":folder},
		"units":{"dimensions_m":envelope,
			"source_unit":str(probe_report.get("unit_candidate","m")),
			"meters_per_unit":float(probe_report.get("meters_per_unit",1.0)),
			"tolerance_fraction":0.02,"attachment_tolerance_m":0.02},
		"axes":{"turret":{"space":"local","axis":[0,1,0],"limits_deg":DRAFT_TURRET_LIMITS_DEG},
			"gun":{"space":"local","axis":[1,0,0],"limits_deg":DRAFT_GUN_LIMITS_DEG}},
		"internal_attachments":{"modules":{},"crew":{}},
		"nodes":nodes,"_pending_author_steps":pending,"_axis_limits_provenance":"game_design"}

static func registration_blockers(asset_root: String, folder: String, probe_report: Dictionary, result: Dictionary) -> Dictionary:
	var draft := draft_binding(asset_root,folder,probe_report,result)
	var pending: Array = draft.get("_pending_author_steps",[])
	var binding := draft.duplicate(true)
	binding.erase("_pending_author_steps")
	binding.erase("_axis_limits_provenance")
	var shape: Array = []
	if (binding.nodes as Dictionary).size() > 0:
		shape = ModelBindingValidator._shape(binding,folder)
	# Three separate blocker classes, never merged: structural shape, author data, and the two
	# decisions that live outside this repository (intake authorisation and licence basis).
	var structure_errors: Array = []
	for error in shape:
		if str(error).contains("path"): continue
		structure_errors.append(error)
	var path_gate := str(draft.model.path).begins_with("res://assets/vehicles/")
	return {"shape_errors":shape,"structure_errors":structure_errors,
		"pending_author_steps":pending,"node_roles_resolved":int((binding.nodes as Dictionary).size()),
		"vehicle_class":str(result.get("vehicle_class","unknown")),
		"muzzle_state":str(result.get("muzzle_state","unknown")),
		"axis_checks":result.get("axis_checks",{}),
		"path_inside_repo":path_gate,
		"path_gate":"internal" if path_gate else "external_needs_intake_authorisation",
		"licence":"unknown","licence_gate":"needs_licence_basis",
		"adapter_artifact_required":bool(result.get("muzzle_state","") == "measured_frame"),
		"check_scene_run":false,"check_file_run":false,
		"registration_ready":structure_errors.is_empty() and pending.is_empty() and path_gate}

static func summary_line(folder: String, result: Dictionary) -> String:
	if not result.get("ok",false): return "%s: UNPARSABLE (%s)"%[folder,str(result.get("reason",""))]
	var parts: Array[String] = []
	for role in ModelBindingValidator.ROLES:
		var entry: Dictionary = result.roles.get(role,{})
		match str(entry.get("kind","")):
			"node": parts.append("%s=%s"%[role,str(entry.path)])
			"measured_frame": parts.append("%s=measured(%s)"%[role,str(entry.parent)])
			"ambiguous": parts.append("%s=AMBIGUOUS(%d)"%[role,int(entry.count)])
			_: parts.append("%s=MISSING"%role)
	return "%s [%s]: ready=%s node=%d measured=%d ambiguous=%d missing=%d axis=%s | %s"%[folder,
		str(result.vehicle_class),str(result.binding_ready),int(result.node_roles),int(result.measured_roles),
		int(result.ambiguous_roles),int(result.missing_roles),str(result.axis_checks)," ".join(parts)]
