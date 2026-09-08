class_name VillageWorld
extends RefCounted
static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat

static func ground(parent: Node3D) -> StaticBody3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-160,160,4):
		for x in range(-160,160,4):
			var points: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(4,0),Vector2(4,4),Vector2(0,4)]:
				points.append(Vector3(x+offset.x,VillageDefinition.height(x+offset.x,z+offset.y),z+offset.y))
			var patch := (sin(float(x)/29.0)*cos(float(z)/37.0)+1.0)*0.5
			var color := Color("64724f").lerp(Color("6b7754"),patch)
			for index in [0,1,2,0,2,3]:
				surface.set_color(color)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var mesh := surface.commit()
	var mat := material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,mat)
	var body := StaticBody3D.new()
	body.name = "VillageTerrain"
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	WorldCollisionRules.tag(body,"terrain")
	parent.add_child(body)
	return body

static func build(parent: Node3D, map: MapDefinition, graybox: bool = false) -> StaticBody3D:
	var terrain := ground(parent)
	for item in map.obstacles:
		var color: Color = {"building":Color("c1ae86"),"stone_wall":Color("848877"),"solid_fence":Color("69543d"),"boundary":Color("666c59")}[item.kind]
		var body := TerrainFixtures.box(parent,item.position,item.size,color if not graybox else Color("888888"))
		body.name = item.id
		WorldCollisionRules.tag(body,item.kind)
		if not graybox and item.kind == "building": house_details(body,item.size)
		if not graybox and item.kind == "solid_fence":
			for z in range(-5,6,2): CoreVehicleVisual.box(body,Vector3(0.51,0,z),Vector3(0.02,2.1,0.07),Color("423e31"))
	roads(parent,map)
	for p in map.supply_reservations:
		var marker := CoreVehicleVisual.box(parent,p+Vector3.UP*0.035,Vector3(14,0.03,8),Color("85896a"))
		WorldCollisionRules.tag(marker,"supply_reservation")
		var label := Label3D.new()
		label.font = CoreUI.FONT
		label.text = "弹药补给 · 驻车每2秒1发"
		label.font_size = 40
		label.position = p+Vector3(0,2,0)
		parent.add_child(label)
	if not graybox: grass(parent,map)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	parent.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("afc4c4")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("dce3dc")
	world.environment.ambient_light_energy = 0.4
	parent.add_child(world)
	return terrain

static func house_details(body: StaticBody3D, size: Vector3) -> void:
	# Closed gable prism: shell collision uses the very same triangles as the visible roof.
	var w := size.x/2
	var d := size.z/2
	var y := size.y/2
	var ridge := y+size.x*0.23
	var points := PackedVector3Array([Vector3(-w,y,-d),Vector3(w,y,-d),Vector3(0,ridge,-d),Vector3(-w,y,d),Vector3(w,y,d),Vector3(0,ridge,d)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,2,1],[3,4,5],[0,3,5],[0,5,2],[1,2,5],[1,5,4],[0,1,4],[0,4,3]]:
		for i in face: st.add_vertex(points[i])
	st.generate_normals()
	var mesh := st.commit()
	var roof_mat := material(Color("845c45"))
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,roof_mat)
	var roof := MeshInstance3D.new()
	roof.mesh = mesh
	body.add_child(roof)
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	shape.shape = convex
	body.add_child(shape)
	for side in [-1,1]:
		for x in [-size.x*0.3,size.x*0.3]:
			CoreVehicleVisual.box(body,Vector3(x,0.3,side*(d+0.012)),Vector3(1.2,1.6,0.02),Color("394540"))
		CoreVehicleVisual.box(body,Vector3(0,-y+1.1,side*(d+0.014)),Vector3(1.4,2.2,0.025),Color("635c46"))
	CoreVehicleVisual.box(body,Vector3(0,-y+0.3,0),Vector3(size.x+0.015,0.6,size.z+0.015),Color("8b8a75"))

static func roads(parent: Node3D, map: MapDefinition) -> void:
	var nav := DriveNavigator.new()
	nav.configure(map.graph)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in map.graph.edges:
		# Dense spawn/capture graph is drivable open ground, not overlapping painted strips.
		if not edge.get("road_visual",false): continue
		var a: Vector3 = nav.nodes[edge.a]
		var b: Vector3 = nav.nodes[edge.b]
		var side := (b-a).normalized().cross(Vector3.UP)*5.5
		var steps := maxi(1,ceili(a.distance_to(b)/3))
		for i in steps:
			var p := a.lerp(b,float(i)/steps)
			var q := a.lerp(b,float(i+1)/steps)
			var points := [p-side,p+side,q+side,q-side]
			for index in [0,1,2,0,2,3]:
				var v: Vector3 = points[index]
				v.y = VillageDefinition.height(v.x,v.z)+0.045
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := material(Color("a49b78"))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mesh.surface_set_material(0,mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldCollisionRules.tag(node,"road")
	parent.add_child(node)

static func grass(parent: Node3D, map: MapDefinition) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18018
	for i in 900:
		var x := rng.randf_range(-153,153)
		var z := rng.randf_range(-153,153)
		if absf(x)<80 and absf(z)<140: continue
		var p := Vector3(x,VillageDefinition.height(x,z)+0.015,z)
		st.add_vertex(p+Vector3(-0.2,0,0))
		st.add_vertex(p+Vector3(0,0.28,0))
		st.add_vertex(p+Vector3(0.2,0,0))
	st.generate_normals()
	var mesh := st.commit()
	var mat := material(Color("7a8450"))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,mat)
	var node := MeshInstance3D.new()
	node.name = "LowGrass_028m_NoCover"
	node.mesh = mesh
	WorldCollisionRules.tag(node,"low_grass")
	parent.add_child(node)
