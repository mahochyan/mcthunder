class_name RiverJunctionWorld
extends RefCounted
## Deterministic original environment sample. Static collision is survey-grade, not destruction-ready.
var root: Node3D
var rng := RandomNumberGenerator.new()
var buildings: Array[Rect2]=[]
var stats := {"buildings":0,"trees":0,"bridges":0,"terrain_tiles":0}
var cube := BoxMesh.new()
var sphere := SphereMesh.new()

func build(parent: Node3D) -> void:
	root=parent; rng.seed=13092026
	sphere.radial_segments=12; sphere.rings=7
	_terrain(); _roads_and_river(); _districts(); _vegetation(); _lighting()
	root.set_meta("river_junction_stats",stats.duplicate())

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.91; return mat

func finish(batch: StaticArtBatch,title: String, masonry: bool=false) -> MeshInstance3D:
	var instance := batch.finish(root,title)
	if masonry:
		var mat := ShaderMaterial.new(); mat.shader=load("res://assets/shaders/river_buildings.gdshader"); instance.material_override=mat
	else:
		var mat := material(Color.WHITE); mat.vertex_color_use_as_albedo=true; mat.vertex_color_is_srgb=true; instance.material_override=mat
	return instance

func box(batch: StaticArtBatch,p: Vector3,size: Vector3,color: Color,angle: float=0) -> void:
	batch.mesh(cube,Transform3D(Basis(Vector3.UP,angle).scaled(size),p),color)

func body(p: Vector3,size: Vector3,title: String) -> void:
	var node := StaticBody3D.new(); node.name=title; node.position=p; root.add_child(node)
	var shape := CollisionShape3D.new(); var geometry := BoxShape3D.new(); geometry.size=size; shape.shape=geometry; node.add_child(shape)

func _terrain() -> void:
	var mat := ShaderMaterial.new(); mat.shader=load("res://assets/shaders/river_ground.gdshader")
	# 200 m chunks keep world bounds local; no monolithic foliage/terrain batch.
	for tx in range(-1200,1200,200):
		for tz in range(-1000,1000,200):
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for x in range(tx,tx+200,8):
				for z in range(tz,tz+200,8):
					var a := RiverJunctionDefinition.point(Vector2(x,z)); var b := RiverJunctionDefinition.point(Vector2(x+8,z))
					var c := RiverJunctionDefinition.point(Vector2(x,z+8)); var d := RiverJunctionDefinition.point(Vector2(x+8,z+8))
					for p in [a,b,c,b,d,c]:
						st.add_vertex(p)
			st.generate_normals(); st.index()
			var mesh := MeshInstance3D.new(); mesh.name="Terrain_%d_%d"%[tx,tz]; mesh.mesh=st.commit(); mesh.material_override=mat; root.add_child(mesh)
			mesh.create_trimesh_collision(); stats.terrain_tiles+=1

func ribbon(points: PackedVector2Array,width: float,tint: Color,title: String,level: float=8.09) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()):
		var a := points[i-1]; var b := points[i]; var tangent := (b-a).normalized(); var side := Vector2(-tangent.y,tangent.x)*width*.5
		for p in [a-side,b-side,a+side,a+side,b-side,b+side]:
			st.set_normal(Vector3.UP); st.add_vertex(Vector3(p.x,level,p.y))
	var mesh := MeshInstance3D.new(); mesh.name=title; mesh.mesh=st.commit(); mesh.material_override=material(tint); mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(mesh); return mesh

