class_name ModernModelMountAdapter
extends RefCounted
## Authored articulation adapter for exact, frozen base models. Does not admit a vehicle.
const SPECS := {
	"ussr_t_80b":{"root":"ussr_t_80b","gun_mesh":"MainGun","wheel_prefix":"Wheel_","running_mesh_count":14},
	"germ_leopard_2a4":{"root":"VehicleRoot","gun_mesh":"MainGunAndMuzzleBrake","wheel_prefix":"wheel_","running_mesh_count":14}
}

static func unique(root: Node, label: String) -> Node3D:
	var found: Array[Node]=root.find_children(label,"Node3D",true,false)
	if root.name==label: found.append(root)
	return found[0] as Node3D if found.size()==1 else null

static func add_frame(parent: Node3D, label: String, pose: Transform3D) -> Node3D:
	var node := Node3D.new(); node.name=label; node.transform=pose; parent.add_child(node); return node

static func vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

static func prepare(packet: Dictionary, source_row: Dictionary) -> Dictionary:
	var id := str(packet.get("id",""))
	if not SPECS.has(id) or source_row.get("id")!=id or not source_row.get("model") is Dictionary:
		return {"ok":false,"errors":["adapter: exact supported source identity required"]}
	var record: Dictionary=source_row.model
	if record.get("status")!="reviewed_static_model" or record.get("geometry_status")!="PASS" or record.get("visual_status")!="PASS":
		return {"ok":false,"errors":["adapter: reviewed static source required"]}
	var path := str(record.get("path",""))
	if path!="res://assets/research/models/"+id+".glb" or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=record.get("sha256"):
		return {"ok":false,"errors":["adapter: frozen source path/hash differs"]}
	var bytes := FileAccess.get_file_as_bytes(path)
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	if digest.finish().hex_encode()!=record.sha256: return {"ok":false,"errors":["adapter: source changed during read"]}
	var errors := ModelBindingValidator.self_contained_glb(bytes)
	if not errors.is_empty(): return {"ok":false,"errors":errors}
	var document := GLTFDocument.new(); var state := GLTFState.new()
	if document.append_from_buffer(bytes,"",state)!=OK: return {"ok":false,"errors":["adapter: decode failed"]}
	var scene := document.generate_scene(state) as Node3D
	if scene==null: return {"ok":false,"errors":["adapter: no model scene"]}
	var result := adapt_scene(packet,scene,SPECS[id])
	if not result.ok: scene.free(); return result
	result.source={"path":path,"sha256":record.sha256,"id":id}
	var adapted: Dictionary=result.packet
	adapted.sources["mount_art"]={"origin":"game_rule","source_vehicle_id":id,"applies_to_identity_ids":[id],"excluded_identity_ids":[],"sha256":record.sha256,"artifact":path,"read_state":"authored"}
	var recipe_path := "res://scripts/content/modern_model_mount_adapter.gd"
	adapted.sources["mount_recipe"]={"origin":"game_rule","source_vehicle_id":id,"applies_to_identity_ids":[id],"excluded_identity_ids":[],"sha256":FileAccess.get_sha256(recipe_path),"artifact":recipe_path,"read_state":"authored"}
	adapted.facts["geometry.exterior"].value=adapted.geometry.duplicate(true)
	adapted.facts["geometry.exterior"].source_refs.append_array(["mount_art","mount_recipe"])
	adapted.facts["geometry.exterior"].location="Original candidate envelope plus measured source TurretPivot/GunPivot and gun-tip mount positions"
	adapted.facts["geometry.exterior"].note+=" Mount transforms measured from exact frozen authored model; armor surface fit remains pending."
	return result

