class_name TerrainFixtures
extends RefCounted
static func box(parent: Node3D, position: Vector3, size: Vector3, color: Color = Color("56644f")) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = position
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	CoreVehicleVisual.box(body,Vector3.ZERO,size,color)
	parent.add_child(body)
	return body

static func ramp(parent: Node3D, position: Vector3, angle_deg: float, width: float = 8, length: float = 15) -> StaticBody3D:
	var height := tan(deg_to_rad(angle_deg))*length
	var w := width/2
	var points := PackedVector3Array([Vector3(-w,0,0),Vector3(w,0,0),Vector3(w,height,-length),Vector3(-w,height,-length),Vector3(-w,-0.5,0),Vector3(w,-0.5,0),Vector3(w,-0.5,-length),Vector3(-w,-0.5,-length)])
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[3,2,6,7],[0,3,7,4],[1,5,6,2]]:
		var normal := (points[face[1]]-points[face[0]]).cross(points[face[2]]-points[face[0]]).normalized()
		for index in [0,1,2,0,2,3]:
			mesh.surface_set_normal(normal)
			mesh.surface_add_vertex(points[face[index]])
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a794b") if angle_deg <= GameConfig.DRIVE_MAX_SLOPE_DEG else Color("975b48")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = mat
	body.add_child(visual)
	parent.add_child(body)
	return body
