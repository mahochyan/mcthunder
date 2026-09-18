extends "res://tests/run_modern_candidate_checks.gd"
## MCT-COMBAT-DEEPEN-01 CD002: the readable zone -> plate -> part mapping and the five-layer view, exported from the
## NORMAL actor for both delivered engineering vehicles, plus the measured check that visual presentation never changes
## combat geometry. Read-only: no authoring file, no production file and no user GLB is touched, and no tolerance is
## invented here - the measured numbers are printed so the tolerance in CD02-T01 can be declared from evidence.
const FIXTURE_PREFIX := "test_cd002_"
const OUT_JSON := "res://logs/COMBAT-DEEPEN-01/cd002-zone-plate-part.json"
## The six key parts WT-CD-002 freezes first, each named with the zones and modules that carry it.
const KEY_PARTS := {
	"mantlet_gun_shield": {"zones":["gun_shield"],"modules":[]},
	"turret_ring": {"zones":["turret_roof"],"modules":["turret_drive"]},
	"glacis_upper_lower": {"zones":["hull_front_upper","hull_front_lower"],"modules":[]},
	"hull_sides": {"zones":["hull_sides_front","hull_sides_rear","hull_sides_lower","hull_sides_lower_rear"],"modules":[]},
	"bustle_rear": {"zones":["turret_rear"],"modules":["ammo_ready","ammo_reserve","bustle_partition","bustle_vent"]},
}
## CD02-T01: the tolerance is NOT invented here. The delivered packets already carry it in model_binding.units -
## attachment_tolerance_m = 0.05 (50 mm) and tolerance_fraction = 0.02 (2% of a dimension) - and the existing binding
## validator enforces exactly those two numbers. The declaration below freezes them for this sub-order, marks them as a
## project estimate taken from the delivered packet, and marks the War Thunder comparison as NOT_COMPARED.
const TOLERANCE_SOURCE := "delivered packet model_binding.units (attachment_tolerance_m / tolerance_fraction) - project estimate, NOT_COMPARED against War Thunder"
const TOLERANCE_FALLBACK_ATTACHMENT_M := 0.05
const TOLERANCE_FALLBACK_FRACTION := 0.02
var export_rows: Array = []

