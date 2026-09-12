class_name BoundVehicleModel
extends RefCounted
## Explicit asset bindings use the same decoded bytes for checks and installation.
static func check(packet: Dictionary, layout: VehicleLayoutDefinition, source: Dictionary, retain_scene: bool = false) -> Dictionary:
	var binding: Variant=packet.get("model_binding")
	if not binding is Dictionary: return {"ok":false,"errors":["model_binding: required dictionary"]}
	var shape := ModelBindingValidator._shape(binding,str(packet.id))
	if not shape.is_empty(): return {"ok":false,"errors":shape}
	var path: String=binding.model.path
	if not path.begins_with("res://assets/vehicles/") or not ModelBindingValidator._path(path.trim_prefix("res://")):
		return {"ok":false,"errors":["model_binding: canonical project assets/vehicles GLB required"]}
	if source.get("delivery_status")!="delivered" or source.get("provenance")!="authored_asset" or not source.get("resource_version") is String or str(source.get("resource_version","")).strip_edges().is_empty():
		return {"ok":false,"errors":["model_source: independent delivered artifact/version required"]}
	return ModelBindingValidator.check_file(binding,str(packet.id),source,layout,packet.geometry,packet.runtime,retain_scene)

static func install(actor: VehicleActor, packet: Dictionary, layout: VehicleLayoutDefinition, source_record: Dictionary) -> Dictionary:
	var checked := check(packet,layout,source_record,true)
	if not checked.ok: return checked
	var source: Node3D=checked.scene
	var binding: Dictionary=packet.model_binding
	var unit := float(binding.units.meters_per_unit)
	var roots := {}
	for role in ModelBindingValidator.ROLES: roots[role]=source.get_node(NodePath(binding.nodes[role]))
	var hull_pose := _relative_pose(source,roots.hull)
	for role in ["hull","turret","gun","running_left","running_right"]:
		var authored: Node3D=roots[role]
		var clone := authored.duplicate() as Node3D
		# Every articulated subtree is installed once on its actual gameplay frame.
		for other in ["turret","gun","running_left","running_right"]:
			if other==role or not authored.is_ancestor_of(roots[other]): continue
			var nested := clone.get_node_or_null(authored.get_path_to(roots[other]))
			if nested!=null: nested.free()
		clone.transform=Transform3D.IDENTITY
		var parent := DamageTrainingLayout.part_node(actor,"barrel" if role=="gun" else role)
		var container := Node3D.new(); container.name="Bound_"+role
		container.add_to_group("base_vehicle_visual")
		if role in ["running_left","running_right"]:
			var relative := hull_pose.affine_inverse()*_relative_pose(source,authored)
			container.transform=Transform3D(relative.basis*unit,relative.origin*unit)
		else: container.scale=Vector3.ONE*unit
		if role=="gun":
			var recoil := Node3D.new(); recoil.name="RecoilVisual"; recoil.add_to_group("base_vehicle_visual")
			parent.add_child(recoil); parent=recoil; actor.turret.recoil_visual=recoil
		parent.add_child(container); container.add_child(clone)
		HistoricalVehicleModel._set_layers(container,actor.tank.visual_layer)
		container.set_meta("model_sha256",binding.model.sha256)
	source.free()
	checked.erase("scene")
	TrackAssembly.install(actor,layout)
	VehicleArmorLayers.install_bound_visuals(actor,packet,layout)
	return checked

static func _relative_pose(root: Node3D, node: Node3D) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent!=null and parent!=root:
		if parent is Node3D: pose=parent.transform*pose
		parent=parent.get_parent()
	return pose
