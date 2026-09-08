class_name DriveNavigator
extends RefCounted
## Authored map route graph. Immutable numeric geometry, deterministic tie-breaking.
var nodes: Dictionary = {}
var edges: Array[Dictionary] = []
var map_id := ""
var valid := false
var request_count := 0

func load_graph(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return configure(value)

func configure(value: Variant) -> Dictionary:
	valid = false
	nodes.clear()
	edges.clear()
	if not value is Dictionary or value.get("schema_version",0) != 1: return {"ok":false,"reason":"schema"}
	if not value.get("nodes") is Array or not value.get("edges") is Array: return {"ok":false,"reason":"structure"}
	if value.nodes.is_empty() or value.nodes.size() > 256 or value.edges.size() > 1024: return {"ok":false,"reason":"capacity"}
	for row in value.nodes:
		if not row is Dictionary or not row.get("id") is String or str(row.id).is_empty() or nodes.has(row.id): return {"ok":false,"reason":"node_id"}
		if not row.get("position") is Array or row.position.size() != 3: return {"ok":false,"reason":"position"}
		for n in row.position:
			if not (n is float or n is int) or not is_finite(float(n)): return {"ok":false,"reason":"nonfinite"}
		nodes[row.id] = Vector3(row.position[0],row.position[1],row.position[2])
	var seen := {}
	for row in value.edges:
		if not row is Dictionary or not nodes.has(row.get("a")) or not nodes.has(row.get("b")) or row.a == row.b: return {"ok":false,"reason":"edge_reference"}
		if not (row.get("width") is float or row.get("width") is int) or not is_finite(float(row.width)) or row.width <= 0: return {"ok":false,"reason":"edge_width"}
		var key := edge_key(row.a,row.b)
		if seen.has(key): return {"ok":false,"reason":"duplicate_edge"}
		seen[key] = true
		edges.append({"a":row.a,"b":row.b,"width":float(row.width),"key":key})
	map_id = str(value.get("map_id",""))
	valid = true
	return {"ok":true}

static func edge_key(a: String,b: String) -> String:
	return a+":"+b if a < b else b+":"+a

func nearest(position: Vector3) -> String:
	var result := ""
	var best := INF
	var ids := nodes.keys()
	ids.sort()
	for id in ids:
		var d := position.distance_squared_to(nodes[id])
		if d < best: best = d; result = id
	return result

func request_path(from: Vector3, goal: Vector3, vehicle_width: float, blocked: Dictionary = {}) -> Dictionary:
	request_count += 1
	if not valid or not from.is_finite() or not goal.is_finite() or not is_finite(vehicle_width) or vehicle_width <= 0: return {"ok":false,"reason":"invalid_request"}
	var start := nearest(from)
	var finish := nearest(goal)
	if from.distance_to(nodes[start]) > 16 or goal.distance_to(nodes[finish]) > GameConfig.AI_GOAL_RADIUS_M: return {"ok":false,"reason":"outside_graph"}
	var open: Array[String] = [start]
	var cost := {start:0.0}
	var came := {}
	var closed := {}
	while not open.is_empty():
		open.sort_custom(func(a: String,b: String) -> bool:
			var fa: float = cost[a]+nodes[a].distance_to(nodes[finish])
			var fb: float = cost[b]+nodes[b].distance_to(nodes[finish])
			return a < b if is_equal_approx(fa,fb) else fa < fb)
		var current := open.pop_front() as String
		if current == finish:
			var ids: Array[String] = [current]
			while came.has(current): current = came[current]; ids.push_front(current)
			var points := PackedVector3Array()
			for id in ids: points.append(nodes[id])
			return {"ok":true,"points":points,"ids":ids,"cost":cost[finish]}
		closed[current] = true
		for edge in edges:
			if edge.width < vehicle_width+GameConfig.AI_NAV_MARGIN_M or blocked.has(edge.key): continue
			var next: String = edge.b if edge.a == current else (edge.a if edge.b == current else "")
			if next.is_empty() or closed.has(next): continue
			var proposed: float = cost[current]+nodes[current].distance_to(nodes[next])
			if proposed >= float(cost.get(next,INF)): continue
			cost[next] = proposed
			came[next] = current
			if not open.has(next): open.append(next)
	return {"ok":false,"reason":"unreachable_or_insufficient_width"}