func _roads_and_river() -> void:
	var water := PackedVector2Array()
	for x in range(-1200,1201,8): water.append(Vector2(x,RiverJunctionDefinition.river_z(x)))
	var river := ribbon(water,31,Color("4b6661"),"River",-1.0)
	var wm := ShaderMaterial.new(); wm.shader=load("res://assets/shaders/river_water.gdshader"); river.material_override=wm
	var batch := StaticArtBatch.new()
	for line in RiverJunctionDefinition.road_lines():
		ribbon(line,21,Color("756d59"),"RoadShoulder",8.035)
		ribbon(line,15,Color("4b4c46"),"RoadSurface")
		# Road markings are short, spaced physical strips, readable at street height.
		for i in range(1,line.size()):
			var a := line[i-1]; var b := line[i]; var distance := a.distance_to(b)
			for step in range(0,int(distance),12):
				var p := a.lerp(b,minf((step+2.0)/distance,1.0)); var dir := b-a
				box(batch,Vector3(p.x,8.115,p.y),Vector3(.15,.018,4),Color("b9b098"),atan2(dir.x,dir.y))
	for lane in RiverJunctionDefinition.LANES:
		var z := RiverJunctionDefinition.river_z(lane)
		box(batch,Vector3(lane,7.0,z),Vector3(23,2,104),Color("797c73"))
		body(Vector3(lane,7.0,z),Vector3(23,2,104),"BridgeDeck")
		for side in [-1,1]:
			box(batch,Vector3(lane+side*10.5,8.3,z),Vector3(1,.6,104),Color("99998b"))
			for dz in range(-48,49,8):
				box(batch,Vector3(lane+side*10.5,9.0,z+dz),Vector3(.16,1.2,.16),Color("555e59"))
			for y in [8.8,9.5]: box(batch,Vector3(lane+side*10.5,y,z),Vector3(.12,.12,104),Color("6c736a"))
		for dz in [-28,28]: box(batch,Vector3(lane,2,z+dz),Vector3(20,10,3),Color("666e66"))
		stats.bridges+=1
	# Two tracks, proper ballast, sleepers, rails and loading platform north of the river.
	for x in [-36.0,-28.0]:
		box(batch,Vector3(x,8.1,-275),Vector3(5,.2,430),Color("64665c"))
		for z in range(-485,-60,3): box(batch,Vector3(x,8.26,z),Vector3(3,.16,.30),Color("494638"))
		for side in [-.75,.75]: box(batch,Vector3(x+side,8.43,-275),Vector3(.10,.22,430),Color("6e726d"))
	box(batch,Vector3(-12,8.6,-145),Vector3(17,1.2,110),Color("aaa58f"))
	for z in [-195,-173,-151,-129]:
		box(batch,Vector3(-36,10.2,z),Vector3(3.0,3.2,17),Color("655541"))
		box(batch,Vector3(-36,12,z),Vector3(3.2,.35,17),Color("484c47"))
		for dx in [-1.3,1.3]:
			for dz in [-5,5]: box(batch,Vector3(-36+dx,8.9,z+dz),Vector3(.25,1.1,1.1),Color("303936"))
	finish(batch,"Road_Bridge_Rail_Details")