static func adapt_scene(original: Dictionary, scene: Node3D, spec: Dictionary) -> Dictionary:
	var errors: Array[String]=[]; var transforms := {}; var stats := {"meshes":0,"bounds":AABB()}
	ModelBindingValidator._walk(scene,Transform3D.IDENTITY,transforms,stats,errors)
	if not errors.is_empty(): return {"ok":false,"errors":errors}
	var hull := unique(scene,spec.root); var turret := unique(scene,"TurretPivot"); var gun := unique(scene,"GunPivot")
	if hull==null or turret==null or gun==null or not hull.is_ancestor_of(turret) or not turret.is_ancestor_of(gun):
		return {"ok":false,"errors":["adapter: source articulation hierarchy changed"]}
	var hull_pose: Transform3D=transforms[hull.get_instance_id()]
	var turret_pose: Transform3D=hull_pose.affine_inverse()*transforms[turret.get_instance_id()]
	var gun_pose: Transform3D=(transforms[turret.get_instance_id()] as Transform3D).affine_inverse()*transforms[gun.get_instance_id()]
	if not hull_pose.is_equal_approx(Transform3D.IDENTITY) or not turret_pose.basis.is_equal_approx(Basis.IDENTITY) or not gun_pose.basis.is_equal_approx(Basis.IDENTITY):
		return {"ok":false,"errors":["adapter: unsupported rest axes; explicit reauthoring required"]}
	var tube := unique(scene,spec.gun_mesh) as MeshInstance3D
	if tube==null or tube.mesh==null or not gun.is_ancestor_of(tube): return {"ok":false,"errors":["adapter: exact gun mesh missing"]}
	var tube_pose: Transform3D=(transforms[gun.get_instance_id()] as Transform3D).affine_inverse()*transforms[tube.get_instance_id()]
	var tube_bounds: AABB=tube_pose*tube.mesh.get_aabb()
	var muzzle_distance := -tube_bounds.position.z
	if muzzle_distance<=0: return {"ok":false,"errors":["adapter: gun does not extend along -Z"]}
	var tip_bounds := AABB(); var tips := 0
	for surface in tube.mesh.get_surface_count():
		for vertex in tube.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var point: Vector3=tube_pose*vertex
			if absf(point.z+muzzle_distance)<=0.002:
				tip_bounds=AABB(point,Vector3.ZERO) if tips==0 else tip_bounds.expand(point); tips+=1
	if tips<3 or Vector2(tip_bounds.get_center().x,tip_bounds.get_center().y).length()>0.03:
		return {"ok":false,"errors":["adapter: muzzle tip does not match the declared gun centerline"]}
	var groups := {}
	for side in ["l","r"]:
		var members: Array[Node3D]=[]
		for child in hull.get_children():
			if child is MeshInstance3D and (child.name=="track_"+side or str(child.name).begins_with(str(spec.wheel_prefix)+side+"_")): members.append(child)
		if members.size()!=int(spec.running_mesh_count): return {"ok":false,"errors":["adapter: running gear membership differs on "+side]}
		groups[side]=members
	var before := mesh_poses(scene)
	var roots := {"hull":hull,"turret":turret,"barrel":gun,"drive":hull}
	for side in ["l","r"]:
		var branch := "running_left" if side=="l" else "running_right"
		var anchor := Vector3(-1 if side=="l" else 1,0,0)
		var frame := add_frame(hull,"RunningLeft" if side=="l" else "RunningRight",Transform3D(Basis.IDENTITY,anchor)); roots[branch]=frame
		for mesh in groups[side]:
			var local: Transform3D=hull_pose.affine_inverse()*transforms[mesh.get_instance_id()]
			mesh.owner=null; mesh.reparent(frame,false); mesh.transform=frame.transform.affine_inverse()*local
	var muzzle := add_frame(gun,"Muzzle",Transform3D(Basis.IDENTITY,Vector3(0,0,-muzzle_distance)))
	var packet := original.duplicate(true)
	packet.geometry.turret_origin=vector(turret_pose.origin); packet.geometry.gun_origin=vector(gun_pose.origin); packet.geometry.barrel_length=muzzle_distance
	var layout := HistoricalVehicleGeometry.build(packet)
	var attachments := {"modules":{},"crew":{}}
	for kind in ["modules","crew"]:
		for item in (layout.modules if kind=="modules" else layout.crew_stations):
			var parent: Node3D=roots.get(item.part_id)
			if parent==null: return {"ok":false,"errors":["adapter: unknown internal moving part "+item.part_id]}
			var local: Transform3D=item.local_box_transform
			if item.part_id in ["running_left","running_right"]: local=parent.transform.affine_inverse()*local
			var attachment := add_frame(parent,"Attachment_"+item.id,local)
			attachments[kind][item.id]=str(scene.get_path_to(attachment))
	var paths := {}
	for role in ModelBindingValidator.ROLES: paths[role]=str(scene.get_path_to(muzzle if role=="muzzle" else roots["barrel" if role=="gun" else role]))
	var binding := {"schema_version":1,"vehicle_id":packet.id,"model":{"source_vehicle_id":packet.id,"path":"pending.glb","sha256":"0".repeat(64)},
		"units":{"source_unit":"m","meters_per_unit":1.0,"dimensions_m":vector((stats.bounds as AABB).size),"tolerance_fraction":0.001,"attachment_tolerance_m":0.001},
		"nodes":paths,"axes":{"turret":{"space":"local","axis":[0,1,0],"limits_deg":[packet.runtime.get("yaw_min",-180),packet.runtime.get("yaw_max",180)]},"gun":{"space":"local","axis":[1,0,0],"limits_deg":[packet.runtime.pitch_min,packet.runtime.pitch_max]}},"internal_attachments":attachments}
	var checked := ModelBindingValidator.check_scene(binding,packet.id,scene,layout,packet.geometry,packet.runtime)
	if not checked.ok: return checked
	var after := mesh_poses(scene)
	if before.size()!=after.size(): return {"ok":false,"errors":["adapter: mesh membership changed"]}
	for key in before:
		if not after.has(key) or not (before[key] as Transform3D).is_equal_approx(after[key]): return {"ok":false,"errors":["adapter: neutral visual pose changed"]}
	return {"ok":true,"errors":[],"scene":scene,"packet":packet,"binding":binding,"layout":layout,"measured":checked.measured,
		"source_meshes_preserved":before.size(),"muzzle_tip_vertices":tips,"combat_admitted":false}

static func mesh_poses(scene: Node3D) -> Dictionary:
	var transforms := {}; var stats := {"meshes":0,"bounds":AABB()}; var errors: Array[String]=[]
	ModelBindingValidator._walk(scene,Transform3D.IDENTITY,transforms,stats,errors)
	var result := {}
	for id in transforms:
		if instance_from_id(id) is MeshInstance3D: result[id]=transforms[id]
	return result
