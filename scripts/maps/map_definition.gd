class_name MapDefinition
extends RefCounted
var id := ""
var title := ""
var bounds := Rect2(-160,-160,320,320)
var graph: Dictionary = {}
var spawns: Dictionary = {}
var obstacles: Array[Dictionary] = []
var supply_reservations: Array[Vector3] = []
var max_vehicle_size := Vector3(4.2,2.4,8.5)

func validate() -> Dictionary:
	var errors: Array[String] = []
	if id.is_empty() or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x <= 0 or bounds.size.y <= 0: errors.append("map_identity_or_bounds")
	if not max_vehicle_size.is_finite() or max_vehicle_size.x <= 0 or max_vehicle_size.y <= 0 or max_vehicle_size.z <= 0: errors.append("vehicle_envelope")
	var nav := DriveNavigator.new()
	var checked := nav.configure(graph)
	if not checked.ok: return {"ok":false,"errors":["graph: "+checked.reason]}
	for p: Vector3 in nav.nodes.values():
		if not bounds.has_point(Vector2(p.x,p.z)): errors.append("node_outside_bounds")
	for team in [1,2]:
		if not spawns.has(team) or spawns[team].size() < 8: errors.append("spawn_capacity"); continue
		for pose: Transform3D in spawns[team]:
			if not pose.is_finite() or not bounds.has_point(Vector2(pose.origin.x,pose.origin.z)): errors.append("spawn_outside_bounds"); continue
			var path := nav.request_path(pose.origin,TeamArena.goal(team,0),max_vehicle_size.x)
			if not path.ok: errors.append("spawn_unreachable"); continue
			# Each individual road may be blocked: all spawns still need another route.
			for i in range(1,path.ids.size()):
				var alternate := nav.request_path(pose.origin,TeamArena.goal(team,0),max_vehicle_size.x,{DriveNavigator.edge_key(path.ids[i-1],path.ids[i]):true})
				if not alternate.ok: errors.append("single_edge_trap")
	for obstacle in obstacles:
		if not WorldCollisionRules.classify(obstacle.kind).known: errors.append("unknown_collision_kind")
		if not obstacle.position.is_finite() or not obstacle.size.is_finite() or obstacle.size.x<=0 or obstacle.size.y<=0 or obstacle.size.z<=0: errors.append("obstacle_geometry")
	return {"ok":errors.is_empty(),"errors":errors}

func minimap() -> Dictionary:
	var rectangles: Array[Rect2] = []
	for obstacle in obstacles:
		var p: Vector3 = obstacle.position
		var s: Vector3 = obstacle.size
		rectangles.append(Rect2(p.x-s.x/2,p.z-s.z/2,s.x,s.z))
	return {"bounds":bounds,"obstacles":rectangles,"roads":graph.duplicate(true),"title":title}