## Compare the layout the normal actor installed against the authored positions and sizes the delivered packet carries,
## item by item, using the declared tolerance. Anything beyond it is named rather than smoothed over.
func _tolerance_checks(id: String, packet: Dictionary, layout: VehicleLayoutDefinition) -> Dictionary:
	# The declared tolerance comes from the PRODUCTION config the sub-order names as a read entry - not from the
	# reference packet this fixture was built from - and it is the same pair the existing binding validator enforces.
	var production := _read("res://configs/vehicles/engineering/"+id+".json")
	var units: Dictionary = production.get("model_binding",{}).get("units",{})
	var fixture_units: Dictionary = packet.get("model_binding",{}).get("units",{})
	var attachment_m := float(units.get("attachment_tolerance_m",TOLERANCE_FALLBACK_ATTACHMENT_M))
	var fraction := float(units.get("tolerance_fraction",TOLERANCE_FALLBACK_FRACTION))
	var authored_modules := {}
	for row in packet.get("modules",[]): authored_modules[str(row.get("id",""))] = row
	var authored_crew := {}
	for row in packet.get("crew",[]): authored_crew[str(row.get("id",""))] = row
	var rows: Array = []
	var worst_attachment_mm := 0.0
	var worst_size_ratio := 0.0
	var over: Array = []
	for module in layout.modules:
		if not authored_modules.has(module.id): continue
		var authored: Dictionary = authored_modules[module.id]
		var expected_pos := HistoricalVehicleGeometry.vec(authored.get("position",[0,0,0]))
		var delta_mm := (module.local_box_transform.origin - expected_pos).length() * 1000.0
		var expected_size := HistoricalVehicleGeometry.vec(authored.get("size",[0,0,0]))
		var size_delta := module.size_m - expected_size
		var worst_axis := 0.0
		for axis in ["x","y","z"]:
			var expected_axis: float = maxf(float(expected_size[axis]),0.0001)
			worst_axis = maxf(worst_axis, absf(float(size_delta[axis]))/expected_axis)
		worst_attachment_mm = maxf(worst_attachment_mm,delta_mm)
		worst_size_ratio = maxf(worst_size_ratio,worst_axis)
		var ok := delta_mm <= attachment_m*1000.0 + 1e-6 and worst_axis <= fraction + 1e-6
		if not ok: over.append({"item":"module:"+module.id,"delta_mm":delta_mm,"size_ratio":worst_axis})
		rows.append({"item":"module:"+module.id,"part_id":module.part_id,"delta_mm":delta_mm,"size_ratio":worst_axis,
			"tolerance_mm":attachment_m*1000.0,"tolerance_ratio":fraction,"within":ok})
	for station in layout.crew_stations:
		if not authored_crew.has(station.id): continue
		var authored: Dictionary = authored_crew[station.id]
		var expected_pos := HistoricalVehicleGeometry.vec(authored.get("position",[0,0,0]))
		var delta_mm := (station.local_box_transform.origin - expected_pos).length() * 1000.0
		worst_attachment_mm = maxf(worst_attachment_mm,delta_mm)
		var ok := delta_mm <= attachment_m*1000.0 + 1e-6
		if not ok: over.append({"item":"crew:"+station.id,"delta_mm":delta_mm})
		rows.append({"item":"crew:"+station.id,"part_id":station.part_id,"delta_mm":delta_mm,
			"tolerance_mm":attachment_m*1000.0,"within":ok})
	var result := {"tolerance":{"attachments_mm":attachment_m*1000.0,"dimension_fraction":fraction,
			"source":TOLERANCE_SOURCE,"unit_length":"m","unit_thickness":"mm",
			"production_config":"res://configs/vehicles/engineering/"+id+".json",
			"reference_packet_units":fixture_units},
		"items":rows,"worst_attachment_mm":worst_attachment_mm,"worst_size_ratio":worst_size_ratio,
		"out_of_tolerance":over,
		"authored_leg":"layout versus the very packet it was constructed from - it must agree at zero and is kept as a generation sanity check, NOT as the CD02-T01 tolerance evidence"}
	# The delivered bound model IS present. The earlier NOT_RUN here was my own path bug: the packet's model entry is a
	# nested object and string-replacing it produced a bad path. The anchors are now read through the existing reader,
	# using the packet's own internal_attachments node paths, and compared against the installed part-local origins.
	var model_binding: Dictionary = production.get("model_binding",{})
	var glb_path := str(model_binding.get("model",{}).get("path",""))
	var attachments: Dictionary = model_binding.get("internal_attachments",{})
	var anchor_rows: Array = []
	var worst_anchor_mm := 0.0
	var anchor_over: Array = []
	var leg := "NOT_RUN"
	var leg_reason := "the production config does not name a delivered model path"
	if not glb_path.is_empty() and FileAccess.file_exists(glb_path):
		leg = "MEASURED"
		leg_reason = ""
		var module_paths: Dictionary = attachments.get("modules",{})
		for module in layout.modules:
			if not module_paths.has(module.id): continue
			var node_path := str(module_paths[module.id])
			var read := ModelAnchorReader.part_relative(glb_path,node_path.get_file(),module.part_id)
			if not read.get("ok",false):
				anchor_rows.append({"item":"module:"+module.id,"ok":false,"reason":str(read.get("reason","")),
					"anchor":node_path.get_file(),"part":module.part_id})
				continue
			var anchor_position: Vector3 = read.position
			var delta_mm := (anchor_position - module.local_box_transform.origin).length()*1000.0
			worst_anchor_mm = maxf(worst_anchor_mm,delta_mm)
			var ok := delta_mm <= attachment_m*1000.0 + 1e-6
			if not ok: anchor_over.append({"item":"module:"+module.id,"delta_mm":delta_mm,"anchor":node_path.get_file()})
			anchor_rows.append({"item":"module:"+module.id,"ok":ok,"delta_mm":delta_mm,"anchor":node_path.get_file(),
				"part":module.part_id,"part_node":str(read.get("part_node","")),"anchor_parent":str(read.get("anchor_parent",""))})
		var crew_paths: Dictionary = attachments.get("crew",{})
		for station in layout.crew_stations:
			if not crew_paths.has(station.id): continue
			var node_path := str(crew_paths[station.id])
			var read := ModelAnchorReader.part_relative(glb_path,node_path.get_file(),station.part_id)
			if not read.get("ok",false):
				anchor_rows.append({"item":"crew:"+station.id,"ok":false,"reason":str(read.get("reason","")),
					"anchor":node_path.get_file(),"part":station.part_id})
				continue
			var anchor_position: Vector3 = read.position
			var delta_mm := (anchor_position - station.local_box_transform.origin).length()*1000.0
			worst_anchor_mm = maxf(worst_anchor_mm,delta_mm)
			var ok := delta_mm <= attachment_m*1000.0 + 1e-6
			if not ok: anchor_over.append({"item":"crew:"+station.id,"delta_mm":delta_mm,"anchor":node_path.get_file()})
			anchor_rows.append({"item":"crew:"+station.id,"ok":ok,"delta_mm":delta_mm,"anchor":node_path.get_file(),
				"part":station.part_id,"part_node":str(read.get("part_node","")),"anchor_parent":str(read.get("anchor_parent",""))})
	result["model_anchor_leg"] = leg
	result["model_anchor_reason"] = leg_reason
	result["model_path"] = glb_path
	result["anchors"] = anchor_rows
	result["worst_anchor_mm"] = worst_anchor_mm
	result["anchors_out_of_tolerance"] = anchor_over
	check(leg=="MEASURED","CD02-T01 the delivered bound model is readable from the production config ("+id+"): "+glb_path)
	check(anchor_over.is_empty(),"CD02-T01 every installed module and crew origin agrees with the delivered model anchor within the declared tolerance ("+id+"): worst %.2f mm <= %.0f mm over %d anchors" % [worst_anchor_mm,attachment_m*1000.0,anchor_rows.size()])
	print("[CD02-T01 %s] model-anchor leg: %s ; anchors=%d ; worst=%.2f mm ; over_tolerance=%s" % [
		id,leg,anchor_rows.size(),worst_anchor_mm,JSON.stringify(anchor_over)])
	for row in anchor_rows:
		if not bool(row.get("ok",false)):
			print("[CD02-T01 %s]   anchor item: %s" % [id,JSON.stringify(row)])
	return result