func house(batch: StaticArtBatch,p: Vector2,size: Vector3,tint: Color,roof_tint: Color) -> void:
	var base := RiverJunctionDefinition.height(p.x,p.y)
	var center := Vector3(p.x,base+size.y*.5,p.y)
	box(batch,center,size,tint)
	box(batch,Vector3(p.x,base+.4,p.y),Vector3(size.x+.35,.8,size.z+.35),Color("7b7c70"))
	body(center,size,"BuildingShell")
	buildings.append(Rect2(p-Vector2(size.x,size.z)*.5,Vector2(size.x,size.z)))
	var rise := size.x*.27
	var angle := atan2(rise,size.x*.5)
	var roof_length := sqrt(pow(size.x*.5+.7,2)+pow(rise,2))
	var gable := SurfaceTool.new(); gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		var points := [Vector3(-size.x*.5,0,side*size.z*.5),Vector3(size.x*.5,0,side*size.z*.5),Vector3(0,rise,side*size.z*.5)]
		if side>0: points.reverse()
		for v in points: gable.add_vertex(v)
	gable.generate_normals()
	batch.mesh(gable.commit(),Transform3D(Basis.IDENTITY,Vector3(p.x,base+size.y,p.y)),tint)
	for side in [-1,1]:
		var roof := BoxMesh.new(); roof.size=Vector3(roof_length,.22,size.z+1.4)
		batch.mesh(roof,Transform3D(Basis(Vector3.FORWARD,side*angle),Vector3(p.x+side*size.x*.25,base+size.y+rise*.5,p.y)),roof_tint)
		# Gutters, fascia, windows with recess surround, stone sills and shutters.
		box(batch,Vector3(p.x+side*(size.x*.5+.5),base+size.y-.05,p.y),Vector3(.20,.22,size.z+1.2),Color("565c56"))
		for z in range(2,int(size.z)-1,4):
			for floor_index in maxi(1,int(size.y/3.2)):
				var y := base+2+floor_index*3.1
				var px: float=p.x+side*(size.x*.5+.04); var pz := p.y-size.z*.5+z
				box(batch,Vector3(px,y,pz),Vector3(.16,1.65,1.4),Color("d1cbb6"))
				box(batch,Vector3(px+side*.10,y,pz),Vector3(.05,1.35,1.1),Color("344a48"))
				box(batch,Vector3(px+side*.16,y,pz),Vector3(.07,1.35,.055),Color("a9ae9a"))
				box(batch,Vector3(px,y-.86,pz),Vector3(.45,.14,1.6),Color("b8b5a5"))
				for shutter in [-1,1]: box(batch,Vector3(px,y,pz+shutter*.97),Vector3(.13,1.65,.45),Color("56624c"))
		for x in range(2,int(size.x)-1,4):
			var px := p.x-size.x*.5+x; var pz: float=p.y+side*(size.z*.5+.08)
			box(batch,Vector3(px,base+2,pz),Vector3(1.3,1.6,.12),Color("d1cbb6"))
			box(batch,Vector3(px,base+2,pz+side*.07),Vector3(1.05,1.35,.06),Color("344a48"))
	# Closed front door, lintel and step. Buildings are cover shells at this phase.
	box(batch,Vector3(p.x,base+1.35,p.y-size.z*.5-.1),Vector3(1.6,2.7,.2),Color("4a5146"))
	box(batch,Vector3(p.x,base+.15,p.y-size.z*.5-.7),Vector3(2.5,.3,1.3),Color("a1a18f"))
	box(batch,Vector3(p.x+size.x*.23,base+size.y+rise,p.y+size.z*.2),Vector3(1,2.9,1.1),Color("8b705b"))
	box(batch,Vector3(p.x+size.x*.23,base+size.y+rise+1.5,p.y+size.z*.2),Vector3(1.35,.18,1.4),Color("5a5d53"))
	stats.buildings+=1

