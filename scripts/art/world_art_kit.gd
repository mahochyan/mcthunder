class_name WorldArtKit
extends RefCounted
## Shared meter-scale scene pieces. Visual detail batches never write gameplay state.
static func box(parent: Node3D, position: Vector3, size: Vector3, palette_key: String) -> StaticBody3D:
	var body := TerrainFixtures.box(parent,position,size,ArtPalette.color(palette_key))
	for child in body.get_children():
		if child is MeshInstance3D: child.material_override = ArtPalette.material(palette_key)
	return body

static func house_details(body: StaticBody3D, size: Vector3) -> void:
	var w := size.x/2; var d := size.z/2; var y := size.y/2; var ridge := y+size.x*0.23
	var points := PackedVector3Array([Vector3(-w,y,-d),Vector3(w,y,-d),Vector3(0,ridge,-d),Vector3(-w,y,d),Vector3(w,y,d),Vector3(0,ridge,d)])
	var batch := StaticArtBatch.new()
	# Clockwise render winding; the convex collider uses these same six vertices.
	batch.polygon(points,PackedInt32Array([0,1,2,3,5,4,0,5,3,0,2,5,1,5,2,1,4,5,0,4,1,0,3,4]),"roof")
	var shape := CollisionShape3D.new(); var convex := ConvexPolygonShape3D.new(); convex.points = points; shape.shape = convex; body.add_child(shape)
	for side in [-1,1]:
		for x in [-size.x*0.3,size.x*0.3]:
			batch.box(Vector3(x,0.3,side*(d+0.012)),Vector3(1.2,1.6,0.02),"glass")
			for offset in [-0.7,0.7]: batch.box(Vector3(x+offset,0.3,side*(d+0.024)),Vector3(0.15,1.8,0.035),"wood_dark")
			batch.box(Vector3(x,-0.56,side*(d+0.025)),Vector3(1.6,0.12,0.07),"stone")
		batch.box(Vector3(0,-y+1.1,side*(d+0.014)),Vector3(1.4,2.2,0.025),"wood_dark")
		batch.box(Vector3(0,-y+2.22,side*(d+0.025)),Vector3(1.6,0.12,0.06),"wood")
		batch.box(Vector3(0,y-0.1,side*(d+0.014)),Vector3(size.x,0.18,0.025),"wood_dark")
	batch.box(Vector3(0,-y+0.3,0),Vector3(size.x+0.015,0.6,size.z+0.015),"stone")
	batch.finish(body,"Cosmetic_HouseDetails")

static func warehouse_details(body: StaticBody3D, size: Vector3) -> void:
	var batch := StaticArtBatch.new()
	for side in [-1,1]:
		var z: float = side*(size.z/2+0.012)
		for x in [-size.x*0.3,size.x*0.3]:
			batch.box(Vector3(x,-size.y/2+2.2,z),Vector3(minf(8,size.x*0.3),4.4,0.02),"dark")
			for y in [0.2,1.4,2.6]: batch.box(Vector3(x,-size.y/2+y,z+side*0.012),Vector3(minf(7.8,size.x*0.29),0.035,0.012),"steel")
		for x in range(int(-size.x/2)+4,int(size.x/2)-2,6):
			batch.box(Vector3(x,size.y/2-1.2,z),Vector3(2.8,0.8,0.02),"glass")
			batch.box(Vector3(x,size.y/2-1.64,z+side*0.02),Vector3(3.0,0.12,0.045),"concrete")
		for x in [-size.x/2+0.25,size.x/2-0.25]: batch.box(Vector3(x,0,z),Vector3(0.45,size.y,0.035),"concrete")
	for x in range(int(-size.x/2)+2,int(size.x/2),4):
		batch.box(Vector3(x,size.y/2+0.006,0),Vector3(0.06,0.01,size.z),"steel")
	batch.finish(body,"Cosmetic_WarehouseDetails")

static func stone_wall_details(body: StaticBody3D, size: Vector3) -> void:
	var batch := StaticArtBatch.new()
	for side in [-1,1]:
		for row in maxi(1,int(size.y/0.55)):
			batch.box(Vector3(0,-size.y/2+0.25+row*0.55,side*(size.z/2+0.008)),Vector3(size.x,0.022,0.01),"mortar")
	batch.finish(body,"Cosmetic_StoneCourses")

static func rail_details(parent: Node3D) -> void:
	var batch := StaticArtBatch.new()
	for x in [-13,13]:
		for side in [-0.75,0.75]: batch.box(Vector3(x+side,0.014,0),Vector3(0.09,0.012,70),"steel")
		for z in range(-34,35,2): batch.box(Vector3(x,0.006,z),Vector3(2.1,0.01,0.2),"wood_dark")
	var visual := batch.finish(parent,"Cosmetic_FlushRailAssembly")
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorldCollisionRules.tag(visual,"road")

static func tree(parent: Node3D, location: Vector3, size: float = 1.0) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = "LowPolyTree"; body.position = location
	body.collision_layer = GameConfig.LAYER_WORLD; body.collision_mask = 0; WorldCollisionRules.tag(body,"tree")
	parent.add_child(body)
	var batch := StaticArtBatch.new()
	var trunk := CylinderMesh.new(); trunk.radial_segments = 8; trunk.rings = 1
	trunk.top_radius=0.21*size; trunk.bottom_radius=0.31*size; trunk.height=4.0*size
	_add_convex_piece(body,batch,trunk,Vector3(0,2*size,0),"wood_dark")
	for layer in 2:
		var crown := CylinderMesh.new(); crown.radial_segments=7; crown.rings=1; crown.top_radius=0
		crown.bottom_radius=(2.1-layer*0.65)*size; crown.height=(3.6-layer*0.6)*size
		_add_convex_piece(body,batch,crown,Vector3(0,(3.8+layer*1.7)*size,0),"leaves")
	batch.finish(body,"TreeMesh")
	return body

static func rocks(parent: Node3D, location: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name="LowPolyRockPile"; body.position=location
	body.collision_layer=GameConfig.LAYER_WORLD; body.collision_mask=0; WorldCollisionRules.tag(body,"rock")
	parent.add_child(body)
	var batch := StaticArtBatch.new()
	for i in 3:
		var primitive := SphereMesh.new(); primitive.radial_segments=7; primitive.rings=3; primitive.radius=1.3-i*0.22; primitive.height=(1.3-i*0.22)*2
		var source := M4LowPolyDetails.flat_mesh(primitive)
		_add_convex_piece(body,batch,source,Vector3((i-1)*1.25,0.5-i*0.05,sin(i*1.7)*0.4),"stone")
	batch.finish(body,"RockMesh")
	return body

static func _add_convex_piece(body: StaticBody3D, batch: StaticArtBatch, mesh: Mesh, p: Vector3, key: String) -> void:
	batch.mesh(mesh,Transform3D(Basis.IDENTITY,p),ArtPalette.color(key))
	var convex := ConvexPolygonShape3D.new(); convex.points=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var shape := CollisionShape3D.new(); shape.shape=convex; shape.position=p; body.add_child(shape)