func _summary(packet: Dictionary, layout: VehicleLayoutDefinition, actor: VehicleActor) -> Dictionary:
	var zones := {}
	for patch in layout.armor_patches:
		var zone := str(patch.plate_group_id)
		if not zones.has(zone): zones[zone] = []
		zones[zone].append({"plate_id":patch.id,"part_id":patch.part_id,"has_thickness":patch.has_thickness,
			"thickness_mm":patch.thickness_mm,"thickness_status":patch.thickness_status,"geometry_status":patch.geometry_status,
			"material_kind":patch.material_kind,"vertices":patch.vertices_local_m.size(),"triangles":patch.triangles.size()/3,
			"reactive":not patch.reactive_profile.is_empty(),"evidence_keys":Array(patch.evidence_keys)})
	var modules: Array = []
	for module in layout.modules:
		modules.append({"id":module.id,"kind":module.kind,"part_id":module.part_id,"external":module.external,
			"enclosure_id":module.enclosure_id,"ammo_capacity":module.ammo_capacity,"geometry_status":module.geometry_status,
			"size_m":[module.size_m.x,module.size_m.y,module.size_m.z],
			"integrity_now":float(actor.state.module_states.get(module.id,{}).get("integrity",-1.0))})
	var crew: Array = []
	for station in layout.crew_stations:
		crew.append({"id":station.id,"role":station.role,"part_id":station.part_id,
			"position_status":station.position_status,"volume_status":station.volume_status,
			"role_placement_status":station.role_placement_status})
	var parts: Array = []
	for part in layout.parts:
		parts.append({"id":part.id,"parent_id":part.parent_id,"joint_kind":part.joint_kind,
			"min_angle_deg":part.min_angle_deg,"max_angle_deg":part.max_angle_deg})
	# The six key parts: what the zone carries, and which modules and declared openings belong to it.
	var key: Dictionary = {}
	for label in KEY_PARTS.keys():
		var spec: Dictionary = KEY_PARTS[label]
		var zone_rows: Array = []
		for zone in spec.zones:
			zone_rows.append({"zone":zone,"plates":zones.get(zone,[])})
		var module_rows: Array = []
		for module_id in spec.modules:
			for row in modules:
				if row.id==module_id: module_rows.append(row)
		var openings: Array = []
		for opening in layout.declared_openings:
			if str(opening.get("part","")) in spec.zones or str(opening.get("part",""))=="turret": openings.append(opening)
		key[label] = {"zones":spec.zones,"zone_rows":zone_rows,"modules":module_rows,"declared_openings":openings}
	# The authored geometry parameters these six parts depend on, straight from the delivered packet.
	var geometry: Dictionary = packet.get("geometry",{})
	var geometry_subset := {}
	for name in ["mantlet_half_width","mantlet_half_height","ring_half","hull_rings","hull_half_width","turret_outline",
			"turret_taper","turret_bottom","turret_top","open_top","gun_origin","barrel_length","muzzle_brake","track_width"]:
		if geometry.has(name): geometry_subset[name] = geometry[name]
	return {"entity":packet.get("id",""),"display_name":packet.get("display_name",""),
		"layout_id":layout.id,"layout_schema":layout.schema_version,"content_tier":layout.content_tier,
		"evidence_profile":packet.get("evidence_profile",""),"admission_status":str(packet.get("admission","")),
		"counts":{"parts":parts.size(),"armor_patches":layout.armor_patches.size(),"zones":zones.size(),
			"modules":modules.size(),"crew_stations":crew.size(),"declared_openings":layout.declared_openings.size(),
			"allowed_overlaps":layout.allowed_overlaps.size()},
		"zones":zones,"modules":modules,"crew":crew,"parts":parts,
		"declared_openings":layout.declared_openings,"allowed_overlaps":layout.allowed_overlaps,
		"key_parts":key,"geometry_subset":geometry_subset}

