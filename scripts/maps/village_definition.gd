class_name VillageDefinition
extends RefCounted
## Original, deterministic authored layout. All distances are game design metres.
static func height(x: float, z: float) -> float:
	var h := 0.0
	for side in [-1,1]:
		var r := Vector2(x-side*116,z).length()/46.0
		if r < 1: h += 6.8*pow(cos(r*PI/2),2)
	return h

static func create() -> MapDefinition:
	var map := MapDefinition.new()
	map.id = "hill_village_018"
	map.title = "丘陵村落"
	var nodes := {}
	var edges: Array = []
	for team in [1,2]:
		var sign := 1 if team == 1 else -1
		var poses: Array[Transform3D] = []
		for row in 2:
			for i in 4:
				var p := Vector3(TeamArena.SPAWN_X[i],0,sign*(116+14*row))
				poses.append(Transform3D(Basis.IDENTITY if team == 1 else Basis(Vector3.UP,PI),p+Vector3.UP*0.03))
				var key := "spawn%d_%d_%d"%[team,row,i]
				nodes[key] = p
				for side in ["w","e"]: edges.append({"a":key,"b":"hub%d_"%team+side,"width":12})
		map.spawns[team] = poses
		map.supply_reservations.append(Vector3(0,0,sign*143))
		var supply := "supply%d"%team
		nodes[supply] = map.supply_reservations[team-1]
		for i in [1,2]: edges.append({"a":supply,"b":"spawn%d_1_%d"%[team,i],"width":12})
		for side in [-1,1]:
			var suffix := "w" if side<0 else "e"
			var hub := "hub%d_"%team+suffix
			var middle := "middle%d_"%team+suffix
			var near := "near%d_"%team+suffix
			nodes[hub] = Vector3(side*72,0,sign*116)
			nodes[middle] = Vector3(side*72,0,sign*50)
			nodes[near] = Vector3(side*42,0,sign*20)
			edges.append({"a":hub,"b":middle,"width":12})
			edges.append({"a":middle,"b":near,"width":12})
			for index in 4: edges.append({"a":near,"b":"cap%d"%[(team-1)*4+index],"width":12})
		# Western hill road adds a long flank and joins beyond either front route.
		var flank := "flank%d"%team
		nodes[flank] = Vector3(-120,0,sign*65)
		edges.append({"a":"hub%d_w"%team,"b":flank,"width":12})
		edges.append({"a":flank,"b":"hill_w","width":12})
		edges.append({"a":flank,"b":"middle%d_w"%team,"width":12})
	nodes.hill_w = Vector3(-120,height(-120,0),0)
	for index in 8: nodes["cap%d"%index] = TeamArena.GOALS[index]
	for pair in [[0,1],[1,2],[2,3],[3,7],[7,6],[6,5],[5,4],[4,0],[1,5],[2,6]]: edges.append({"a":"cap%d"%pair[0],"b":"cap%d"%pair[1],"width":12})
	# Existing driver replans from nearby graph nodes. Short segments keep every road
	# position within its 16m attachment limit, including after reverse recovery.
	var split_edges: Array = []
	for edge_index in edges.size():
		var edge: Dictionary = edges[edge_index]
		var a: Vector3 = nodes[edge.a]
		var b: Vector3 = nodes[edge.b]
		var steps := maxi(1,ceili(a.distance_to(b)/22.0))
		var previous: String = edge.a
		for i in range(1,steps+1):
			var key: String = edge.b if i == steps else "road_%d_%d"%[edge_index,i]
			if i<steps:
				var p := a.lerp(b,float(i)/steps)
				p.y = height(p.x,p.z)
				nodes[key] = p
			split_edges.append({"a":previous,"b":key,"width":edge.width,"road_visual":not edge.a.begins_with("spawn") and not edge.b.begins_with("cap")})
			previous = key
	edges = split_edges
	var serialized: Array = []
	for key in nodes:
		var p: Vector3 = nodes[key]
		serialized.append({"id":str(key),"position":[p.x,p.y,p.z]})
	map.graph = {"schema_version":1,"map_id":map.id,"nodes":serialized,"edges":edges}
	for sign in [-1,1]:
		map.obstacles.append({"id":"spawn_screen_%d"%sign,"kind":"stone_wall","position":Vector3(0,3,sign*87),"size":Vector3(112,6,4)})
		for side in [-1,1]:
			map.obstacles.append({"id":"house_%d_%d"%[sign,side],"kind":"building","position":Vector3(side*29,3,sign*48),"size":Vector3(18,6,14)})
		map.obstacles.append({"id":"village_house_%d"%sign,"kind":"building","position":Vector3(sign*28,2.5,0),"size":Vector3(10,5,8)})
		map.obstacles.append({"id":"cover_%d"%sign,"kind":"stone_wall","position":Vector3(sign*53,0.7,-sign*12),"size":Vector3(12,1.4,1)})
		map.obstacles.append({"id":"fence_%d"%sign,"kind":"solid_fence","position":Vector3(sign*46,1.1,sign*61),"size":Vector3(1,2.2,12)})
	for x in [-160,160]: map.obstacles.append({"id":"boundary_x%d"%x,"kind":"boundary","position":Vector3(x,3,0),"size":Vector3(2,6,322)})
	for z in [-160,160]: map.obstacles.append({"id":"boundary_z%d"%z,"kind":"boundary","position":Vector3(0,3,z),"size":Vector3(320,6,2)})
	return map
