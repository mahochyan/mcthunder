class_name IndustrialWorld
extends RefCounted
## All solid geometry is a box whose visible mesh and physics size agree exactly.
## Painted doors, roof seams and rails are flush decorative surfaces with no collision.
static func build(parent: Node3D, map: MapDefinition, graybox: bool = false) -> StaticBody3D:
	var terrain := TerrainFixtures.box(parent,Vector3(0,-0.5,0),Vector3(350,1,450),Color("666864"))
	terrain.name = "IndustrialTerrain"
	WorldCollisionRules.tag(terrain,"terrain")
	for item in map.obstacles:
		var color := ArtPalette.color("warehouse") if item.kind == "building" else ArtPalette.color("concrete")
		if str(item.id).begins_with("outer"): color = ArtPalette.color("earth")
		var body := TerrainFixtures.box(parent,item.position,item.size,Color("888888") if graybox else color)
		body.name = item.id
		WorldCollisionRules.tag(body,item.kind)
		if not graybox and item.kind == "building": warehouse_details(body,item.size)
		if not graybox and item.kind == "stone_wall": WorldArtKit.stone_wall_details(body,item.size)
	roads(parent,map)
	SpecialStructures.build(parent,map)
	for p in map.supply_reservations:
		var marker := CoreVehicleVisual.box(parent,p+Vector3.UP*0.025,Vector3(14,0.03,8),Color("8f9a81"))
		WorldCollisionRules.tag(marker,"supply_reservation")
		var label := Label3D.new(); label.font = CoreUI.FONT
		label.text = "弹药补给 · 驻车每2秒1发"; label.font_size = 40; label.position = p+Vector3(0,2,0)
		parent.add_child(label)
	if not graybox:
		WorldArtKit.rail_details(parent)
		WorldProps.build(parent,map)
		for side in [-1,1]:
			var sign := Label3D.new(); sign.font = CoreUI.FONT; sign.font_size = 70
			sign.text = "货运广场  A"; sign.position = Vector3(side*65,2.5,side*1.05)
			if side<0: sign.rotation.y = PI
			parent.add_child(sign); WorldCollisionRules.tag(sign,"sign")
	WorldLighting.build(parent)
	return terrain

static func warehouse_details(body: StaticBody3D, size: Vector3) -> void:
	WorldArtKit.warehouse_details(body,size)

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
