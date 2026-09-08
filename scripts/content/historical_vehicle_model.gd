class_name HistoricalVehicleModel
extends RefCounted
## Common reconstruction: rendered armor and shot-query armor share the same layout vertices.
static func apply(actor: VehicleActor, packet: Dictionary, layout: VehicleLayoutDefinition) -> void:
	for parent in [actor.tank,actor.turret]:
		for child in parent.get_children():
			if child.is_in_group("base_vehicle_visual"): child.queue_free()
	for child in actor.tank.get_children():
		if child is CollisionShape3D:
			child.shape = BoxShape3D.new(); child.shape.size = actor.definition.drive_collision_size
			child.position = actor.definition.drive_collision_center
	var g: Dictionary = packet.geometry
	actor.turret.position = HistoricalVehicleGeometry.vec(g.turret_origin)
	actor.turret.barrel_pivot.position = HistoricalVehicleGeometry.vec(g.gun_origin)
	actor.turret.barrel_mesh.visible = false
	actor.turret.muzzle.position = Vector3(0,0,-float(g.barrel_length))
	actor.turret._flash.position = actor.turret.muzzle.position-Vector3(0,0,0.05)
	actor.cam_rig.position.y = float(g.turret_origin[1])+0.3
	actor.label3d.position.y = float(g.turret_origin[1])+float(g.turret_top)+0.5
	for patch in layout.armor_patches:
		var mesh := MeshInstance3D.new(); mesh.name = "Skin_"+patch.id
		mesh.mesh = ArmorPatchMesh.build_surface(patch.vertices_local_m,patch.triangles,patch.outward_normal_local)
		var material := StandardMaterial3D.new()
		material.albedo_color = M4LowPolyDetails.OLIVE; material.roughness = 0.92
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material; mesh.layers = actor.tank.visual_layer
		DamageTrainingLayout.part_node(actor,patch.part_id).add_child(mesh)
	build_details(actor.tank,actor.turret,actor.turret.barrel_pivot,packet,actor.tank.visual_layer)
	actor.turret.recoil_visual = actor.turret.barrel_pivot.get_node("RecoilVisual")

static func build_details(hull: Node3D, turret: Node3D, gun: Node3D, packet: Dictionary, layer: int) -> void:
	var path := "res://assets/vehicles/"+str(packet.id)+".glb"
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("HistoricalVehicleModel: missing Blender asset "+path)
		return
	var source := scene.instantiate() as Node3D
	for part in ["hull","turret","barrel"]:
		var parent: Node3D = hull if part == "hull" else (turret if part == "turret" else gun)
		var authored := source if source.name == part else source.find_child(part,true,false)
		if authored == null:
			push_error("HistoricalVehicleModel: missing authored part "+part)
			continue
		for child in authored.get_children():
			if not child.name.begins_with("Cosmetic") and child.name != "gun_recoil": continue
			var detail := child.duplicate() as Node3D
			if child.name == "gun_recoil": detail.name = "RecoilVisual"
			_set_layers(detail,layer)
			parent.add_child(detail)
	source.free()
	var g: Dictionary = packet.geometry
	var width: float = HistoricalEvidenceGate.value(packet,"dimensions.width_m")
	var length: float = HistoricalEvidenceGate.value(packet,"dimensions.reference_length_m")
	var tracks := M4TrackMotion.new()
	tracks.build(hull,layer,{"center_x":width*0.5-float(g.track_width)*0.5,"width":float(g.track_width),"straight":length*0.804})

static func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D: node.layers = layer
	for child in node.get_children(): _set_layers(child,layer)
