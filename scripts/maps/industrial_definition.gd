class_name IndustrialDefinition
extends RefCounted
## Original 350x450m industrial yard, authored in metres. No historical location claim.
static func create() -> MapDefinition:
	var map := MapDefinition.new()
	map.id = "industrial_edge_023"
	map.title = "工业边缘"
	map.bounds = Rect2(-175,-225,350,450)
	var nodes := {}
	var edges: Array = []
	for team in [1,2]:
		var sign := 1 if team == 1 else -1
		var poses: Array[Transform3D] = []
		for row in 2:
			for i in 4:
				var key := "spawn%d_%d_%d"%[team,row,i]
				var p := Vector3(TeamArena.SPAWN_X[i],0,sign*(185+16*row))
				poses.append(Transform3D(Basis.IDENTITY if team == 1 else Basis(Vector3.UP,PI),p+Vector3.UP*0.03))
				nodes[key] = p
				edges.append({"a":key,"b":"hub%d_%s"%[team,"w" if i<2 else "e"],"width":14,"road_visual":false})
				if i>0: edges.append({"a":key,"b":"spawn%d_%d_%d"%[team,row,i-1],"width":14,"road_visual":false})
				if row>0: edges.append({"a":key,"b":"spawn%d_0_%d"%[team,i],"width":14,"road_visual":false})
		map.spawns[team] = poses
		map.supply_reservations.append(Vector3(0,0,sign*214))
		var supply := "supply%d"%team
		nodes[supply] = map.supply_reservations[team-1]
		for i in [1,2]: edges.append({"a":supply,"b":"spawn%d_1_%d"%[team,i],"width":14,"road_visual":false})
		for side in [-1,1]:
			var suffix := "%d_%s"%[team,"w" if side<0 else "e"]
			var points := {"hub":Vector3(side*78,0,sign*185),"junction":Vector3(side*78,0,sign*100),"street":Vector3(side*95,0,sign*100),"corner":Vector3(side*95,0,sign*25),"alley":Vector3(side*78,0,sign*25),"near":Vector3(side*42,0,sign*25),"outer":Vector3(side*160,0,sign*100)}
			for key in points: nodes[key+suffix] = points[key]
			for pair in [["hub","junction"],["junction","street"],["street","corner"],["corner","alley"],["alley","near"],["street","outer"],["junction","alley"]]:
				edges.append({"a":pair[0]+suffix,"b":pair[1]+suffix,"width":14,"road_visual":true})
			for i in 4: edges.append({"a":"near"+suffix,"b":"cap%d"%[(team-1)*4+i],"width":14,"road_visual":false})
			map.obstacles.append({"id":"warehouse_%d_%d"%[team,side],"kind":"building","position":Vector3(side*30,4,sign*65),"size":Vector3(60,8,50)})
			map.obstacles.append({"id":"outer_works_%d_%d"%[team,side],"kind":"building","position":Vector3(side*130,4.5,sign*55),"size":Vector3(36,9,60)})
		map.obstacles.append({"id":"spawn_warehouse_%d"%team,"kind":"building","position":Vector3(0,4.5,sign*140),"size":Vector3(112,9,36)})
	for side in ["w","e"]: edges.append({"a":"outer1_"+side,"b":"outer2_"+side,"width":14,"road_visual":true})
	for side in [-1,1]:
		# A central loading block interrupts straight street fire. Its two ends have alternate approaches.
		map.obstacles.append({"id":"loading_block_%d"%side,"kind":"building","position":Vector3(side*86,3,0),"size":Vector3(32,6,24)})
		map.obstacles.append({"id":"yard_cover_%d"%side,"kind":"stone_wall","position":Vector3(side*65,0.8,0),"size":Vector3(18,1.6,2)})
	for i in 8: nodes["cap%d"%i] = TeamArena.GOALS[i]
	for pair in [[0,1],[1,2],[2,3],[3,7],[7,6],[6,5],[5,4],[4,0],[1,5],[2,6]]: edges.append({"a":"cap%d"%pair[0],"b":"cap%d"%pair[1],"width":14,"road_visual":false})
	# Keep the existing driver's 16m graph attachment bound valid along every route.
	var split: Array = []
	for index in edges.size():
		var edge: Dictionary = edges[index]
		var a: Vector3 = nodes[edge.a]; var b: Vector3 = nodes[edge.b]
		var steps := maxi(1,ceili(a.distance_to(b)/20.0))
		var previous: String = edge.a
		for i in range(1,steps+1):
			var key: String = edge.b if i == steps else "road_%d_%d"%[index,i]
			if i<steps: nodes[key] = a.lerp(b,float(i)/steps)
			split.append({"a":previous,"b":key,"width":edge.width,"road_visual":edge.road_visual})
			previous = key
	var serialized: Array = []
	for key in nodes:
		var p: Vector3 = nodes[key]
		serialized.append({"id":str(key),"position":[p.x,p.y,p.z]})
	map.graph = {"schema_version":1,"map_id":map.id,"nodes":serialized,"edges":split}
	for x in [-175,175]: map.obstacles.append({"id":"boundary_x%d"%x,"kind":"boundary","position":Vector3(x,3,0),"size":Vector3(2,6,452)})
	for z in [-225,225]: map.obstacles.append({"id":"boundary_z%d"%z,"kind":"boundary","position":Vector3(0,3,z),"size":Vector3(350,6,2)})
	return map
