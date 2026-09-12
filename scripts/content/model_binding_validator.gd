class_name ModelBindingValidator
extends RefCounted
## Checks authored bindings, never infers equipment or promotes a vehicle package.
const ROLES := ["hull","turret","gun","muzzle","running_left","running_right"]
const PART_ROLES := {"hull":"hull","turret":"turret","barrel":"gun","running_left":"running_left","running_right":"running_right","drive":"hull"}
const UNIT_SCALE := {"m":1.0,"cm":0.01,"mm":0.001}
const EPS := 0.0001

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _vector(value: Variant) -> bool:
	if not value is Array or value.size()!=3: return false
	for item in value:
		if not _number(item): return false
	return true

static func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func _sha(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character in value.to_lower():
		if character not in "0123456789abcdef": return false
	return true

static func _path(value: Variant) -> bool:
	if not value is String or value.is_empty() or value!=value.strip_edges(): return false
	if value==".": return true
	if value.begins_with("/") or value.contains(":") or value.contains("%") or value.contains("\\"): return false
	for segment in value.split("/"):
		if segment in ["",".",".."]: return false
	return true

static func _result(errors: Array[String], measured: Dictionary = {}) -> Dictionary:
	return {"ok":errors.is_empty(),"status":"binding_checked" if errors.is_empty() else "rejected",
		"scope":"model_binding_only","artifact_verified":false,"historical_verified":false,
		"vehicle_admission":"unchanged","errors":errors,"measured":measured}

static func _shape(binding: Variant, expected_vehicle_id: String) -> Array[String]:
	var errors: Array[String]=[]
	if not binding is Dictionary: return ["binding: expected dictionary"]
	for key in binding:
		if key not in ["schema_version","vehicle_id","model","units","nodes","axes","internal_attachments"]:
			errors.append("binding: unknown field "+str(key))
	if not _number(binding.get("schema_version")) or binding.schema_version!=1: errors.append("schema_version: expected 1")
	if expected_vehicle_id.is_empty() or not binding.get("vehicle_id") is String or binding.vehicle_id!=expected_vehicle_id:
		errors.append("vehicle_id: exact requested identity required")
	for key in ["model","units","nodes","axes","internal_attachments"]:
		if not binding.get(key) is Dictionary: errors.append(key+": expected dictionary")
	if not errors.is_empty(): return errors
	var model: Dictionary=binding.model
	if model.get("source_vehicle_id")!=expected_vehicle_id: errors.append("model.source_vehicle_id: exact identity required")
	if not model.get("path") is String or not str(model.get("path","")).to_lower().ends_with(".glb"):
		errors.append("model.path: explicit GLB artifact required")
	if not _sha(model.get("sha256")): errors.append("model.sha256: expected SHA256")
	var units: Dictionary=binding.units
	if not UNIT_SCALE.has(units.get("source_unit")): errors.append("units.source_unit: expected m/cm/mm")
	if not _number(units.get("meters_per_unit")) or float(units.get("meters_per_unit",0))<=0:
		errors.append("units.meters_per_unit: positive finite conversion required")
	elif UNIT_SCALE.has(units.get("source_unit")) and not is_equal_approx(float(units.meters_per_unit),float(UNIT_SCALE[units.source_unit])):
		errors.append("units.meters_per_unit: conversion disagrees with declared unit")
	if not _vector(units.get("dimensions_m")): errors.append("units.dimensions_m: finite XYZ envelope required")
	elif minf(float(units.dimensions_m[0]),minf(float(units.dimensions_m[1]),float(units.dimensions_m[2])))<=0:
		errors.append("units.dimensions_m: dimensions must be positive")
	if not _number(units.get("tolerance_fraction")) or float(units.get("tolerance_fraction",-1))<0 or float(units.get("tolerance_fraction",1))>0.1:
		errors.append("units.tolerance_fraction: explicit envelope tolerance within 0..0.1 required")
	if not _number(units.get("attachment_tolerance_m")) or float(units.get("attachment_tolerance_m",-1))<0 or float(units.get("attachment_tolerance_m",1))>0.1:
		errors.append("units.attachment_tolerance_m: explicit attachment tolerance within 0..0.1m required")
	var used := {}
	for role in ROLES:
		var path: Variant=binding.nodes.get(role)
		if not _path(path): errors.append("nodes."+role+": explicit canonical relative path required")
		elif used.has(path): errors.append("nodes."+role+": roles cannot share a node")
		else: used[path]=true
	for role in binding.nodes:
		if role not in ROLES: errors.append("nodes: unknown role "+str(role))
	for role in ["turret","gun"]:
		var axis: Variant=binding.axes.get(role)
		if not axis is Dictionary: errors.append("axes."+role+": explicit axis required"); continue
		if axis.get("space")!="local" or not _vector(axis.get("axis")):
			errors.append("axes."+role+": finite local axis required")
		elif _vec(axis.axis).distance_to(Vector3.UP if role=="turret" else Vector3.RIGHT)>EPS:
			errors.append("axes."+role+": current mechanism requires +Y yaw / +X elevation")
		var limits: Variant=axis.get("limits_deg")
		if not limits is Array or limits.size()!=2:
			errors.append("axes."+role+": two finite limits required")
		elif not _number(limits[0]) or not _number(limits[1]) or float(limits[0])>=float(limits[1]) or float(limits[0]) < -180 or float(limits[1])>180:
			errors.append("axes."+role+": invalid degree limits")
	for kind in ["modules","crew"]:
		if not binding.internal_attachments.get(kind) is Dictionary: errors.append("internal_attachments."+kind+": explicit ID map required")
	return errors

## Structural helper for an already instantiated scene. It cannot attest its bytes.
static func check_scene(binding: Variant, expected_vehicle_id: String, model_root: Node3D, layout: VehicleLayoutDefinition, geometry: Dictionary = {}, runtime: Dictionary = {}) -> Dictionary:
	var errors := _shape(binding,expected_vehicle_id)
	if not errors.is_empty(): return _result(errors)
	if not is_instance_valid(model_root): return _result(["model: missing Node3D root"])
	var transforms := {}; var stats := {"meshes":0,"bounds":AABB()}
	_walk(model_root,Transform3D.IDENTITY,transforms,stats,errors)
	var nodes := {}
	for role in ROLES:
		var node := model_root.get_node_or_null(NodePath(binding.nodes[role])) as Node3D
		if node==null: errors.append("nodes."+role+": missing Node3D at "+str(binding.nodes[role]))
		else: nodes[role]=node
	if nodes.has("hull"):
		for role in ["turret","running_left","running_right"]:
			if nodes.has(role) and not nodes.hull.is_ancestor_of(nodes[role]): errors.append("hierarchy."+role+": must descend from hull")
	if nodes.has("turret") and nodes.has("gun") and not nodes.turret.is_ancestor_of(nodes.gun): errors.append("hierarchy.gun: must descend from turret")
	if nodes.has("gun") and nodes.has("muzzle"):
		if not nodes.gun.is_ancestor_of(nodes.muzzle): errors.append("hierarchy.muzzle: must descend from gun")
		# GLB Empty nodes import as Node3D; their Godot Marker3D class is not portable.
		if nodes.muzzle is MeshInstance3D or nodes.muzzle.get_child_count()!=0: errors.append("nodes.muzzle: explicit empty marker required")
	for role in ["running_left","running_right"]:
		if nodes.has(role) and nodes.has("turret") and (nodes.turret.is_ancestor_of(nodes[role]) or nodes[role].is_ancestor_of(nodes.turret)):
			errors.append("hierarchy."+role+": running gear must be independent of turret")
	if nodes.has("running_left") and nodes.has("running_right") and (nodes.running_left.is_ancestor_of(nodes.running_right) or nodes.running_right.is_ancestor_of(nodes.running_left)):
		errors.append("hierarchy.running: left/right must be independent branches")
	if errors.is_empty(): _axes_and_muzzle(binding,nodes,transforms,errors)
	if errors.is_empty() and not geometry.is_empty(): _runtime_mounts(binding,nodes,transforms,geometry,runtime,errors)
	_validate_layout(binding,expected_vehicle_id,model_root,nodes,transforms,layout,errors)
	var measured := {}
	if stats.meshes<=0: errors.append("model: no finite nonempty mesh envelope")
	else:
		var bounds: AABB=stats.bounds
		var size: Vector3=bounds.size*float(binding.units.meters_per_unit)
		var expected := _vec(binding.units.dimensions_m)
		for axis in 3:
			if absf(size[axis]-expected[axis])>maxf(EPS,expected[axis]*float(binding.units.tolerance_fraction)):
				errors.append("units.dimensions_m: measured envelope differs on axis "+str(axis))
		measured={"dimensions_m":[size.x,size.y,size.z],"meshes":stats.meshes,"paths":binding.nodes.duplicate(true)}
	return _result(errors,measured)

## File entry uses a separately supplied exact-ID source registry record, then actual bytes.
static func check_file(binding: Variant, expected_vehicle_id: String, source_record: Dictionary, layout: VehicleLayoutDefinition, geometry: Dictionary = {}, runtime: Dictionary = {}, retain_scene: bool = false) -> Dictionary:
	var errors := _shape(binding,expected_vehicle_id)
	if not errors.is_empty(): return _result(errors)
	if source_record.get("id")!=expected_vehicle_id or source_record.get("path")!=binding.model.path:
		errors.append("source: registry identity/path differs from binding")
	if not _sha(source_record.get("sha256")) or str(source_record.get("sha256","")).to_lower()!=str(binding.model.sha256).to_lower():
		errors.append("source: registry SHA256 differs from binding")
	if not errors.is_empty(): return _result(errors)
	if not FileAccess.file_exists(binding.model.path): return _result(["model.path: artifact missing"])
	if FileAccess.get_sha256(binding.model.path).to_lower()!=str(binding.model.sha256).to_lower(): return _result(["model.sha256: actual bytes differ"])
	var container_errors := self_contained_glb(FileAccess.get_file_as_bytes(binding.model.path))
	if not container_errors.is_empty(): return _result(container_errors)
	var document := GLTFDocument.new(); var state := GLTFState.new()
	if document.append_from_file(binding.model.path,state)!=OK: return _result(["model: GLB decode failed"])
	var scene := document.generate_scene(state) as Node3D
	if scene==null: return _result(["model: GLB produced no Node3D scene"])
	var result := check_scene(binding,expected_vehicle_id,scene,layout,geometry,runtime)
	if FileAccess.get_sha256(binding.model.path).to_lower()!=str(binding.model.sha256).to_lower():
		scene.free(); return _result(["model.sha256: artifact changed during decode"])
	result.artifact_verified=true
	if retain_scene and result.ok: result["scene"]=scene
	else: scene.free()
	return result

static func self_contained_glb(bytes: PackedByteArray) -> Array[String]:
	if bytes.size()<20 or bytes.decode_u32(0)!=0x46546c67 or bytes.decode_u32(4)!=2 or bytes.decode_u32(8)!=bytes.size():
		return ["model: invalid GLB container"]
	var length := int(bytes.decode_u32(12))
	if bytes.decode_u32(16)!=0x4e4f534a or length>bytes.size()-20: return ["model: missing GLB JSON chunk"]
	var manifest: Variant=JSON.parse_string(bytes.slice(20,20+length).get_string_from_utf8())
	if not manifest is Dictionary: return ["model: invalid GLB JSON"]
	for category in ["buffers","images"]:
		var rows: Variant=manifest.get(category,[])
		if not rows is Array: return ["model: invalid GLB resource table"]
		for row in rows:
			if not row is Dictionary: return ["model: invalid GLB resource record"]
			if row.has("uri") and (not row.uri is String or not row.uri.begins_with("data:")):
				return ["model: external GLB dependencies are not packaged bindings"]
	return []

static func _runtime_mounts(binding: Dictionary, nodes: Dictionary, transforms: Dictionary, geometry: Dictionary, runtime: Dictionary, errors: Array[String]) -> void:
	var unit := float(binding.units.meters_per_unit)
	var tolerance := maxf(EPS,float(binding.units.attachment_tolerance_m))
	for spec in [["hull","turret",_vec(geometry.turret_origin)],["turret","gun",_vec(geometry.gun_origin)],
		["gun","muzzle",Vector3(0,0,-float(geometry.barrel_length))]]:
		var local: Transform3D=(transforms[nodes[spec[0]].get_instance_id()] as Transform3D).affine_inverse()*transforms[nodes[spec[1]].get_instance_id()]
		if (local.origin*unit).distance_to(spec[2])>tolerance or not local.basis.is_equal_approx(Basis.IDENTITY):
			errors.append("runtime_mount."+str(spec[1])+": model rest pose differs from combat geometry")
	for spec in [["turret",runtime.get("yaw_min",-180.0),runtime.get("yaw_max",180.0)],["gun",runtime.pitch_min,runtime.pitch_max]]:
		if not is_equal_approx(float(binding.axes[spec[0]].limits_deg[0]),float(spec[1])) or not is_equal_approx(float(binding.axes[spec[0]].limits_deg[1]),float(spec[2])):
			errors.append("runtime_mount."+str(spec[0])+": model limits differ from mechanism")
	# All source meshes must belong to the explicit articulated hull subtree.
	for instance_id in transforms:
		var node := instance_from_id(instance_id) as Node3D
		if node is MeshInstance3D and node!=nodes.hull and not nodes.hull.is_ancestor_of(node):
			errors.append("runtime_mount: mesh outside bound hull")
	var gun_forward := 0.0
	for role in ["hull","turret","gun","running_left","running_right"]:
		var mesh_count := 0
		for instance_id in transforms:
			var mesh := instance_from_id(instance_id) as MeshInstance3D
			if mesh==null or mesh.mesh==null or (mesh!=nodes[role] and not nodes[role].is_ancestor_of(mesh)): continue
			var separate := false
			for other in ["turret","gun","running_left","running_right"]:
				if other!=role and nodes[role].is_ancestor_of(nodes[other]) and (mesh==nodes[other] or nodes[other].is_ancestor_of(mesh)): separate=true
			if separate: continue
			mesh_count+=1
			if role=="gun":
				var relative: Transform3D=(transforms[nodes.gun.get_instance_id()] as Transform3D).affine_inverse()*transforms[instance_id]
				var bounds: AABB=relative*mesh.mesh.get_aabb()
				gun_forward=maxf(gun_forward,-bounds.position.z*unit)
		if mesh_count==0: errors.append("runtime_mount."+role+": articulated part has no own visible mesh")
	if absf(gun_forward-float(geometry.barrel_length))>maxf(0.1,tolerance):
		errors.append("runtime_mount.gun: visible gun envelope does not reach declared muzzle")

static func _walk(node: Node, parent_transform: Transform3D, transforms: Dictionary, stats: Dictionary, errors: Array[String]) -> void:
	var transform := parent_transform
	if node is Node3D:
		if not LayoutMath.is_rigid(node.transform): errors.append("transform: nonfinite/scaled/sheared/reflected node "+str(node.name))
		if node.top_level: errors.append("transform: top_level node escapes declared hierarchy "+str(node.name))
		transform=parent_transform*node.transform
		transforms[node.get_instance_id()]=transform
	if node is MeshInstance3D and node.mesh!=null:
		var box: AABB=transform*node.mesh.get_aabb()
		if not box.position.is_finite() or not box.size.is_finite() or box.size.length_squared()<=0:
			errors.append("model: invalid mesh envelope "+str(node.name))
		else:
			stats.bounds=box if stats.meshes==0 else stats.bounds.merge(box)
			stats.meshes+=1
	for child in node.get_children(): _walk(child,transform,transforms,stats,errors)

static func _axes_and_muzzle(binding: Dictionary, nodes: Dictionary, transforms: Dictionary, errors: Array[String]) -> void:
	var hull: Transform3D=transforms[nodes.hull.get_instance_id()]
	var turret: Transform3D=transforms[nodes.turret.get_instance_id()]
	var gun: Transform3D=transforms[nodes.gun.get_instance_id()]
	var muzzle: Transform3D=transforms[nodes.muzzle.get_instance_id()]
	if (hull.basis.inverse()*turret.basis*_vec(binding.axes.turret.axis)).distance_to(Vector3.UP)>EPS:
		errors.append("axes.turret: actual pivot orientation disagrees with hull up")
	if (turret.basis.inverse()*gun.basis*_vec(binding.axes.gun.axis)).distance_to(Vector3.RIGHT)>EPS:
		errors.append("axes.gun: actual pivot orientation disagrees with turret elevation axis")
	var muzzle_local := gun.affine_inverse()*muzzle
	if (-muzzle_local.basis.z).distance_to(Vector3.FORWARD)>EPS or muzzle_local.origin.dot(Vector3.FORWARD)<=0:
		errors.append("nodes.muzzle: must point along gun -Z and lie ahead of its pivot")
	var hull_inverse := hull.affine_inverse()
	var left: Transform3D=transforms[nodes.running_left.get_instance_id()]
	var right: Transform3D=transforms[nodes.running_right.get_instance_id()]
	if (hull_inverse*left.origin).x>=0 or (hull_inverse*right.origin).x<=0:
		errors.append("hierarchy.running: declared left/right anchors disagree with hull X sides")

static func _validate_layout(binding: Dictionary, expected_id: String, root: Node3D, nodes: Dictionary, transforms: Dictionary, layout: VehicleLayoutDefinition, errors: Array[String]) -> void:
	if layout==null:
		errors.append("layout: matching combat geometry is missing")
		return
	if layout.historical_identity_id!=expected_id: errors.append("layout: exact vehicle identity differs")
	if layout.modules.is_empty() or layout.crew_stations.is_empty() or layout.armor_patches.is_empty(): errors.append("layout: armor/modules/crew geometry required")
	var ids := {}
	for kind in ["modules","crew"]:
		var rows: Array=layout.modules if kind=="modules" else layout.crew_stations
		var attachments: Dictionary=binding.internal_attachments[kind]
		var expected := {}
		for row in rows:
			if row==null or row.id.is_empty(): errors.append("layout: null/empty internal item"); continue
			expected[row.id]=true
			if ids.has(row.id): errors.append("layout: duplicate internal ID "+row.id)
			ids[row.id]=true
			var path: Variant=attachments.get(row.id)
			if not _path(path): errors.append("internal_attachments."+kind+"."+row.id+": explicit path missing"); continue
			var anchor := root.get_node_or_null(NodePath(path)) as Node3D
			if anchor==null: errors.append("internal_attachments."+row.id+": missing Node3D"); continue
			var role: String=PART_ROLES.get(row.part_id,"")
			if role.is_empty() or not nodes.has(role): errors.append("internal_attachments."+row.id+": unbound layout part"); continue
			if anchor!=nodes[role] and not nodes[role].is_ancestor_of(anchor): errors.append("internal_attachments."+row.id+": wrong moving parent")
			var part_transform: Transform3D=transforms[nodes[role].get_instance_id()]
			# Runtime running frames share the drive origin at rest. Their authored
			# branch anchors may sit at the left/right wheel centers instead.
			if row.part_id in ["drive","running_left","running_right"]:
				part_transform=transforms[nodes.hull.get_instance_id()]
			var anchor_transform: Transform3D=transforms[anchor.get_instance_id()]
			if LayoutMath.is_rigid(part_transform) and LayoutMath.is_rigid(anchor_transform) and LayoutMath.is_rigid(row.local_box_transform):
				var local := part_transform.affine_inverse()*anchor_transform
				if (local.origin*float(binding.units.meters_per_unit)).distance_to(row.local_box_transform.origin)>maxf(EPS,float(binding.units.attachment_tolerance_m)) or not local.basis.is_equal_approx(row.local_box_transform.basis):
					errors.append("internal_attachments."+row.id+": actual anchor differs from layout local transform")
			else: errors.append("internal_attachments."+row.id+": nonrigid attachment/layout transform")
			# A hull attachment must not silently follow a turret or a running-gear branch.
			for other in ["turret","gun","running_left","running_right"]:
				if other==role or not nodes.has(other): continue
				if nodes[role].is_ancestor_of(nodes[other]) and (anchor==nodes[other] or nodes[other].is_ancestor_of(anchor)):
					errors.append("internal_attachments."+row.id+": follows a different articulated part")
		for id in attachments:
			if not expected.has(id): errors.append("internal_attachments."+kind+": unknown layout ID "+str(id))
