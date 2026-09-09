class_name VehicleAtlas
extends RefCounted
## UVs are authored against the same validated armor vertices used by shot queries.
const TEXTURE_PATH := "res://assets/vehicles/textures/vehicle_concept_atlas_v1.png"
static var _material: StandardMaterial3D
static var _manifests: Dictionary = {}

static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = load(TEXTURE_PATH)
		_material.roughness = 0.9
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material

static func manifest(id: String) -> Dictionary:
	if not _manifests.has(id):
		_manifests[id] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/"+id+".manifest.json"))
	return _manifests[id]

static func skin(actor: VehicleActor, part: String, layout: VehicleLayoutDefinition, id: String) -> MeshInstance3D:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ids: Array[String] = []
	var atlas: Dictionary = manifest(id).get("armor_uv",{})
	for patch in layout.armor_patches:
		if patch.part_id != part: continue
		ids.append(patch.id)
		var uvs: Array = atlas.get(patch.id,[])
		for i in range(0,patch.triangles.size(),3):
			var a := patch.vertices_local_m[patch.triangles[i]]
			var b := patch.vertices_local_m[patch.triangles[i+1]]
			var c := patch.vertices_local_m[patch.triangles[i+2]]
			var normal := -(b-a).cross(c-a).normalized()
			for j in 3:
				var index := patch.triangles[i+j]
				var uv := Vector2(0.125,0.875)
				if index < uvs.size(): uv=Vector2(float(uvs[index][0]),1.0-float(uvs[index][1]))
				surface.set_normal(normal); surface.set_uv(uv); surface.add_vertex(patch.vertices_local_m[index])
	var mesh := MeshInstance3D.new(); mesh.name="Skin_"+part
	mesh.mesh=surface.commit(); mesh.material_override=material(); mesh.layers=actor.tank.visual_layer
	mesh.set_meta("gameplay_patch_ids",ids)
	DamageTrainingLayout.part_node(actor,part).add_child(mesh)
	return mesh
