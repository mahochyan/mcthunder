class_name M4EngineeringProfile
extends RefCounted
## M4A3(75)W VVSS silhouette study: TM 9-759 figs 3, 4, 350.
## Original reconstruction, estimated geometry; armor/module performance remains a training design.
const TURRET_ORIGIN := Vector3(0,1.85,-0.30)
const GUN_ORIGIN := Vector3(0,0.33,-0.88)

static func layout(recovery: bool = false) -> VehicleLayoutDefinition:
	var out := DamageTrainingLayout.build(recovery)
	out.id = "m4_silhouette_training"
	out.display_name = "M4A3 silhouette engineering vehicle"
	out.armor_patches.clear()
	for part in out.parts:
		if part.id == "turret": part.bind_local.origin = TURRET_ORIGIN
		if part.id == "barrel": part.bind_local.origin = GUN_ORIGIN
	# Each section shares exact vertices between rendered skin and shot query.
	var bottom := [Vector3(-1.04,0.53,-2.45),Vector3(1.04,0.53,-2.45),Vector3(1.04,0.53,2.55),Vector3(-1.04,0.53,2.55)]
	var belt := [Vector3(-1.18,0.98,-2.65),Vector3(1.18,0.98,-2.65),Vector3(1.18,0.98,2.75),Vector3(-1.18,0.98,2.75)]
	var roof := [Vector3(-1.16,1.85,-1.62),Vector3(1.16,1.85,-1.62),Vector3(1.16,1.85,2.42),Vector3(-1.16,1.85,2.42)]
	for i in 4:
		var j := (i+1)%4
		face(out,"hull_lower_%d"%i,"hull",[bottom[i],bottom[j],belt[j],belt[i]],Vector3(0,1.1,0))
		face(out,"hull_front" if i == 0 else "hull_upper_%d"%i,"hull",[belt[i],belt[j],roof[j],roof[i]],Vector3(0,1.1,0))
	face(out,"hull_roof","hull",roof,Vector3(0,1.1,0))
	face(out,"hull_floor","hull",bottom,Vector3(0,1.1,0))
	# Faceted cast turret, narrower roof and distinct rear bustle; no box turret.
	var rings: Array = []
	for level in [[0.03,1.06,1.13],[0.39,1.10,1.14],[0.70,0.88,0.98]]:
		var ring: Array = []
		for i in 16:
			var a := TAU*i/16.0
			ring.append(Vector3(cos(a)*level[1],level[0],sin(a)*level[2]+0.12))
		rings.append(ring)
	for level in 2:
		for i in 16:
			var j := (i+1)%16
			face(out,"turret_%d_%d"%[level,i],"turret",[rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]],Vector3(0,0.35,0.12))
	face(out,"turret_roof","turret",rings[2],Vector3(0,0.35,0.12))
	face(out,"turret_floor","turret",rings[0],Vector3(0,0.35,0.12))
	for m in out.modules:
		match m.id:
			"engine": m.local_box_transform.origin = Vector3(0,1.22,1.45); m.size_m = Vector3(1.25,0.75,1.0)
			"track_left","track_right": m.local_box_transform.origin = Vector3(-1.2 if m.id == "track_left" else 1.2,0.56,0); m.size_m = Vector3(0.43,1.12,5.42)
			"breech": m.local_box_transform.origin = Vector3(0,0.33,-0.40); m.size_m = Vector3(0.44,0.36,0.6)
			"turret_drive": m.local_box_transform.origin = Vector3(0,1.73,-0.3)
			"ammo_rack": m.local_box_transform.origin = Vector3(0.72,1.05,0.55)
			"transmission": m.local_box_transform.origin = Vector3(0,0.85,-2.05)
			"fuel": m.local_box_transform.origin = Vector3(-0.8,1.2,1.85)
	for crew in out.crew_stations:
		if crew.part_id == "hull": crew.local_box_transform.origin = Vector3(crew.local_box_transform.origin.x,1.30,-1.2)
		else: crew.local_box_transform.origin.y += 0.08
	return out

static func face(out: VehicleLayoutDefinition, id: String, part: String, vertices: Array, interior: Vector3) -> void:
	var plane_normal: Vector3 = (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	for vertex in vertices:
		if absf(plane_normal.dot(vertex-vertices[0])) > 0.00001:
			for i in range(1,vertices.size()-1): face(out,id+"_tri%d"%i,part,[vertices[0],vertices[i],vertices[i+1]],interior)
			return
	var p := ArmorPatchDefinition.new()
	p.id = id
	p.part_id = part
	p.plate_group_id = id
	p.vertices_local_m = PackedVector3Array(vertices)
	var normal: Vector3 = (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	if normal.dot(vertices[0]-interior) < 0:
		vertices.reverse()
		p.vertices_local_m = PackedVector3Array(vertices)
		normal = -normal
	p.outward_normal_local = normal
	for i in range(1,vertices.size()-1): p.triangles.append_array(PackedInt32Array([0,i,i+1]))
	p.has_thickness = true
	p.thickness_mm = 240 if id == "hull_front" else 20
	p.geometry_status = "estimated"
	p.thickness_status = "estimated"
	p.material_kind = "cast" if part == "turret" else "rolled"
	out.armor_patches.append(p)

static func apply(actor: VehicleActor) -> void:
	# Per-instance definition prevents a showroom/profile change mutating the legacy fixture.
	actor.definition = actor.definition.duplicate(true)
	actor.definition.drive_collision_size = Vector3(2.85,1.68,5.45)
	actor.definition.drive_collision_center = Vector3(0,0.86,0)
	actor.definition.follow_camera_distance = 9.5
	actor.tank.defs = actor.definition
	actor.turret.defs = actor.definition
	for child in actor.tank.get_children():
		if child.is_in_group("base_vehicle_visual"): child.queue_free()
		if child is CollisionShape3D:
			child.shape = BoxShape3D.new()
			child.shape.size = actor.definition.drive_collision_size
			child.position = actor.definition.drive_collision_center
	for child in actor.turret.get_children():
		if child.is_in_group("base_vehicle_visual"): child.queue_free()
	actor.turret.position = TURRET_ORIGIN
	actor.turret.barrel_pivot.position = GUN_ORIGIN
	actor.turret.barrel_mesh.visible = false
	actor.cam_rig.position.y = 2.15
	actor.label3d.position.y = 3.2
	var profile := layout(actor.state._damage_layout.recovery_enabled)
	actor.set_damage_layout(profile)
	build_skin(actor.tank,actor.turret,profile,actor.tank.visual_layer)
	M4VoxelDetails.build(actor.tank,actor.turret,actor.turret.barrel_pivot,actor.tank.visual_layer)
	actor.turret.recoil_visual = actor.turret.barrel_pivot.get_node("RecoilVisual")
	for child in actor.get_children():
		if child is RecoveryVisuals: child.refresh_materials()

static func build_skin(hull: Node3D, turret: Node3D, profile: VehicleLayoutDefinition, layer: int) -> void:
	for p in profile.armor_patches:
		var mesh := MeshInstance3D.new()
		mesh.name = "Skin_"+p.id
		mesh.mesh = ArmorPatchMesh.build_surface(p.vertices_local_m,p.triangles,p.outward_normal_local)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("65704a") if p.part_id == "hull" else Color("6e7952")
		material.roughness = 0.92
		mesh.material_override = material
		mesh.layers = layer
		(hull if p.part_id == "hull" else turret).add_child(mesh)
