class_name CoreVehicleVisual
extends RefCounted
## Original cosmetic details; no physics shapes, no changes to hit geometry or muzzle.
static func decorate(hull: Node3D, turret: Node3D, layer: int) -> void:
	var steel := Color("3d493b")
	var dark := Color("242b29")
	for side in [-1,1]:
		for i in 12:
			box(hull,Vector3(side*1.25,0.605,-1.78+i*0.32),Vector3(0.56,0.025,0.22),dark,layer)
		for i in 6:
			box(hull,Vector3(side*1.528,0.3,-1.52+i*0.6),Vector3(0.025,0.36,0.38),steel,layer)
			box(hull,Vector3(side*1.545,0.3,-1.52+i*0.6),Vector3(0.015,0.14,0.15),dark,layer)
		box(hull,Vector3(side*0.65,1.364,-1.15),Vector3(0.54,0.028,0.52),steel,layer)
		box(hull,Vector3(side*0.65,1.39,-1.22),Vector3(0.23,0.035,0.09),dark,layer)
	for i in 7:
		box(hull,Vector3(-0.66+i*0.22,1.36,1.05),Vector3(0.1,0.022,0.6),dark,layer)
	box(turret,Vector3(-0.29,0.565,0.36),Vector3(0.58,0.03,0.62),steel,layer)
	box(turret,Vector3(0.31,0.565,0.15),Vector3(0.38,0.03,0.47),steel,layer)
	for side in [-1,1]:
		box(turret,Vector3(side*0.756,0.30,0.3),Vector3(0.015,0.17,0.45),Color("bdc2a0"),layer)
		for i in 3:
			box(turret,Vector3(side*0.766,0.30,0.17+i*0.12),Vector3(0.012,0.13,0.04),steel,layer)

static func box(parent: Node3D, position: Vector3, size: Vector3, color: Color, layer: int = 1) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Cosmetic"
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mesh.material = mat
	node.mesh = mesh
	node.position = position
	node.layers = layer
	parent.add_child(node)
	return node