func _districts() -> void:
	# Town blocks have a through street plus a perimeter bypass; no compulsory cul-de-sac.
	var town := StaticArtBatch.new()
	for x in [462.0,493.0,553.0,586.0]:
		for z in [70.0,105.0,140.0,177.0]:
			if x==493 and z==105: continue
			house(town,Vector2(x,z),Vector3(rng.randf_range(12,18),rng.randi_range(1,2)*3.3,rng.randf_range(17,23)),Color("c1b298").darkened(rng.randf_range(0,.22)),Color("7e5342"))
	for z in [50.0,125.0,200.0]: ribbon(PackedVector2Array([Vector2(432,z),Vector2(610,z)]),14,Color("76756b"),"TownLane",8.06)
	for x in [435.0,610.0]: ribbon(PackedVector2Array([Vector2(x,50),Vector2(x,200)]),14,Color("76756b"),"TownBypass",8.06)
	# Courtyard walls are interrupted by 14 m drive-through gaps.
	for z in [84.0,158.0]:
		for x in [470.0,577.0]: box(town,Vector3(x,9,z),Vector3(22,2,.55),Color("8b8975"))
	for x in [441.0,602.0]:
		for z in [65.0,105.0,145.0,185.0]:
			box(town,Vector3(x,12,z),Vector3(.14,8,.14),Color("5c6158"))
			box(town,Vector3(x+1,16,z),Vector3(2.2,.15,.15),Color("5c6158"))
			box(town,Vector3(x+2,15.8,z),Vector3(.7,.28,.4),Color("d7ceaa"))
	# Pavement slabs, kerbs, planters, fence rails and street furniture anchor human scale.
	for x in [507.0,535.0]:
		box(town,Vector3(x,8.16,130),Vector3(3,.32,145),Color("989b8a"))
		for z in range(60,201,2): box(town,Vector3(x,8.33,z),Vector3(2.9,.02,.04),Color("777c70"))
	for p in [Vector2(494,110),Vector2(550,150),Vector2(458,90)]:
		box(town,Vector3(p.x,8.7,p.y),Vector3(5,1.4,2),Color("8f8773"))
		box(town,Vector3(p.x,9.5,p.y),Vector3(4.7,.7,1.8),Color("475a3b"))
		box(town,Vector3(p.x+7,8.7,p.y),Vector3(2.4,.16,.65),Color("625941"))
		box(town,Vector3(p.x+7,9.15,p.y+.3),Vector3(2.4,.7,.12),Color("625941"))
		for dx in [-.9,.9]: box(town,Vector3(p.x+7+dx,8.4,p.y),Vector3(.12,.7,.6),Color("47514a"))
	for x in [452.0,595.0]:
		for z in range(75,185,5): box(town,Vector3(x,8.8,z),Vector3(.15,1.6,.15),Color("756e52"))
		for y in [8.5,9.15]: box(town,Vector3(x,y,128),Vector3(.1,.14,110),Color("756e52"))
	finish(town,"RiversideTown_Detail",true)
	var rail := StaticArtBatch.new()
	house(rail,Vector2(38,-155),Vector3(25,7,54),Color("ab9b80"),Color("59665f"))
	house(rail,Vector2(-95,-160),Vector3(36,10,75),Color("8b8b7c"),Color("596560"))
	house(rail,Vector2(70,-225),Vector3(22,5,25),Color("b9a98b"),Color("75594b"))
	for x in [-72.0,-57.0]:
		for z in [-260.0,-243.0,-226.0]:
			var tint := Color("666e5d") if x==-72 else Color("985f49")
			box(rail,Vector3(x,9.5,z),Vector3(6,3,12),tint)
			for dz in range(-5,6,1): box(rail,Vector3(x+3.025,9.5,z+dz),Vector3(.06,2.9,.08),tint.lightened(.15))
	for x in [-65.0,5.0]:
		box(rail,Vector3(x,16,-115),Vector3(1.2,16,1.2),Color("6c746d"))
	box(rail,Vector3(-30,24,-115),Vector3(72,1.2,2),Color("6c746d"))
	finish(rail,"FreightDepot_Detail",true)
	for p in [Vector2(-520,-320),Vector2(520,340),Vector2(-820,350),Vector2(820,-350)]:
		var batch := StaticArtBatch.new()
		for dx in [-42.0,42.0]:
			for dz in [-32.0,32.0]: house(batch,p+Vector2(dx,dz),Vector3(22,6,28),Color("a59c7c"),Color("666457"))
		for dz in [-65.0,65.0]: box(batch,RiverJunctionDefinition.point(p+Vector2(0,dz),1),Vector3(35,2,1),Color("868575"))
		finish(batch,"OuterDistrict",true)
	var quarry := StaticArtBatch.new()
	for i in 6:
		var p := Vector2(-605+i*12,110+sin(i)*40)
		box(quarry,RiverJunctionDefinition.point(p,3),Vector3(24,6,20),Color("969687"))
	for i in 9: box(quarry,Vector3(-567+float(i%3)*10,9,180+float(i/3)*8),Vector3(8,2,6),Color("aea995"))
	finish(quarry,"QuarryTerraces")

