class_name M4VoxelDetails
extends RefCounted
## Instanced voxel details grouped by part/material: small features without one draw call per block.
const OLIVE := Color("626d49")
const EDGE := Color("87906b")
const DARK := Color("30372c")
const RUBBER := Color("252a25")
const STEEL := Color("555c50")
var groups: Dictionary = {}

func cube(parent: Node3D, p: Vector3, s: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var key := str(parent.get_instance_id())+color.to_html()
	if not groups.has(key): groups[key] = {"parent":parent,"color":color,"transforms":[]}
	groups[key].transforms.append(Transform3D(Basis.from_euler(rotation).scaled(s),p))

func disk(parent: Node3D, p: Vector3, radius: float, width: float, color: Color, axis: String = "x") -> void:
	# Voxel cross-section, with an actual stepped perimeter instead of a square wheel.
	var cell := 0.065
	var count := ceili(radius/cell)
	for a in range(-count,count):
		for b in range(-count,count):
			var u := (a+0.5)*cell
			var v := (b+0.5)*cell
			if u*u+v*v > radius*radius: continue
			cube(parent,p+(Vector3(0,u,v) if axis == "x" else Vector3(u,0,v)),Vector3(width,cell,cell) if axis == "x" else Vector3(cell,width,cell),color)

func finish(layer: int) -> void:
	for group in groups.values():
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var material := StandardMaterial3D.new()
		material.albedo_color = group.color
		material.roughness = 0.9
		mesh.material = material
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = group.transforms.size()
		for i in instances.instance_count: instances.set_instance_transform(i,group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Cosmetic_VoxelDetails"
		node.multimesh = instances
		node.layers = layer
		group.parent.add_child(node)

static func build(hull: Node3D, turret: Node3D, gun: Node3D, layer: int) -> void:
	var b := M4VoxelDetails.new()
	for side in [-1,1]:
		var x: float = side*1.2
		# Three VVSS bogies, paired wheels, triangular arms and vertical spring housings.
		for z in [-1.45,0.0,1.45]:
			for offset in [-0.35,0.35]:
				b.disk(hull,Vector3(x,0.39,z+offset),0.34,0.28,RUBBER)
				b.disk(hull,Vector3(x+side*0.15,0.39,z+offset),0.255,0.04,OLIVE)
				b.disk(hull,Vector3(x+side*0.18,0.39,z+offset),0.09,0.065,EDGE)
				b.cube(hull,Vector3(x+side*0.18,0.61,z+offset*0.45),Vector3(0.11,0.14,0.48),OLIVE,Vector3(offset*1.8,0,0))
			b.cube(hull,Vector3(x,0.78,z),Vector3(0.32,0.34,0.30),OLIVE)
			for spring in [-0.10,0.10]:
				for i in 5: b.cube(hull,Vector3(x+side*0.19,0.69+i*0.045,z+spring),Vector3(0.09,0.027,0.12),EDGE)
			b.disk(hull,Vector3(x,0.98,z+0.35),0.11,0.24,RUBBER)
		for z in [-2.15,2.15]:
			b.disk(hull,Vector3(x,0.56,z),0.45,0.28,OLIVE)
			b.disk(hull,Vector3(x+side*0.15,0.56,z),0.34,0.025,DARK)
			b.disk(hull,Vector3(x+side*0.18,0.56,z),0.12,0.06,EDGE)
			for i in 8:
				var a := i*TAU/8
				b.cube(hull,Vector3(x+side*0.17,0.56+sin(a)*0.22,z+cos(a)*0.22),Vector3(0.05,0.085,0.25),OLIVE,Vector3(-a,0,0))
		b.cube(hull,Vector3(x,1.16,0),Vector3(0.54,0.06,5.35),OLIVE)
		for z in [-2.57,2.52]: b.cube(hull,Vector3(x,1.05,z),Vector3(0.54,0.28,0.08),OLIVE)
		# Large hull hatches, periscopes, lifting eyes, guards and headlamps.
		b.disk(hull,Vector3(side*0.62,1.87,-1.16),0.36,0.055,DARK,"y")
		b.disk(hull,Vector3(side*0.62,1.91,-1.16),0.32,0.065,OLIVE,"y")
		b.cube(hull,Vector3(side*0.62,1.97,-1.25),Vector3(0.22,0.085,0.12),DARK)
		b.cube(hull,Vector3(side*0.62,2.02,-1.26),Vector3(0.25,0.025,0.15),EDGE)
		b.cube(hull,Vector3(side*0.91,1.37,-2.24),Vector3(0.14,0.16,0.12),Color("d1c7a0"))
		for dx in [-0.11,0.11]: b.cube(hull,Vector3(side*0.91+dx,1.42,-2.24),Vector3(0.035,0.24,0.2),OLIVE)
		b.cube(hull,Vector3(side*0.91,1.55,-2.24),Vector3(0.25,0.035,0.2),OLIVE)
		for z in [-2.5,2.63]:
			b.cube(hull,Vector3(side*0.72,0.79,z),Vector3(0.15,0.2,0.13),DARK)
			b.cube(hull,Vector3(side*0.72,0.87,z),Vector3(0.24,0.07,0.15),EDGE)
	# Engine grilles, panel seams, hinge bars, rear exhaust deflector and pioneer tools.
	for x in [-0.56,0.56]:
		b.cube(hull,Vector3(x,1.866,1.50),Vector3(0.96,0.035,1.24),DARK)
		for i in 17: b.cube(hull,Vector3(x,1.892,0.94+i*0.068),Vector3(0.91,0.025,0.035),OLIVE)
		b.cube(hull,Vector3(x,1.93,2.19),Vector3(0.85,0.035,0.035),EDGE)
	for i in 9: b.cube(hull,Vector3(0,0.81+i*0.06,2.75),Vector3(1.7,0.025,0.14),DARK)
	b.cube(hull,Vector3(-0.96,1.93,1.0),Vector3(0.07,0.065,1.55),Color("817452"))
	b.cube(hull,Vector3(-0.96,1.95,1.76),Vector3(0.22,0.045,0.34),STEEL)
	# Bow machine gun, with ball mount on sloped glacis.
	b.disk(hull,Vector3(0.66,1.49,-2.04),0.17,0.17,OLIVE,"y")
	b.cube(hull,Vector3(0.66,1.48,-2.35),Vector3(0.055,0.055,0.57),DARK)
	# Commander vision cupola and separate loader's hatch.
	b.disk(turret,Vector3(-0.43,0.75,0.45),0.36,0.10,DARK,"y")
	b.disk(turret,Vector3(-0.43,0.84,0.45),0.33,0.18,OLIVE,"y")
	for i in 6:
		var a := i*TAU/6
		b.cube(turret,Vector3(-0.43+cos(a)*0.32,0.85,0.45+sin(a)*0.32),Vector3(0.12,0.07,0.09),DARK,Vector3(0,-a,0))
	b.disk(turret,Vector3(-0.43,0.97,0.45),0.35,0.055,EDGE,"y")
	b.disk(turret,Vector3(0.42,0.73,0.21),0.29,0.055,DARK,"y")
	b.disk(turret,Vector3(0.42,0.77,0.21),0.26,0.065,OLIVE,"y")
	for x in [-0.43,0.42]: b.cube(turret,Vector3(x,1.02 if x < 0 else 0.82,0.35),Vector3(0.16,0.04,0.055),DARK)
	b.cube(turret,Vector3(0.67,1.01,0.73),Vector3(0.055,0.48,0.055),DARK)
	b.cube(turret,Vector3(0.67,1.24,0.6),Vector3(0.14,0.12,0.45),STEEL)
	b.cube(turret,Vector3(0.67,1.24,0.15),Vector3(0.05,0.05,0.6),DARK)
	b.cube(turret,Vector3(-0.68,1.10,0.85),Vector3(0.024,0.8,0.024),DARK)
	# Mantlet is stepped in depth around the barrel, retaining the characteristic wide shield.
	for i in 7:
		var y := (i-3)*0.08
		b.cube(gun,Vector3(0,y,-0.10-0.09*(1-absf(i-3)/3)),Vector3(1.05-absf(i-3)*0.055,0.08,0.25),OLIVE)
	var recoil := Node3D.new()
	recoil.name = "RecoilVisual"
	gun.add_child(recoil)
	for i in 30:
		var radius := 0.115-i*0.0014
		b.cube(recoil,Vector3(0,0,-0.25-i*0.073),Vector3(radius*2,radius*2,0.08),STEEL)
	# Muzzle hole: four walls with a recessed dark bore, no muzzle brake on this 75-mm silhouette.
	for side in [-1,1]:
		b.cube(recoil,Vector3(side*0.065,0,-2.44),Vector3(0.025,0.155,0.05),EDGE)
		b.cube(recoil,Vector3(0,side*0.065,-2.44),Vector3(0.105,0.025,0.05),EDGE)
	b.cube(recoil,Vector3(0,0,-2.415),Vector3(0.1,0.1,0.01),Color("111811"))
	b.finish(layer)
	M4TrackMotion.new().build(hull,layer)
