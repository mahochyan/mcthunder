class_name GeometryOverlay
extends RefCounted
## Independent triangle comparison and optional debug wire layer. It never edits layout data.
static func compare(actor: VehicleActor) -> Dictionary:
	var errors: Array[String]=[]
	var snapshot:=QuerySnapshotBuilder.build_from_vehicle(actor.tank,actor.damage_layout_override)
	var checked:=0
	for part in ["hull","turret","barrel"]:
		var parent:=DamageTrainingLayout.part_node(actor,part)
		var skin:=parent.get_node_or_null("Skin_"+part) as MeshInstance3D
		if skin==null: errors.append("missing_skin_"+part); continue
		var expected: Array[String]=[]; var actual: Array[String]=[]
		for patch in actor.damage_layout_override.armor_patches:
			if patch.part_id!=part: continue
			for i in range(0,patch.triangles.size(),3):
				var points: Array[Vector3]=[]
				for j in 3: points.append(snapshot.part_world_transforms[part]*patch.vertices_local_m[patch.triangles[i+j]])
				expected.append(_face_key(points))
		var arrays:=skin.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var count:=indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0,count,3):
			var points: Array[Vector3]=[]
			for j in 3: points.append(skin.global_transform*vertices[indices[i+j] if not indices.is_empty() else i+j])
			actual.append(_face_key(points))
			var n:=-(points[1]-points[0]).cross(points[2]-points[0]).normalized()
			for j in 3:
				var index:=indices[i+j] if not indices.is_empty() else i+j
				if n.dot(skin.global_basis*normals[index])<0.999: errors.append("normal_"+part)
		expected.sort(); actual.sort(); checked+=actual.size()
		if expected!=actual: errors.append("triangles_or_pose_"+part)
	return {"ok":errors.is_empty(),"errors":errors,"triangles":checked}

static func _face_key(points: Array[Vector3]) -> String:
	var rows: Array[String]=[]
	for point in points: rows.append("%d,%d,%d"%[roundi(point.x*100000),roundi(point.y*100000),roundi(point.z*100000)])
	rows.sort(); return "|".join(rows)

static func attach(actor: VehicleActor) -> void:
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("7edfea"); material.no_depth_test=true
	for patch in actor.damage_layout_override.armor_patches:
		var line:=MeshInstance3D.new(); line.name="DebugArmor_"+patch.id
		line.mesh=ArmorPatchMesh.build_wire(patch.vertices_local_m,patch.triangles,patch.outward_normal_local)
		line.material_override=material; line.layers=actor.tank.visual_layer; line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		DamageTrainingLayout.part_node(actor,patch.part_id).add_child(line)
