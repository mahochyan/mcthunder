class_name VehicleArmorLayers
extends RefCounted
## Finite supplementary sheets in owning part coordinates. Geometry determines order/gaps.
const MAX_LAYERS := 32

static func check(packet: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for zone in packet.armor:
		var row: Variant = packet.armor[zone]
		if not row is Dictionary: continue
		if row.has("reactive_profile"): errors.append("armor."+str(zone)+": ERA requires explicitly bounded armor_layers tiles")
		var material := str(row.get("material","rolled"))
		if material not in LayoutValidator.MATERIAL_KINDS: errors.append("armor."+str(zone)+": unsupported material")
		errors.append_array(ArmorLayerProfile.validate(row.get("response_profile",{}),material))
		if row.has("response_profile") or material == "composite":
			errors.append_array(_claim(packet,"protection.zone."+str(zone),{"material":material,"response_profile":row.get("response_profile",{})}))
	if not packet.has("armor_layers"): return errors
	var layers: Variant = packet.armor_layers
	if not layers is Array or layers.is_empty() or layers.size() > MAX_LAYERS: return errors + ["armor_layers: bounded nonempty array required"]
	var ids := {}
	for row in layers:
		if not row is Dictionary: errors.append("armor_layers: malformed layer"); continue
		var path := "armor_layers."+str(row.get("id","?"))
		for key in row:
			if key not in ["id","part","vertices_m","normal","thickness_mm","material","response_profile","reactive_profile","reason"]: errors.append(path+": unsupported field "+str(key))
		if not row.get("id") is String or not str(row.get("id","")).is_valid_identifier() or str(row.get("id","")).length()>128 or ids.has(row.get("id")): errors.append(path+": unique bounded identifier required")
		else: ids[row.id]=true
		if row.get("part") not in ["hull","turret","barrel"]: errors.append(path+": known articulated part required")
		if not row.get("reason") is String or str(row.get("reason","")).strip_edges().is_empty(): errors.append(path+": layer geometry explanation required")
		if not VehicleContentPipeline.number(row.get("thickness_mm")) or float(row.thickness_mm)<=0 or float(row.thickness_mm)>2000: errors.append(path+": explicit positive physical thickness required")
		if row.get("material") not in ["rolled","cast","composite"]: errors.append(path+": known material required")
		errors.append_array(ArmorLayerProfile.validate(row.get("response_profile",{}),str(row.get("material","unknown"))))
		errors.append_array(ReactiveArmorProfile.validate(row.get("reactive_profile",{})))
		var valid_points: bool = row.get("vertices_m") is Array and row.vertices_m.size()==4 and VehicleContentPipeline.vector(row.get("normal"),3)
		if valid_points:
			for point in row.vertices_m:
				if not VehicleContentPipeline.vector(point,3): valid_points=false
		if not valid_points: errors.append(path+": four local metre vertices and unit normal required"); continue
		var points := PackedVector3Array()
		for point in row.vertices_m: points.append(HistoricalVehicleGeometry.vec(point))
		var normal := HistoricalVehicleGeometry.vec(row.normal)
		errors.append_array(ArmorPatchMesh.validate_geometry(points,PackedInt32Array([0,1,2,0,2,3]),normal))
		for index in 4:
			if (points[(index+1)%4]-points[index]).cross(points[(index+2)%4]-points[(index+1)%4]).dot(normal)<=0: errors.append(path+": convex ordered quad required")
		errors.append_array(_claim(packet,"protection.layer."+str(row.get("id","?")),row))
	return errors

static func _claim(packet: Dictionary, key: String, actual: Dictionary) -> Array[String]:
	if packet.get("evidence_profile") != "game_reference": return [key+": explicit game-reference admission required"]
	var claim: Variant = packet.facts.get(key)
	var errors := ReferenceEvidenceGate.check_claim(key,claim,packet,"structured")
	if not claim is Dictionary: return errors
	if claim.get("origin") != "game_rule" or claim.get("status") != "estimated" or claim.get("value") != actual: errors.append(key+": exact independently registered design value required")
	return errors

static func append_to(layout: VehicleLayoutDefinition, packet: Dictionary) -> void:
	for row in packet.get("armor_layers",[]):
		var patch := ArmorPatchDefinition.new()
		patch.id=row.id; patch.part_id=row.part; patch.plate_group_id=row.id
		for point in row.vertices_m: patch.vertices_local_m.append(HistoricalVehicleGeometry.vec(point))
		patch.triangles=PackedInt32Array([0,1,2,0,2,3]); patch.outward_normal_local=HistoricalVehicleGeometry.vec(row.normal)
		patch.has_thickness=true; patch.thickness_mm=row.thickness_mm; patch.thickness_status="estimated"; patch.geometry_status="estimated"
		patch.material_kind=row.material; patch.response_profile=row.get("response_profile",{}).duplicate(true)
		patch.reactive_profile=row.get("reactive_profile",{}).duplicate(true)
		patch.evidence_keys=PackedStringArray(["protection.layer."+str(row.id)])
		layout.armor_patches.append(patch)
		layout.declared_openings.append({"id":str(row.id)+"_perimeter","part":row.part,"boundary_loop":Array(patch.vertices_local_m),"reason":row.reason})

static func install_bound_visuals(actor: VehicleActor, packet: Dictionary, layout: VehicleLayoutDefinition, reactive_only: bool = false) -> void:
	# Supplementary sheets are explicitly authored gameplay geometry, visible even with a GLB skin.
	# Legacy VehicleAtlas already renders every patch; call this only for the bound-model path.
	var ids := {}
	for row in packet.get("armor_layers",[]): ids[str(row.id)]=true
	for patch in layout.armor_patches:
		if not ids.has(patch.id) or (reactive_only and patch.reactive_profile.is_empty()): continue
		var mesh := MeshInstance3D.new(); mesh.name="Protection_"+patch.id
		mesh.mesh=ArmorPatchMesh.build_surface(patch.vertices_local_m,patch.triangles,patch.outward_normal_local)
		var material := StandardMaterial3D.new(); material.albedo_color=Color(0.34,0.39,0.25); material.roughness=0.9; material.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.material_override=material; mesh.layers=actor.tank.visual_layer
		mesh.add_to_group("base_vehicle_visual"); mesh.set_meta("gameplay_patch_ids",[patch.id])
		DamageTrainingLayout.part_node(actor,patch.part_id).add_child(mesh)

static func refresh_reactive_visuals(actor: VehicleActor) -> void:
	for id in actor.state.reactive_armor:
		for part in ["hull","turret","barrel"]:
			var parent := DamageTrainingLayout.part_node(actor,part)
			if parent==null: continue
			var mesh := parent.get_node_or_null("Protection_"+str(id)) as MeshInstance3D
			if mesh!=null and mesh.material_override is StandardMaterial3D:
				mesh.material_override.albedo_color=Color(0.34,0.39,0.25) if actor.state.reactive_armor[id]==1 else Color(0.14,0.13,0.12)
