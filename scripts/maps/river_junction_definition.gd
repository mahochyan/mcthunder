class_name RiverJunctionDefinition
extends RefCounted
## Original design coordinates, metres. Survey data is not a admitted match configuration.
const ID := "river_junction"
const WORLD := Rect2(-1200,-1000,2400,2000)
const LANES := [-820.0,-520.0,0.0,520.0,820.0]
const LINKS := [-680.0,-480.0,-220.0,220.0,480.0,680.0]
const OBJECTIVES := {
	"A":{"title":"采石场","xz":Vector2(-520,120),"role":"台阶地形 / 反斜面"},
	"B":{"title":"中央货运站","xz":Vector2(0,-130),"role":"铁路枢纽 / 中距离争夺"},
	"C":{"title":"河畔镇","xz":Vector2(520,100),"role":"街区绕行 / 近距离交战"}}
const LANDMARKS := {
	"D":{"title":"西部机修厂","xz":Vector2(-520,-320),"role":"工业掩体 / 侧翼转场"},
	"E":{"title":"东部农庄","xz":Vector2(520,340),"role":"果园 / 镇外接应"},
	"F":{"title":"西南木材场","xz":Vector2(-820,350),"role":"16v16 外侧推进"},
	"G":{"title":"东北中继站","xz":Vector2(820,-350),"role":"16v16 外侧推进"}}

static func layout(team_size: int) -> Dictionary:
	assert(team_size in [10,16])
	return {"id":"river_junction_%dv%d"%[team_size,team_size],"team_size":team_size,
		"bounds":Rect2(-740,-600,1480,1200) if team_size==10 else Rect2(-1040,-800,2080,1600),
		"objectives":["A","B","C"],
		"capture_limit":3,
		"crossings":[-520.0,0.0,520.0] if team_size==10 else LANES.duplicate(),
		"deployment_z":480.0 if team_size==10 else 680.0,
		"status":"design_preview","combat_admitted":false}

static func river_z(x: float) -> float: return 32.0*sin(x/210.0)

static func capture_definitions() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in OBJECTIVES:
		rows.append({"id":id,"center":point(OBJECTIVES[id].xz),"radius":45.0})
	return rows

static func lane_x(lane: float,z: float) -> float:
	var street_alignment := 1.0
	if lane==520.0: street_alignment=1.0-smoothstep(10.0,50.0,z)*(1.0-smoothstep(200.0,250.0,z))
	return lane+28.0*sin(z/120.0)*smoothstep(70.0,150.0,absf(z))*clampf((760.0-absf(z))/100.0,0,1)*street_alignment

static func road_distance(x: float,z: float) -> float:
	var distance := INF
	if absf(z)<760:
		for lane in LANES: distance=minf(distance,absf(x-lane_x(lane,z)))
	if absf(x)<870:
		for link in LINKS: distance=minf(distance,absf(z-link))
	return distance

static func height(x: float,z: float) -> float:
	var hills := 10.0+9.0*sin(x/165.0)*sin(z/145.0)+4.0*sin(x/71.0+z/103.0)
	# Terrain, rather than foliage, screens deployment and interrupts long views.
	hills+=28.0*exp(-pow((absf(x)-1030.0)/130.0,2))
	hills+=20.0*exp(-pow((absf(z)-840.0)/100.0,2))
	# Include the road shoulder plus an 8 m terrain cell diagonal in the level platform.
	var flat := 1.0-smoothstep(30.0,65.0,road_distance(x,z))
	var town_rect := Vector2((x-522.0)/105.0,(z-125.0)/92.0).abs()
	flat=maxf(flat,1.0-smoothstep(1.0,1.5,maxf(town_rect.x,town_rect.y)))
	for p in [Vector2(520,100),Vector2(0,-130),Vector2(-520,-320),Vector2(520,340),Vector2(-820,350),Vector2(820,-350)]:
		flat=maxf(flat,1.0-smoothstep(75.0,150.0,Vector2(x,z).distance_to(p)))
	for deployment_z in [480.0,680.0]:
		var apron := Vector2(absf(x)-260.0,absf(z)-deployment_z-10.0).abs()
		flat=maxf(flat,1.0-smoothstep(1.0,1.6,maxf(apron.x/60.0,apron.y/40.0)))
	hills=lerpf(hills,8.0,flat)
	var river_distance := absf(z-river_z(x))
	return lerpf(-3.0,hills,smoothstep(14.0,49.0,river_distance))

static func point(p: Vector2, lift: float=0.0) -> Vector3:
	return Vector3(p.x,height(p.x,p.y)+lift,p.y)