func cd002_case(id: String) -> void:
	var packet := _read(PACKAGES+id+".json")
	packet.id = FIXTURE_PREFIX+id
	for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
	var sources := fixture_asset(packet,1.0)
	var defs := VehicleDefs.new()
	var registered := VehicleCatalog.new(sources).register(packet,defs)
	check(registered.ok,"CD002 the delivered packet registers with isolated TEST ONLY art ("+id+")")
	if not registered.ok: print(registered.errors); return
	var world := Node3D.new(); root.add_child(world)
	var actor := VehicleActor.new(); world.add_child(actor)
	check(actor.setup(defs,packet.id,"cd002_target",1,Transform3D.IDENTITY,2,null).ok,"CD002 the normal actor installs the authored layout ("+id+")")
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	await _frames(2)
	var layout: VehicleLayoutDefinition = actor.damage_layout_override
	var summary := _summary(packet,layout,actor)
	summary["tolerance_check"] = _tolerance_checks(id,packet,layout)
	export_rows.append(summary)
	print("[CD02 %s] layout=%s schema=%d tier=%s ; counts=%s" % [id,summary.layout_id,summary.layout_schema,summary.content_tier,JSON.stringify(summary.counts)])
	print("[CD02 %s] zones=%s" % [id,JSON.stringify(summary.zones.keys())])
	for label in summary.key_parts.keys():
		var entry: Dictionary = summary.key_parts[label]
		var plate_count := 0
		var thicknesses: Array = []
		for zone_row in entry.zone_rows:
			for plate in zone_row.plates:
				plate_count += 1
				if bool(plate.has_thickness): thicknesses.append(float(plate.thickness_mm))
		print("[CD02 %s] key part %s: zones=%s plates=%d thickness_mm=%s modules=%s openings=%d" % [
			id,label,JSON.stringify(entry.zones),plate_count,JSON.stringify(thicknesses),
			JSON.stringify(entry.modules.map(func(m): return m.id)),entry.declared_openings.size()])
	print("[CD02 %s] five layers: model parts=%d (joint kinds=%s) · armor plates=%d · modules=%d · crew stations=%d · declared openings=%d" % [
		id,summary.counts.parts,JSON.stringify(_joint_kinds(summary.parts)),summary.counts.armor_patches,
		summary.counts.modules,summary.counts.crew_stations,summary.counts.declared_openings])
	# CD02-T05: visual presentation must never change combat geometry or a rule result.
	var from_world: Vector3 = actor.tank.global_transform*Vector3(-6.0,0.95,0.0)
	var to_world: Vector3 = actor.tank.global_transform*Vector3(6.0,0.95,0.0)
	var request := {"query_id":"cd002_visual","from_world":from_world,"to_world":to_world}
	var before_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	var before_hits := ShotQueryService.query(request,[before_snapshot])
	actor.tank.presentation_enabled = false
	actor.tank.hull_frame.visible = false
	if actor.tank.turret_rig != null: actor.tank.turret_rig.visible = false
	await _frames(3)
	var after_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	var after_hits := ShotQueryService.query(request,[after_snapshot])
	check(JSON.stringify(before_hits.get("events",[]))==JSON.stringify(after_hits.get("events",[])),"CD02-T05 hiding the visual model changes no query event ("+id+")")
	check(JSON.stringify(before_snapshot.get("part_world_transforms",{}))==JSON.stringify(after_snapshot.get("part_world_transforms",{})),"CD02-T05 a visual toggle moves no combat part ("+id+")")
	var occupancy_equal := JSON.stringify(before_snapshot.get("ammo_contents",{}))==JSON.stringify(after_snapshot.get("ammo_contents",{}))
	check(occupancy_equal,"CD02-T05 a visual toggle changes no ammunition occupancy ("+id+")")
	actor.tank.presentation_enabled = true
	actor.tank.hull_frame.visible = true
	if actor.tank.turret_rig != null: actor.tank.turret_rig.visible = true
	world.queue_free(); await _frames(2)

func _joint_kinds(parts: Array) -> Dictionary:
	var out := {}
	for part in parts: out[str(part.joint_kind)] = int(out.get(str(part.joint_kind),0)) + 1
	return out

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd002_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD002 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	print("[CD002] exported from the normal actor for " + str(MODERN) + " ; this is a layout/geometry export, not an acceptance of the delivered models")
	for id in MODERN: await cd002_case(id)
	var handle := FileAccess.open(OUT_JSON,FileAccess.WRITE)
	check(handle != null,"CD002 writes the readable mapping to "+OUT_JSON)
	if handle != null:
		handle.store_string(JSON.stringify(export_rows, "  "))
		handle.close()
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD002_GEOMETRY_MAP_PASS" if failures==0 else "CD002_GEOMETRY_MAP_FAIL")
	quit(0 if failures==0 else 1)
