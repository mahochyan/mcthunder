class_name M4LowPolyDetails
extends RefCounted
## Low-poly mechanical fittings. Circular parts use faceted cylinders; plates retain planar geometry.
const OLIVE := Color("626d49")
const EDGE := Color("87906b")
const DARK := Color("30372c")
const RUBBER := Color("252a25")
const STEEL := Color("555c50")
var groups: Dictionary = {}

func cube(parent: Node3D, p: Vector3, s: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	instance(parent,Transform3D(Basis.from_euler(rotation)*Basis.from_scale(s),p),color,"plate")

func instance(parent: Node3D, pose: Transform3D, color: Color, kind: String) -> void:
	var key := str(parent.get_instance_id())+color.to_html()+kind
	if not groups.has(key): groups[key] = {"parent":parent,"color":color,"kind":kind,"transforms":[]}
	groups[key].transforms.append(pose)

func disk(parent: Node3D, p: Vector3, radius: float, width: float, color: Color, axis: String = "x") -> void:
	var rotation := Basis(Vector3.FORWARD,PI/2) if axis == "x" else Basis.IDENTITY
	instance(parent,Transform3D(rotation*Basis.from_scale(Vector3(radius,width,radius)),p),color,"cylinder")

static func flat_mesh(source: PrimitiveMesh) -> ArrayMesh:
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0,indices.size(),3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		var normal := -(b-a).cross(c-a).normalized() # Godot rendering uses clockwise faces.
		points.append_array(PackedVector3Array([a,b,c]))
		normals.append_array(PackedVector3Array([normal,normal,normal]))
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = points
	result[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result)
	return mesh

func finish(layer: int) -> void:
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1
	cylinder.bottom_radius = 1
	cylinder.height = 1
	cylinder.radial_segments = 16
	cylinder.rings = 1
	var unit_cylinder := flat_mesh(cylinder)
	for group in groups.values():
		var mesh: Mesh = unit_cylinder if group.kind == "cylinder" else unit_box
		var material := StandardMaterial3D.new()
		material.albedo_color = group.color
		material.roughness = 0.9
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = group.transforms.size()
		for i in instances.instance_count: instances.set_instance_transform(i,group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Cosmetic_LowPolyDetails"
		node.multimesh = instances
		node.layers = layer
		node.material_override = material
		group.parent.add_child(node)

static func build(hull: Node3D, turret: Node3D, gun: Node3D, layer: int) -> void:
	var b := M4LowPolyDetails.new()
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
	var tube := CylinderMesh.new()
	tube.top_radius = 0.115
	tube.bottom_radius = 0.075
	tube.height = 2.2
	tube.radial_segments = 16
	tube.rings = 1
	tube.cap_bottom = false
	tube.cap_top = false
	var tube_mesh := MeshInstance3D.new()
	tube_mesh.name = "Cosmetic_TaperedBarrel"
	tube_mesh.mesh = flat_mesh(tube)
	tube_mesh.rotation.x = PI/2
	tube_mesh.position.z = -1.35
	tube_mesh.layers = layer
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_color = STEEL
	gun_material.roughness = 0.86
	tube_mesh.material_override = gun_material
	recoil.add_child(tube_mesh)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.039
	lip.outer_radius = 0.075
	lip.rings = 16
	lip.ring_segments = 4
	var lip_mesh := MeshInstance3D.new()
	lip_mesh.name = "Cosmetic_MuzzleLip"
	lip_mesh.mesh = flat_mesh(lip)
	lip_mesh.rotation.x = PI/2
	lip_mesh.position.z = -2.445
	lip_mesh.layers = layer
	lip_mesh.material_override = gun_material
	recoil.add_child(lip_mesh)
	# Recessed bore, kept behind the open muzzle ring.
	var bore := Node3D.new()
	bore.rotation.x = PI/2
	bore.position.z = -2.41
	recoil.add_child(bore)
	b.disk(bore,Vector3.ZERO,0.045,0.01,Color("111811"),"y")
	b.finish(layer)
	M4TrackMotion.new().build(hull,layer)
