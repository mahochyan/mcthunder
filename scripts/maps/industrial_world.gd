class_name IndustrialWorld
extends RefCounted
## All solid geometry is a box whose visible mesh and physics size agree exactly.
## Painted doors, roof seams and rails are flush decorative surfaces with no collision.
static func build(parent: Node3D, map: MapDefinition, graybox: bool = false) -> StaticBody3D:
	var terrain := TerrainFixtures.box(parent,Vector3(0,-0.5,0),Vector3(350,1,450),Color("666864"))
	terrain.name = "IndustrialTerrain"
	WorldCollisionRules.tag(terrain,"terrain")
	for item in map.obstacles:
		var color := Color("828b87") if item.kind == "building" else Color("77756c")
		if str(item.id).begins_with("outer"): color = Color("887d6b")
		var body := TerrainFixtures.box(parent,item.position,item.size,Color("888888") if graybox else color)
		body.name = item.id
		WorldCollisionRules.tag(body,item.kind)
		if not graybox and item.kind == "building": warehouse_details(body,item.size)
	roads(parent,map)
	for p in map.supply_reservations:
		var marker := CoreVehicleVisual.box(parent,p+Vector3.UP*0.025,Vector3(14,0.03,8),Color("8f9a81"))
		WorldCollisionRules.tag(marker,"supply_reservation")
		var label := Label3D.new(); label.font = CoreUI.FONT
		label.text = "弹药补给 · 驻车每2秒1发"; label.font_size = 40; label.position = p+Vector3(0,2,0)
		parent.add_child(label)
	if not graybox:
		for x in [-13,13]:
			for side in [-0.75,0.75]:
				var rail := CoreVehicleVisual.box(parent,Vector3(x+side,0.014,0),Vector3(0.09,0.012,70),Color("b9b8a7"))
				rail.name = "FlushRail"; WorldCollisionRules.tag(rail,"road")
			for z in range(-34,35,2):
				var sleeper := CoreVehicleVisual.box(parent,Vector3(x,0.006,z),Vector3(2.1,0.01,0.2),Color("494b47"))
				WorldCollisionRules.tag(sleeper,"road")
		for side in [-1,1]:
			var sign := Label3D.new(); sign.font = CoreUI.FONT; sign.font_size = 70
			sign.text = "货运广场  A"; sign.position = Vector3(side*65,2.5,side*1.05)
			if side<0: sign.rotation.y = PI
			parent.add_child(sign); WorldCollisionRules.tag(sign,"sign")
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_color = Color("f4ead8"); sun.light_energy = 0.9; sun.shadow_enabled = true; sun.directional_shadow_max_distance = 240
	parent.add_child(sun)
	var world := WorldEnvironment.new(); world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR; world.environment.background_color = Color("bac3c3")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("dfe5e4"); world.environment.ambient_light_energy = 0.45
	parent.add_child(world)
	return terrain

static func warehouse_details(body: StaticBody3D, size: Vector3) -> void:
	for side in [-1,1]:
		var z: float = side*(size.z/2+0.012)
		for x in [-size.x*0.3,size.x*0.3]:
			var door := CoreVehicleVisual.box(body,Vector3(x,-size.y/2+2.2,z),Vector3(minf(8,size.x*0.3),4.4,0.02),Color("434d4e"))
			WorldCollisionRules.tag(door,"sign")
			for y in [0.2,1.4,2.6]: CoreVehicleVisual.box(body,Vector3(x,-size.y/2+y,z+side*0.012),Vector3(minf(7.8,size.x*0.29),0.035,0.012),Color("89918b"))
		for x in range(int(-size.x/2)+4,int(size.x/2)-2,6):
			CoreVehicleVisual.box(body,Vector3(x,size.y/2-1.2,z),Vector3(2.8,0.8,0.02),Color("b4c9ca"))
	for x in range(int(-size.x/2)+2,int(size.x/2),4):
		CoreVehicleVisual.box(body,Vector3(x,size.y/2+0.006,0),Vector3(0.06,0.01,size.z),Color("b0b0a3"))

static func roads(parent: Node3D, map: MapDefinition) -> void:
	var nav := DriveNavigator.new(); nav.configure(map.graph)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in map.graph.edges:
		if not edge.get("road_visual",false): continue
		var a: Vector3 = nav.nodes[edge.a]; var b: Vector3 = nav.nodes[edge.b]
		var side := (b-a).normalized().cross(Vector3.UP)*7.0
		var corners := [a-side,a+side,b+side,b-side]
		for i in [0,1,2,0,2,3]: st.add_vertex(corners[i]+Vector3.UP*0.022)
	st.generate_normals()
	var mesh := st.commit(); var mat := VillageWorld.material(Color("484e4d")); mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mesh.surface_set_material(0,mat)
	var visual := MeshInstance3D.new(); visual.mesh = mesh; visual.name = "IndustrialStreets"
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldCollisionRules.tag(visual,"road"); parent.add_child(visual)
