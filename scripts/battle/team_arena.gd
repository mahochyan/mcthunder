class_name TeamArena
extends RefCounted
const SPAWN_X := [-27,-9,9,27]
const GOALS := [Vector3(-8,0,6),Vector3(-3,0,9),Vector3(3,0,9),Vector3(8,0,6),Vector3(-8,0,-6),Vector3(-3,0,-9),Vector3(3,0,-9),Vector3(8,0,-6)]

static func goal(team: int, index: int) -> Vector3: return GOALS[(team-1)*4+index]

static func candidates(team: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var basis := Basis.IDENTITY if team == 1 else Basis(Vector3.UP,PI)
	for depth in [48,58]:
		for x in SPAWN_X: out.append(Transform3D(basis,Vector3(x,0.03,depth if team == 1 else -depth)))
	return out

static func graph() -> Dictionary:
	var nodes: Dictionary = {}
	var edges: Array = []
	for team in [1,2]:
		var sign := 1 if team == 1 else -1
		for row in 2:
			for index in 4:
				var id := "spawn%d_%d_%d"%[team,row,index]
				nodes[id] = Vector3(SPAWN_X[index],0,(48+row*10)*sign)
				edges.append({"a":id,"b":"hub%d_%s"%[team,"w" if index<2 else "e"],"width":7})
		for side in [-1,1]:
			var suffix := "w" if side<0 else "e"
			nodes["hub%d_%s"%[team,suffix]] = Vector3(side*26,0,sign*36)
			nodes["near%d_%s"%[team,suffix]] = Vector3(side*26,0,sign*8)
			edges.append({"a":"hub%d_%s"%[team,suffix],"b":"near%d_%s"%[team,suffix],"width":7})
			for slot in ([0,1] if side<0 else [2,3]):
				edges.append({"a":"near%d_%s"%[team,suffix],"b":"cap%d"%[(team-1)*4+slot],"width":7})
	for index in GOALS.size(): nodes["cap%d"%index] = GOALS[index]
	for pair in [[0,1],[1,2],[2,3],[3,7],[7,6],[6,5],[5,4],[4,0],[1,5],[2,6]]: edges.append({"a":"cap%d"%pair[0],"b":"cap%d"%pair[1],"width":7})
	var serialized: Array = []
	for id in nodes:
		var p: Vector3 = nodes[id]
		serialized.append({"id":id,"position":[p.x,p.y,p.z]})
	return {"schema_version":1,"map_id":"team_graybox_016","nodes":serialized,"edges":edges}

static func build(parent: Node3D) -> void:
	TerrainFixtures.box(parent,Vector3(0,-0.5,0),Vector3(100,1,140),Color("596c50"))
	for z in [-34,34]: TerrainFixtures.box(parent,Vector3(0,2,z),Vector3(20,4,4),Color("83785b"))
	for p in [Vector3(-12,1.5,15),Vector3(12,1.5,-15)]: TerrainFixtures.box(parent,p,Vector3(8,3,6),Color("84765a"))
	for x in [-50,50]: TerrainFixtures.box(parent,Vector3(x,2,0),Vector3(1,4,140))
	for z in [-70,70]: TerrainFixtures.box(parent,Vector3(0,2,z),Vector3(100,4,1))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	sun.shadow_enabled = true
	parent.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("91a6a3")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("bfc8b3")
	world.environment.ambient_light_energy = 0.7
	parent.add_child(world)