func _vegetation() -> void:
	var clusters := {}
	for i in 6500:
		var p := Vector2(rng.randf_range(-1170,1170),rng.randf_range(-970,970))
		if RiverJunctionDefinition.road_distance(p.x,p.y)<25 or absf(p.y-RiverJunctionDefinition.river_z(p.x))<44: continue
		if absf(absf(p.x)-260)<80 and (absf(absf(p.y)-490)<60 or absf(absf(p.y)-690)<60): continue
		var near_building := false
		for rectangle in buildings:
			if rectangle.grow(12).has_point(p): near_building=true; break
		if near_building: continue
		# Preserve farmland/open maneuvre pockets; cluster trees in belts and groves.
		if sin(p.x*.012)*cos(p.y*.017)<-.1: continue
		if absf(p.x)<115 and p.y<30 and p.y>-510: continue
		var key := Vector2i(floori(p.x/200),floori(p.y/200))
		if not clusters.has(key): clusters[key]=[]
		clusters[key].append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(.8,1.5)),RiverJunctionDefinition.point(p)))
	# Rounded crowns, branch/trunk structure and tonal variation, instead of stacked cones.
	var tree := SurfaceTool.new(); tree.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new(); trunk.top_radius=.14; trunk.bottom_radius=.32; trunk.height=7; trunk.radial_segments=10
	append_smooth(tree,trunk,Transform3D(Basis.IDENTITY,Vector3(0,3.5,0)),Color("625d47"))
	sphere.radial_segments=16; sphere.rings=8
	for i in 7:
		var angle := float(i)*2.4
		var p := Vector3(cos(angle)*2.0,6.5+float(i%3)*1.1,sin(angle)*1.7)
		append_smooth(tree,sphere,Transform3D(Basis.IDENTITY.scaled(Vector3(4.7,3.2,4.5)),p),Color("566743").lightened(float(i%3)*.035))
	var tree_mesh := tree.commit()
	var tree_material := material(Color.WHITE); tree_material.vertex_color_use_as_albedo=true; tree_material.vertex_color_is_srgb=true
	for key in clusters:
		var poses: Array=clusters[key]
		var instance := MultiMeshInstance3D.new(); instance.name="Grove_%d_%d"%[key.x,key.y]
		instance.multimesh=MultiMesh.new(); instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D; instance.multimesh.mesh=tree_mesh; instance.material_override=tree_material
		instance.multimesh.instance_count=poses.size()
		for i in poses.size(): instance.multimesh.set_instance_transform(i,poses[i])
		root.add_child(instance); stats.trees+=poses.size()

func append_smooth(st: SurfaceTool,mesh: Mesh,pose: Transform3D,tint: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		st.set_color(tint); st.set_normal((pose.basis.inverse().transposed()*normals[index]).normalized()); st.add_vertex(pose*vertices[index])

func _lighting() -> void:
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-32,-38,0); sun.light_color=Color("fff0d7"); sun.light_energy=.88
	sun.shadow_enabled=true; sun.directional_shadow_max_distance=650; root.add_child(sun)
	var env := WorldEnvironment.new(); env.environment=Environment.new(); root.add_child(env)
	var sky := Sky.new(); var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("708f9f"); sky_mat.sky_horizon_color=Color("c4d0c6"); sky_mat.ground_horizon_color=Color("c4d0c6"); sky_mat.ground_bottom_color=Color("737b68"); sky.sky_material=sky_mat
	env.environment.background_mode=Environment.BG_SKY; env.environment.sky=sky
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("b0bfbc"); env.environment.ambient_light_energy=.42
	env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment.fog_enabled=true; env.environment.fog_light_color=Color("b9c8bf"); env.environment.fog_density=.00006
