class_name NavigationBakePipeline
extends RefCounted
## Validate authored roads against the same collision world used by actors and shells.
static func build(map: MapDefinition, space: PhysicsDirectSpaceState3D, ground_rid: RID) -> Dictionary:
	var validation := map.validate()
	if not validation.ok: return validation
	var nav := DriveNavigator.new()
	nav.configure(map.graph)
	var failures: Array = []
	var samples := 0
	var shape := BoxShape3D.new()
	shape.size = map.max_vehicle_size
	for edge in nav.edges:
		var a: Vector3 = nav.nodes[edge.a]
		var b: Vector3 = nav.nodes[edge.b]
		var steps := maxi(1,ceili(a.distance_to(b)/3.0))
		for i in range(steps+1):
			var p := a.lerp(b,float(i)/steps)
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*30,p-Vector3.UP*30,GameConfig.LAYER_WORLD)
			var floor_hit := space.intersect_ray(ray)
			samples += 1
			if floor_hit.is_empty() or floor_hit.rid != ground_rid or rad_to_deg(floor_hit.normal.angle_to(Vector3.UP)) > GameConfig.DRIVE_MAX_SLOPE_DEG:
				failures.append({"edge":edge.key,"position":p,"reason":"missing_or_steep_road"}); continue
			var basis := Basis.looking_at((b-a)*Vector3(1,0,1),Vector3.UP)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(basis,floor_hit.position+Vector3.UP*(shape.size.y/2+0.08))
			query.collision_mask = GameConfig.LAYER_WORLD
			query.exclude = [ground_rid]
			if not space.intersect_shape(query,1).is_empty(): failures.append({"edge":edge.key,"position":p,"reason":"vehicle_envelope_blocked"})
	return {"ok":failures.is_empty(),"samples":samples,"failures":failures,"graph":map.graph.duplicate(true)}