static func driving_stops(team_size: int=16) -> Array[Dictionary]:
	var config := layout(team_size)
	var stops: Array[Dictionary]=[
		{"title":"南部部署场","xz":Vector2(-260,config.deployment_z)},
		{"title":"北部部署场","xz":Vector2(260,-config.deployment_z),"yaw":PI}]
	for lane in config.crossings:
		stops.append({"title":"跨河通路 %d m"%lane,"xz":Vector2(lane,90)})
	stops.append({"title":"A 采石场入口","xz":Vector2(lane_x(-520,210),210)})
	stops.append({"title":"B 货运站入口","xz":Vector2(lane_x(0,-310),-310),"yaw":PI})
	stops.append({"title":"C 河畔镇主街","xz":Vector2(520,185)})
	return stops

static func hard_cover() -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for depth in [480.0,680.0]:
		for sign_z in [-1.0,1.0]:
			for sector in [-260.0,260.0]:
				var prefix := "Deployment_%d_%d"%[sector,depth*sign_z]
				rows.append({"id":prefix+"_front","xz":Vector2(sector,sign_z*(depth-55)),"footprint":Vector2(152,16),"height":8.0})
				for side in [-1,1]: rows.append({"id":prefix+"_wing"+str(side),"xz":Vector2(sector+side*73,sign_z*(depth-36)),"footprint":Vector2(10,35),"height":8.0})
	for lane in [-520.0,0.0,520.0]:
		for side in [-1,1]:
			for z in [-110.0,105.0]: rows.append({"id":"BridgeCover_%d_%d_%d"%[lane,side,z],"xz":Vector2(lane_x(lane,z)+side*35,z),"footprint":Vector2(22,12),"height":3.2})
	for x in [-285.0,285.0]:
		for z in [-250.0,250.0]: rows.append({"id":"TransferCover_%d_%d"%[x,z],"xz":Vector2(x,z),"footprint":Vector2(32,12),"height":4.0})
	return rows

static func spawns(team_size: int, team: int) -> Array[Transform3D]:
	var out: Array[Transform3D]=[]
	var sign_z := 1.0 if team==1 else -1.0
	var base_z: float=layout(team_size).deployment_z
	# Two dispersed parking aprons, each with an east and west exit.
	for i in team_size:
		var sector := -1.0 if i<ceili(team_size/2.0) else 1.0
		var slot := i%ceili(team_size/2.0)
		var row := int(slot/4)
		var p := Vector2(sector*260.0+(float(slot%4)-1.5)*18.0+row*9.0,sign_z*(base_z-row*20.0))
		out.append(Transform3D(Basis.IDENTITY if team==1 else Basis(Vector3.UP,PI),point(p,0.15)))
	return out

static func supply_points(team_size: int) -> Array[Dictionary]:
	# WT-032-R1: the two older maps place a resupply reservation behind each deployment
	# and wire a supply node into their graph; the river map had none, so spawn->supply
	# reachability could not be verified. These two points sit on the rear deployment
	# channel ends that the navigation graph already builds and the geometry check
	# already verifies as supported.
	var depth: float=layout(team_size).deployment_z
	var out: Array[Dictionary]=[]
	for team in [1,2]:
		var sign_z := 1.0 if team==1 else -1.0
		out.append({"team":team,"id":"supply%d"%team,
			"title":("南部部署场后侧补给圈" if team==1 else "北部部署场后侧补给圈"),
			"xz":Vector2(370.0,sign_z*(depth+32.0))})
	return out

static func road_lines() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for lane in LANES:
		var line := PackedVector2Array()
		for z in range(-740,741,10): line.append(Vector2(lane_x(lane,z),z))
		result.append(line)
	for z in LINKS: result.append(PackedVector2Array([Vector2(-860,z),Vector2(860,z)]))
	return result

static func route_graph(team_size: int, blocked_crossing: float=INF) -> Dictionary:
	# Strategic junction graph. Local vehicle navigation is a separate future integration.
	var config := layout(team_size)
	var nodes := {}; var edges: Array=[]
	for lane in config.crossings:
		for z in [-config.deployment_z,-220.0,220.0,config.deployment_z]:
			var key := "%d_%d"%[lane,z]; nodes[key]=Vector2(lane,z)
	for a in nodes:
		for b in nodes:
			if a>=b: continue
			var p: Vector2=nodes[a]; var q: Vector2=nodes[b]
			if is_equal_approx(p.x,q.x):
				var rows: Array=[-config.deployment_z,-220.0,220.0,config.deployment_z]
				if absi(rows.find(p.y)-rows.find(q.y))!=1: continue
				if p.y*q.y<0 and p.x==blocked_crossing: continue
				edges.append([a,b])
			elif is_equal_approx(p.y,q.y) and absi(config.crossings.find(p.x)-config.crossings.find(q.x))==1: edges.append([a,b])
	return {"nodes":nodes,"edges":edges,"scope":"strategic_design_only"}
