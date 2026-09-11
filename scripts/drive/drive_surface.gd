class_name DriveSurface
extends RefCounted
## Surface identity belongs to physical ground, independent of visual quality.
static func configure(body: Node3D, kind: String, map: MapDefinition=null, half_width: float=0) -> void:
	var strips: Array=[]
	if map!=null:
		var nav := DriveNavigator.new(); nav.configure(map.graph)
		for edge in map.graph.edges:
			if not edge.get("road_visual",false): continue
			var a: Vector3=body.to_local(body.get_parent().to_global(nav.nodes[edge.a]))
			var b: Vector3=body.to_local(body.get_parent().to_global(nav.nodes[edge.b]))
			var width := half_width*(b-a).normalized().cross(Vector3.UP).length()
			strips.append([Vector2(a.x,a.z),Vector2(b.x,b.z),width])
	body.set_meta("drive_surface",{"kind":kind,"strips":strips})

static func kind_at(body: Object, world_point: Vector3) -> String:
	if not body is Node3D or not body.has_meta("drive_surface"): return "unclassified"
	var data: Dictionary=body.get_meta("drive_surface")
	var point: Vector3=body.to_local(world_point)
	var flat := Vector2(point.x,point.z)
	for strip in data.strips:
		var a: Vector2=strip[0]; var edge: Vector2=strip[1]-a
		if edge.length_squared()<0.00001: continue
		var t := (flat-a).dot(edge)/edge.length_squared()
		if t>=0 and t<=1 and flat.distance_to(a+edge*t)<=float(strip[2]): return "road"
	return str(data.kind)

static func drag_at(body: Object, world_point: Vector3) -> float:
	return float(GameConfig.DRIVE_SURFACE_DRAG.get(kind_at(body,world_point),0.0))
