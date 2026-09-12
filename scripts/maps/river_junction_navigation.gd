class_name RiverJunctionNavigation
extends RefCounted
## Road-centre graph with explicit intersections, bridge decks and two rear deployment exits.
var nodes: Dictionary = {}
var edges: Dictionary = {}
var goals: Dictionary = {}
var graph: Dictionary = {}

func node(p: Vector2, road: bool=true) -> String:
	var id := "%.3f_%.3f"%[p.x,p.y]
	if not nodes.has(id): nodes[id]=Vector3(p.x,8.0 if road else RiverJunctionDefinition.height(p.x,p.y),p.y)
	return id

func add_edge(a: String,b: String,width: float=12.0) -> void:
	if a==b: return
	edges[DriveNavigator.edge_key(a,b)]={"a":a,"b":b,"width":width}

func line(a: Vector2,b: Vector2,road: bool=true,width: float=12.0) -> void:
	var segments := maxi(1,ceili(a.distance_to(b)/24.0))
	var previous := node(a,road)
	for i in range(1,segments+1):
		var current := node(a.lerp(b,float(i)/segments),road)
		add_edge(previous,current,width); previous=current

func build(team_size: int) -> Dictionary:
	nodes.clear(); edges.clear(); goals.clear()
	var config := RiverJunctionDefinition.layout(team_size)
	var depth: float=config.deployment_z
	var lane_rows: Array[float]=[-depth,depth,-220,220,-130,100,120]
	for z in RiverJunctionDefinition.LINKS:
		if absf(z)<=depth and not lane_rows.has(z): lane_rows.append(z)
	lane_rows.sort()
	for lane in config.crossings:
		for i in range(1,lane_rows.size()):
			var start: float=lane_rows[i-1]; var finish: float=lane_rows[i]
			var pieces := maxi(1,ceili((finish-start)/24))
			var previous := node(Vector2(RiverJunctionDefinition.lane_x(lane,start),start))
			for j in range(1,pieces+1):
				var z := lerpf(start,finish,float(j)/pieces)
				var current := node(Vector2(RiverJunctionDefinition.lane_x(lane,z),z))
				add_edge(previous,current); previous=current
	for z in RiverJunctionDefinition.LINKS:
		if absf(z)>depth: continue
		var columns: Array[float]=[]
		for lane in config.crossings: columns.append(RiverJunctionDefinition.lane_x(lane,z))
		if absf(z)==depth:
			for x in [-370.0,-150.0,150.0,370.0]: columns.append(x)
		columns.sort()
		for i in range(1,columns.size()): line(Vector2(columns[i-1],z),Vector2(columns[i],z))
	for team in [1,2]:
		var sign_z := 1.0 if team==1 else -1.0
		for sector in [-260.0,260.0]:
			var aisle_z := sign_z*(depth+32)
			var columns: Array[float]=[sector-110,sector+110]
			for pose in RiverJunctionDefinition.spawns(team_size,team):
				if signf(pose.origin.x)!=signf(sector): continue
				var p := Vector2(pose.origin.x,pose.origin.z)
				columns.append(p.x)
				line(p,Vector2(p.x,aisle_z),false,8)
			columns.sort()
			for i in range(1,columns.size()): line(Vector2(columns[i-1],aisle_z),Vector2(columns[i],aisle_z),false,8)
			for x in [sector-110,sector+110]: line(Vector2(x,aisle_z),Vector2(x,sign_z*depth),false,8)
	for id in RiverJunctionDefinition.OBJECTIVES:
		var p: Vector2=RiverJunctionDefinition.OBJECTIVES[id].xz
		goals[id]=nodes[node(Vector2(RiverJunctionDefinition.lane_x(p.x,p.y),p.y))]
	var serialized: Array=[]
	for id in nodes:
		var p: Vector3=nodes[id]; serialized.append({"id":id,"position":[p.x,p.y,p.z]})
	graph={"schema_version":1,"map_id":config.id,"through_waypoints":true,"nodes":serialized,"edges":edges.values()}
	return graph.duplicate(true)
