class_name TrackAssembly
extends RefCounted
## Running gear shares the drive frame, independently of the sprung hull.
const LEFT := "running_left"
const RIGHT := "running_right"

static func bind_layout(layout: VehicleLayoutDefinition) -> void:
	var drive := LayoutPartDefinition.new()
	drive.id = "drive"
	layout.parts.push_front(drive)
	for part in layout.parts:
		if part.id == "hull": part.parent_id = "drive"
	for id in [LEFT, RIGHT]:
		var part := LayoutPartDefinition.new()
		part.id = id
		part.parent_id = "drive"
		layout.parts.append(part)
	for module in layout.modules:
		if module.id == "track_left": module.part_id = LEFT
		if module.id == "track_right": module.part_id = RIGHT

static func install(actor: VehicleActor, layout: VehicleLayoutDefinition) -> void:
	var tank := actor.tank
	for module in layout.modules:
		if module.part_id not in [LEFT, RIGHT]: continue
		var center := module.local_box_transform.origin
		var bottom := center.y - module.size_m.y * 0.5
		var extent := module.size_m.z * 0.4
		tank.track_probe_offsets[module.part_id] = [Vector3(center.x,bottom,center.z-extent),Vector3(center.x,bottom,center.z+extent)]
	for suffix in ["left", "right"]:
		var detail := tank.hull_frame.get_node_or_null("Cosmetic_track_" + suffix) as Node3D
		if detail != null: detail.reparent(tank.track_left_frame if suffix == "left" else tank.track_right_frame)
	# Existing authored meshes batch both sides. Split their triangle indices once at
	# assembly, retaining vertex attributes, material and original local transforms.
	for name in ["Cosmetic_wheels", "Cosmetic_suspension"]:
		var detail := tank.hull_frame.get_node_or_null(name) as MeshInstance3D
		if detail == null: continue
		for side in [-1, 1]:
			var mesh := ArrayMesh.new()
			for surface in detail.mesh.get_surface_count():
				var arrays := detail.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in vertices.size(): indices.append(i)
				var selected := PackedInt32Array()
				for i in range(0, indices.size(), 3):
					var center := detail.transform * ((vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3.0)
					if (center.x < 0) == (side < 0): selected.append_array(indices.slice(i,i+3))
				if selected.is_empty(): continue
				arrays[Mesh.ARRAY_INDEX] = selected
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.surface_set_material(mesh.get_surface_count()-1,detail.mesh.surface_get_material(surface))
			if mesh.get_surface_count() == 0: continue
			var split := detail.duplicate() as MeshInstance3D
			split.mesh = mesh
			split.name = name + ("_left" if side < 0 else "_right")
			(tank.track_left_frame if side < 0 else tank.track_right_frame).add_child(split)
		detail.get_parent().remove_child(detail)
		detail.free()
