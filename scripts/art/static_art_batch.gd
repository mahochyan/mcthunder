class_name StaticArtBatch
extends RefCounted
## One flat-shaded, vertex-colored surface per static assembly, not one node per brick.
var _surface := SurfaceTool.new()
var triangle_count := 0

func _init() -> void: _surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func mesh(source: Mesh, pose: Transform3D, tint: Color) -> void:
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0,count,3):
			var points: Array[Vector3] = []
			for corner in 3:
				var i := triangle+corner
				points.append(pose*vertices[indices[i] if not indices.is_empty() else i])
			var normal := -(points[1]-points[0]).cross(points[2]-points[0]).normalized()
			for point in points:
				_surface.set_color(tint); _surface.set_normal(normal); _surface.add_vertex(point)
		triangle_count += count/3

func box(position: Vector3, size: Vector3, key: String, rotation: Vector3 = Vector3.ZERO) -> void:
	var primitive := BoxMesh.new(); primitive.size = size
	mesh(primitive,Transform3D(Basis.from_euler(rotation),position),ArtPalette.color(key))

func polygon(points: PackedVector3Array, triangles: PackedInt32Array, key: String) -> void:
	for triangle in range(0,triangles.size(),3):
		var a := points[triangles[triangle]]; var b := points[triangles[triangle+1]]; var c := points[triangles[triangle+2]]
		var normal := -(b-a).cross(c-a).normalized()
		for point in [a,b,c]:
			_surface.set_color(ArtPalette.color(key)); _surface.set_normal(normal); _surface.add_vertex(point)
	triangle_count += triangles.size()/3

func finish(parent: Node3D, title: String = "Cosmetic_StaticBatch", layer: int = 1) -> MeshInstance3D:
	var result := MeshInstance3D.new(); result.name = title; result.layers = layer
	result.mesh = _surface.commit()
	result.material_override = ArtPalette.material("plaster",true)
	result.set_meta("art_triangles",triangle_count)
	parent.add_child(result)
	return result
