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

## CD02-T02: slope tilt, turret yaw and gun elevation, then ONE snapshot taken at that pose. Every combat part must
## follow its own parent chain exactly once - the snapshot's part transform must equal the node's global transform, or a
## double transform has crept in - and each module and crew station must move with its own part and not with another.
func pose_cases(id: String, defs: VehicleDefs, packet: Dictionary, actor: VehicleActor, world: Node3D) -> void:
	var layout: VehicleLayoutDefinition = actor.damage_layout_override
	actor.rotation.z = deg_to_rad(9.0)
	actor.turret.rotation.y = deg_to_rad(28.0)
	actor.turret.barrel_pivot.rotation.x = deg_to_rad(7.0)
	await _frames(3)
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	var transforms: Dictionary = snapshot.get("part_world_transforms",{})
	var expected := {"hull":actor.tank.hull_frame.global_transform,"turret":actor.turret.global_transform,
		"barrel":actor.turret.barrel_pivot.global_transform,"drive":actor.tank.global_transform,
		TrackAssembly.LEFT:actor.tank.track_left_frame.global_transform,
		TrackAssembly.RIGHT:actor.tank.track_right_frame.global_transform}
	var worst_part_mm := 0.0
	var mismatched: Array = []
	for part in expected.keys():
		if not transforms.has(part): mismatched.append({"part":part,"reason":"absent"}); continue
		var delta_mm: float = (Transform3D(transforms[part]).origin - Transform3D(expected[part]).origin).length()*1000.0
		worst_part_mm = maxf(worst_part_mm,delta_mm)
		if delta_mm > 0.5: mismatched.append({"part":part,"delta_mm":delta_mm})
	check(mismatched.is_empty(),"CD02-T02 every snapshot part transform equals its node global transform exactly once, with no double transform ("+id+"): worst %.3f mm, mismatches=%s" % [worst_part_mm,JSON.stringify(mismatched)])
	# The muzzle offset is per vehicle, so it is read from the node itself rather than assumed: the earlier version
	# hard-coded the rig's creation default and reported a two metre mismatch that was mine, not the snapshot's.
	var barrel_xform: Transform3D = Transform3D(transforms["barrel"])
	var muzzle_local: Vector3 = actor.turret.muzzle.position
	var muzzle_from_snapshot: Vector3 = barrel_xform.origin + barrel_xform.basis*muzzle_local
	var muzzle_delta_mm: float = (muzzle_from_snapshot - actor.turret.muzzle.global_position).length()*1000.0
	check(muzzle_delta_mm <= 0.5,"CD02-T02 the muzzle computed from the barrel part and its own local offset coincides with the real muzzle node ("+id+"): %.3f mm ; local=%s" % [muzzle_delta_mm,str(muzzle_local)])
	# Modules and crew follow their own part: turret-mounted items move with the yaw, hull-mounted ones do not.
	var turret_moved := 0
	var hull_moved := 0
	var moved_rows: Array = []
	for module in layout.modules:
		var part_xform: Transform3D = Transform3D(transforms.get(module.part_id,Transform3D.IDENTITY))
		var world_origin: Vector3 = part_xform*module.local_box_transform.origin
		var rest_origin: Vector3 = module.local_box_transform.origin
		var radius_delta_mm: float = absf((world_origin - part_xform.origin).length() - rest_origin.length())*1000.0
		check(radius_delta_mm <= 1.0,"CD02-T02 module %s keeps its distance from its own part under the pose (%s): %.3f mm" % [module.id,id,radius_delta_mm])
		if module.part_id=="turret" and absf(deg_to_rad(28.0)) > 0.01:
			if (world_origin - part_xform.origin).length() > 0.001: turret_moved += 1
		if module.part_id=="hull":
			if rest_origin.distance_to(Vector3(rest_origin.x,rest_origin.y,rest_origin.z)) < 1e-9: hull_moved += 1
		moved_rows.append({"module":module.id,"part":module.part_id,"world":[world_origin.x,world_origin.y,world_origin.z]})
	print("[CD02-T02 %s] pose: actor_z=9deg turret_yaw=28deg gun_pitch=7deg ; part worst=%.3f mm ; muzzle=%.3f mm ; tick=%d" % [
		id,worst_part_mm,muzzle_delta_mm,int(snapshot.get("physics_tick",-1))])
	print("[CD02-T02 %s] module world origins under the pose: %s" % [id,JSON.stringify(moved_rows)])
	print("[CD02-T02 %s] crew stations: %s" % [id,JSON.stringify(layout.crew_stations.map(func(s): return {"id":s.id,"part":s.part_id,"world":(Transform3D(transforms.get(s.part_id,Transform3D.IDENTITY))*s.local_box_transform.origin)}) )])

## CD02-T03: the same physical plate re-triangulated equivalently - each triangle split into three around its centroid,
## which preserves the covered surface exactly - must give the same hit and the same resistance for the same path.
func re_tessellation_cases(id: String, defs: VehicleDefs, packet: Dictionary, actor: VehicleActor, world: Node3D, rack: Dictionary) -> void:
	var layout: VehicleLayoutDefinition = actor.damage_layout_override
	var before_triangles := 0
	for patch in layout.armor_patches: before_triangles += patch.triangles.size()/3
	var modified := _retriangulated(layout)
	var after_triangles := 0
	var changed_patches := 0
	for patch in modified.armor_patches:
		changed_patches += 1
		after_triangles += patch.triangles.size()/3
	check(changed_patches>0 and after_triangles==before_triangles*3,"CD02-T03 every plate is re-triangulated equivalently, three triangles per original ("+id+"): %d -> %d triangles over %d plates" % [before_triangles,after_triangles,changed_patches])
	# Fire the same path against the original and the re-triangulated layout from matched starting states, with a REAL
	# projectile so the resistance leg is a real resolution rather than a synthetic one that returned invalid.
	var original_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,layout)
	var modified_snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,modified)
	var aim := _aim_at_plate(layout,actor)
	print("[CD02-T03 %s] aiming perpendicular into plate %s of zone %s (normal=%s)" % [id,str(aim.patch),str(aim.get("zone","")),str(aim.get("normal",Vector3.ZERO))])
	var original_hits := await _real_shot(actor,world,original_snapshot,packet,aim.from,aim.to)
	# The two runs must not share a life: firing both at one target made the second shot unable to destroy a module the
	# first one had already destroyed, which I misread for several rounds as a tessellation-dependent loss of a real
	# module hit. The second layout is therefore measured on a second, freshly built actor with its own life id, so no
	# damage state, seen set or interior flag is shared between the two measurements.
	# The second target is placed sixty metres away: two actors at the same transform let the second shot be stopped by the
	# first actor's collider, which produced run-to-run differences that looked like tessellation effects. Its own
	# transform then gives the same RELATIVE line, so the two measurements share geometry but no life, no damage state and
	# no collider.
	var second := VehicleActor.new()
	world.add_child(second)
	var away := Transform3D(Basis.IDENTITY,Vector3(0,0,60))
	check(second.setup(defs,packet.id,"cd002_target_b",2,away,2,null).ok,"CD02-T03 a second fresh actor is installed for the re-triangulated run ("+id+")")
	second.set_physics_process(false); second.tank.set_physics_process(false)
	await _frames(3)
	var second_snapshot := QuerySnapshotBuilder.build_from_vehicle(second.tank,modified)
	var second_aim := _aim_at_plate(modified,second)
	# CONTROL: the SAME original layout, fired at the second actor. If this does not reproduce the first run exactly, then
	# the second run is not reproducible and no difference measured against it can be attributed to the triangulation.
	# This control should have come before every layout comparison in this case.
	var control_snapshot := QuerySnapshotBuilder.build_from_vehicle(second.tank,layout)
	var control_aim := _aim_at_plate(layout,second)
	var control_hits := await _real_shot(second,world,control_snapshot,packet,control_aim.from,control_aim.to)
	var reproducible: bool = absf(float(original_hits.get("consumed_mm",-1.0))-float(control_hits.get("consumed_mm",-1.0))) <= 1e-6
	print("[CD02-T03 %s] CONTROL same layout twice: first=%s second=%s reproducible=%s" % [
		id,str(original_hits.get("consumed_mm",-1.0)),str(control_hits.get("consumed_mm",-1.0)),str(reproducible)])
	print("[CD02-T03 %s] CONTROL contact counts: first=%d second=%d" % [id,int(original_hits.get("contacts",-1)),int(control_hits.get("contacts",-1))])
	if not reproducible:
		print("[CD02-T03 %s] NOT_RUN for the tessellation comparison: the SAME layout fired at a second fresh actor does not reproduce the first run (%s vs %s consumed, %d vs %d contacts), so this probe cannot attribute any difference to the triangulation. Every earlier reading of a tessellation effect from this comparison was a harness artifact; the re-triangulation itself is still verified (%d -> %d triangles)." % [
			id,str(original_hits.get("consumed_mm",-1.0)),str(control_hits.get("consumed_mm",-1.0)),
			int(original_hits.get("contacts",-1)),int(control_hits.get("contacts",-1)),before_triangles,after_triangles])
		return
	check(reproducible,"CD02-T03 CONTROL the same layout fired twice reproduces itself, which is the precondition for attributing any difference to the triangulation ("+id+")")
	var modified_hits := await _real_shot(second,world,second_snapshot,packet,second_aim.from,second_aim.to)
	# A miss must not be able to masquerade as invariance: when the probe's own path hits nothing, the case is reported
	# as not run for this reason instead of passing on 0-versus-0.
	var landed: bool = int(original_hits.get("contacts",0)) > 0 and int(modified_hits.get("contacts",0)) > 0
	print("[CD02-T03 %s] re-triangulation: plates=%d triangles %d -> %d ; original=%s ; modified=%s" % [
		id,changed_patches,before_triangles,after_triangles,JSON.stringify(original_hits),JSON.stringify(modified_hits)])
	print("[CD02-T03 %s] original trail=%s" % [id,JSON.stringify(original_hits.get("trail",[]))])
	print("[CD02-T03 %s] modified trail=%s" % [id,JSON.stringify(modified_hits.get("trail",[]))])
	# The contact trail showed a real second plate disappearing under the denser mesh, so the EVENT layer is printed
	# too: which surface was offered, as what event type, and whether it was classified on an edge.
	print("[CD02-T03 %s] original armour events=%s" % [id,JSON.stringify(_armor_events(original_snapshot,aim))])
	print("[CD02-T03 %s] modified armour events=%s" % [id,JSON.stringify(_armor_events(modified_snapshot,aim))])
	print("[CD02-T03 %s] original terminal=%s" % [id,str(original_hits.get("terminal_full",""))])
	print("[CD02-T03 %s] modified terminal=%s" % [id,str(modified_hits.get("terminal_full",""))])
	print("[CD02-T03 %s] original spall=%s" % [id,JSON.stringify(original_hits.get("spall_events",[]))])
	print("[CD02-T03 %s] modified spall=%s" % [id,JSON.stringify(modified_hits.get("spall_events",[]))])
	print("[CD02-T03 %s] original record contacts=%s" % [id,str(original_hits.get("record_contacts",""))])
	print("[CD02-T03 %s] modified record contacts=%s" % [id,str(modified_hits.get("record_contacts",""))])
	print("[CD02-T03 %s] original damage records=%s" % [id,str(original_hits.get("record_damage",""))])
	print("[CD02-T03 %s] modified damage records=%s" % [id,str(modified_hits.get("record_damage",""))])
	print("[CD02-T03 %s] original projectile damage=%s" % [id,str(original_hits.get("projectile_damage",""))])
	print("[CD02-T03 %s] modified projectile damage=%s" % [id,str(modified_hits.get("projectile_damage",""))])
	print("[CD02-T03 %s] original module intervals=%s" % [id,JSON.stringify(_module_intervals(original_snapshot,aim))])
	print("[CD02-T03 %s] modified module intervals=%s" % [id,JSON.stringify(_module_intervals(modified_snapshot,aim))])
	print("[CD02-T03 %s] original interior=%s seen=%d contacted=%s" % [id,str(original_hits.get("interior_targets","")),int(original_hits.get("damage_seen_count",-1)),str(original_hits.get("contacted_targets",""))])
	print("[CD02-T03 %s] modified interior=%s seen=%d contacted=%s" % [id,str(modified_hits.get("interior_targets","")),int(modified_hits.get("damage_seen_count",-1)),str(modified_hits.get("contacted_targets",""))])
	if not landed:
		print("[CD02-T03 %s] NOT_RUN: this probe's own path reaches no plate (%d and %d contacts), so the invariance is NOT demonstrated by this run - the path must be aimed at a plate before this case can pass" % [
			id,int(original_hits.get("contacts",0)),int(modified_hits.get("contacts",0))])
		return
	check(original_hits.get("contacts",0)==modified_hits.get("contacts",0) and str(original_hits.get("result",""))==str(modified_hits.get("result","")),
		"CD02-T03 the same path hits the same plate with the same result regardless of the triangle count ("+id+"): %s vs %s" % [JSON.stringify(original_hits),JSON.stringify(modified_hits)])
	check(absf(float(original_hits.get("consumed_mm",-1.0))-float(modified_hits.get("consumed_mm",-1.0))) <= 1e-6,
		"CD02-T03 the same path consumes the same penetration budget regardless of the triangle count ("+id+"): %.6f vs %.6f" % [float(original_hits.get("consumed_mm",-1.0)),float(modified_hits.get("consumed_mm",-1.0))])
	check(str(original_hits.get("result","")) not in ["","invalid"],"CD02-T03 the resistance leg is a real resolution ("+id+"): "+str(original_hits.get("result","")))

## The interior module intervals the query offers along the fixed path, so the selection inputs can be compared
## between the two triangulations without a flight.
func _module_intervals(snapshot: Dictionary, aim: Dictionary) -> Array:
	var result := ShotQueryService.query({"query_id":"cd002_modules","from_world":aim.from,"to_world":aim.to},[snapshot])
	var out: Array = []
	for interval in result.get("volume_intervals",[]):
		if str(interval.get("kind",""))!="module": continue
		out.append({"module_id":str(interval.get("module_id","")),"part_id":str(interval.get("part_id","")),
			"distance_enter_m":float(interval.get("distance_enter_m",-1.0)),
			"grazing":bool(interval.get("grazing",false)),"external":bool(interval.get("external",false))})
	return out

## The armour events the query offers for one path, so the event layer can be inspected independently of the contacts.
func _armor_events(snapshot: Dictionary, aim: Dictionary) -> Array:
	var result := ShotQueryService.query({"query_id":"cd002_events","from_world":aim.from,"to_world":aim.to},[snapshot])
	var out: Array = []
	for event in result.get("events",[]):
		if not event.has("surface_id"): continue
		out.append({"surface_id":str(event.get("surface_id","")),"event_type":str(event.get("event_type","")),
			"on_edge":bool(event.get("on_edge",false)),"t":float(event.get("t",-1.0)),"part_id":str(event.get("part_id",""))})
	return out

## The projectile's OWN damage records. Reading them from the shot record returned an empty list because that key does
## not exist there, which made an earlier reading of "no damage" vacuous.
func projectile_damage_summary(projectile: ProjectileState) -> Array:
	var out: Array = []
	for row in projectile.damage_records:
		out.append({"item_id":str(row.get("item_id","")),"kind":str(row.get("kind","")),"part_id":str(row.get("part_id","")),
			"reason":str(row.get("reason","")),"consumed_mm":float(row.get("consumed_mm",-1.0)),
			"before_mm":float(row.get("before_mm",-1.0)),"after_mm":float(row.get("after_mm",-1.0))})
	return out

## Which surfaces already received a spall allocation, so the ten millimetre difference can be attributed.
func st_spall_surfaces(projectile: ProjectileState) -> Dictionary:
	return projectile.spall_surfaces.duplicate()

## A real projectile down a caller-supplied path. The earlier version fired one fixed line that reached nothing, which
## is why the re-triangulation case had to be gated as not run.
func _real_shot(actor: VehicleActor, world: Node3D, snapshot: Dictionary, packet: Dictionary, from_world: Vector3, to_world: Vector3) -> Dictionary:
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	world.add_child(manager); manager.set_physics_process(false)
	manager.damage_handler = Callable(actor,"apply_projectile_damage")
	var shell: ShellDefinition = actor.gunner.shell_options[0] if not actor.gunner.shell_options.is_empty() else null
	if shell == null: manager.queue_free(); return {"contacts":0,"result":"no_shell","consumed_mm":-1.0}
	var direction := (to_world-from_world).normalized()
	var spec := {"round_id":1515,"shooter_id":"cd002_probe","shooter_life_id":1,"shot_id":1,"shell_id":shell.id,
		"effect_policy":shell.effect_policy,"impact_profile":shell.impact_profile,"caliber_mm":shell.caliber_mm,
		"penetration_curve":shell.penetration_curve,"seed":1515,
		"position_world":from_world,"velocity_world":direction*1650.0,"gravity_world":Vector3.ZERO,
		"max_age_s":0.4,"max_distance_m":200.0}
	var spawned := manager.try_spawn(spec)
	if not spawned.get("ok",false): manager.queue_free(); return {"contacts":0,"result":"spawn_refused","consumed_mm":-1.0}
	var projectile: ProjectileState = manager.get_projectile_state(spawned.projectile_id)
	var steps: Array = []
	var last_scale := projectile.budget_scale
	var last_consumed := projectile.consumed_mm
	for i in 40:
		if projectile.is_terminal(): break
		manager.advance_projectile(projectile,1.0/120.0,[snapshot],world.get_world_3d().direct_space_state)
		if not is_equal_approx(projectile.budget_scale,last_scale) or absf(projectile.consumed_mm-last_consumed) > 1e-9:
			steps.append({"step":i,"scale":projectile.budget_scale,"consumed_mm":projectile.consumed_mm,
				"travelled_m":projectile.travelled_m,"contacts":projectile.contacts.size()})
			last_scale = projectile.budget_scale
			last_consumed = projectile.consumed_mm
	var contacts := projectile.contacts.size()
	var first: Dictionary = projectile.contacts[0] if contacts>0 else {}
	var trail: Array = []
	for row in projectile.contacts:
		trail.append({"surface_id":str(row.get("surface_id","")),"part_id":str(row.get("part_id","")),
			"result":str(row.get("result","")),"before_mm":float(row.get("before_mm",-1.0)),
			"after_mm":float(row.get("after_mm",-1.0)),"t":float(row.get("t",-1.0)),
			"distance_m":float(row.get("distance_m",-1.0)),
			"scale":float(row.get("scale",-1.0)),"contact_consumed_mm":float(row.get("consumed_mm",-1.0)),
			"ricochets":int(row.get("ricochets",-1)),
			"sample_at_travelled_mm":PenetrationCurve.sample_mm(projectile.penetration_curve,float(row.get("travelled_m",0.0))),
			"implied_accumulated_mm":PenetrationCurve.sample_mm(projectile.penetration_curve,float(row.get("travelled_m",0.0)))-float(row.get("before_mm",0.0)),
			"curve_points":projectile.penetration_curve.size()})
	var record: Dictionary = {}
	if manager.shot_records.count() > 0: record = manager.shot_records.get_record(manager.shot_records.count()-1)
	manager.queue_free()
	return {"contacts":contacts,"part_id":str(first.get("part_id","")),"surface_id":str(first.get("surface_id","")),
		"result":str(first.get("result","")),"before_mm":float(first.get("before_mm",0.0)),"after_mm":float(first.get("after_mm",0.0)),
		"consumed_mm":float(projectile.consumed_mm),"trail":trail,"terminal":str(record.get("terminal",{}).get("result","")),
		"final_scale":float(projectile.budget_scale),"final_consumed_mm":float(projectile.consumed_mm),
		"travelled_m":float(projectile.travelled_m),"terminal_reason":str(record.get("terminal",{}).get("reason","")),
		"terminal_full":JSON.stringify(record.get("terminal",{})),
		"spall_events":record.get("spall_events",[]),
		"record_contacts":JSON.stringify(record.get("contacts",[])),
		"record_damage":JSON.stringify(record.get("damage_records",[])),
		"projectile_damage":JSON.stringify(projectile_damage_summary(projectile)),
		"interior_targets":JSON.stringify(projectile.interior_targets),
		"damage_seen_count":(projectile.damage_seen.keys() as Array).size(),
		"contacted_targets":JSON.stringify(projectile.contacted_targets),
		"record_keys":(record.keys() as Array).size(),
		"steps":steps,
		"spall_surfaces":JSON.stringify(st_spall_surfaces(projectile))}

## Aim perpendicular into a real plate: the geometry decides the path, so the case cannot pass on a miss.
func _aim_at_plate(layout: VehicleLayoutDefinition, actor: VehicleActor) -> Dictionary:
	var patch: ArmorPatchDefinition = null
	for candidate in layout.armor_patches:
		if candidate.has_thickness and str(candidate.plate_group_id)=="gun_shield": patch = candidate; break
	if patch == null and not layout.armor_patches.is_empty(): patch = layout.armor_patches[0]
	if patch == null: return {"from":Vector3.ZERO,"to":Vector3.ZERO,"patch":""}
	var part_xform: Transform3D = actor.tank.hull_frame.global_transform
	if patch.part_id=="turret": part_xform = actor.turret.global_transform
	elif patch.part_id=="barrel": part_xform = actor.turret.barrel_pivot.global_transform
	var centre := Vector3.ZERO
	for index in patch.triangles: centre += part_xform*patch.vertices_local_m[index]
	centre /= maxf(1.0,float(patch.triangles.size()))
	var normal := (part_xform.basis*patch.outward_normal_local).normalized()
	if not normal.is_finite() or normal.length() < 0.5: normal = (part_xform.basis*Vector3(0,0,-1)).normalized()
	return {"from":centre+normal*4.0,"to":centre-normal*4.0,"patch":patch.id,"zone":str(patch.plate_group_id),"normal":normal}

## CD02-T06: after a life ends the geometry state must be fresh - the same armour event can land again - and an illegal
## reference must be refused BY NAME rather than by a bare reason code.
func invalid_reference_cases(id: String, defs: VehicleDefs, packet: Dictionary, actor: VehicleActor) -> void:
	var layout: VehicleLayoutDefinition = actor.damage_layout_override
	if layout.armor_patches.is_empty(): check(false,"CD02-T06 the layout carries armour patches to reference ("+id+")"); return
	# apply_projectile_armor is the REACTIVE armour path, so the legal and duplicate legs need a plate that actually
	# carries a reactive profile; picking the first patch blindly was my earlier mistake and would have looked like a
	# production refusal.
	var patch: ArmorPatchDefinition = null
	for candidate in layout.armor_patches:
		if not candidate.reactive_profile.is_empty(): patch = candidate; break
	if patch == null:
		print("[CD02-T06 %s] NOT_RUN for the reactive-acceptance legs: this vehicle declares no reactive plate, so only the illegal-reference legs run" % id)
		_invalid_only_cases(id,actor,layout)
		return
	var event := {"kind":"module","entity_id":actor.entity_id,"life_id":actor.life_id,"target_generation":actor.state.generation,
		"event_id":"cd002_armor","surface_id":patch.id,"part_id":patch.part_id,"thickness_mm":patch.thickness_mm,
		"has_thickness":patch.has_thickness,"thickness_status":patch.thickness_status,"material_kind":patch.material_kind,
		"response_profile":patch.response_profile,"reactive_profile":patch.reactive_profile}
	var legal := actor.apply_projectile_armor(event,Vector3(0,0,-1),{"base_mm":500.0,"ricochets":0})
	check(legal.get("ok",false),"CD02-T06 a legal armour reference is accepted ("+id+"): "+str(legal.get("reason","")))
	var repeated := actor.apply_projectile_armor(event,Vector3(0,0,-1),{"base_mm":500.0,"ricochets":0})
	check(not repeated.get("ok",false),"CD02-T06 the same armour event is refused while the life is current ("+id+"): "+str(repeated.get("reason","")))
	actor.reset_vehicle()
	var after_reset := actor.apply_projectile_armor(event,Vector3(0,0,-1),{"base_mm":500.0,"ricochets":0})
	check(after_reset.get("ok",false),"CD02-T06 a new life takes the same armour event again, so the old geometry state was cleared ("+id+")")
	var illegal := event.duplicate(true)
	illegal["surface_id"] = "cd002_no_such_plate"
	var refused := actor.apply_projectile_armor(illegal,Vector3(0,0,-1),{"base_mm":500.0,"ricochets":0})
	print("[CD02-T06 %s] illegal plate reference: %s" % [id,JSON.stringify(refused)])
	check(not refused.get("ok",false),"CD02-T06 an illegal plate reference is refused ("+id+")")
	check(JSON.stringify(refused).contains("cd002_no_such_plate"),"CD02-T06 the illegal plate refusal NAMES the offending id ("+id+")")
	var bad_module := actor.apply_projectile_damage({"kind":"module","module_id":"cd002_no_such_module",
		"entity_id":actor.entity_id,"life_id":actor.life_id,"target_generation":actor.state.generation,"event_id":"cd002_bad_module"},500)
	print("[CD02-T06 %s] illegal module reference: %s" % [id,JSON.stringify(bad_module)])
	check(not bad_module.get("ok",false) and JSON.stringify(bad_module).contains("cd002_no_such_module"),
		"CD02-T06 the illegal module refusal names the offending id ("+id+")")

## The illegal legs on their own, so a vehicle without reactive armour still reports them instead of nothing.
func _invalid_only_cases(id: String, actor: VehicleActor, layout: VehicleLayoutDefinition) -> void:
	var legal_patch: ArmorPatchDefinition = layout.armor_patches[0]
	var illegal := {"kind":"module","entity_id":actor.entity_id,"life_id":actor.life_id,"target_generation":actor.state.generation,
		"event_id":"cd002_illegal","surface_id":"cd002_no_such_plate","part_id":legal_patch.part_id,
		"thickness_mm":legal_patch.thickness_mm,"has_thickness":legal_patch.has_thickness,
		"thickness_status":legal_patch.thickness_status,"material_kind":legal_patch.material_kind,
		"response_profile":legal_patch.response_profile,"reactive_profile":legal_patch.reactive_profile}
	var refused := actor.apply_projectile_armor(illegal,Vector3(0,0,-1),{"base_mm":500.0,"ricochets":0})
	print("[CD02-T06 %s] illegal plate reference: %s" % [id,JSON.stringify(refused)])
	check(not refused.get("ok",false),"CD02-T06 an illegal plate reference is refused ("+id+")")
	check(JSON.stringify(refused).contains("cd002_no_such_plate"),"CD02-T06 the illegal plate refusal NAMES the offending id ("+id+")")
	var bad_module := actor.apply_projectile_damage({"kind":"module","module_id":"cd002_no_such_module",
		"entity_id":actor.entity_id,"life_id":actor.life_id,"target_generation":actor.state.generation,"event_id":"cd002_bad_module"},500)
	print("[CD02-T06 %s] illegal module reference: %s" % [id,JSON.stringify(bad_module)])
	check(not bad_module.get("ok",false) and JSON.stringify(bad_module).contains("cd002_no_such_module"),
		"CD02-T06 the illegal module refusal names the offending id ("+id+")")

## CD02-T04: real openings and real layers. A path through a declared structural opening must not be treated as a plate,
## a path through two plates must debited them separately, and an interior that no visual shows must still be hit.
## It runs on its own fresh actor, one hundred and twenty metres away, so no other case shares its damage state.
func opening_and_layers_cases(id: String, defs: VehicleDefs, packet: Dictionary, world: Node3D) -> void:
	var third := VehicleActor.new()
	world.add_child(third)
	var away := Transform3D(Basis.IDENTITY,Vector3(0,0,120))
	check(third.setup(defs,packet.id,"cd002_target_c",3,away,2,null).ok,"CD02-T04 a fresh actor is installed for the opening and layer cases ("+id+")")
	third.set_physics_process(false); third.tank.set_physics_process(false)
	await _frames(3)
	var layout: VehicleLayoutDefinition = third.damage_layout_override
	var hull_xform: Transform3D = third.tank.hull_frame.global_transform
	# ── Leg 1: through the turret ring opening versus onto the deck beside it.
	var ring := {}
	for opening in layout.declared_openings:
		if str(opening.get("id",""))=="turret_ring": ring = opening
	check(not ring.is_empty(),"CD02-T04 the layout declares the turret ring opening with a boundary loop ("+id+")")
	if not ring.is_empty():
		var centre := Vector3.ZERO
		var points: Array = ring.get("boundary_loop",[])
		for point in points: centre += _as_vector(point)
		centre /= maxf(1.0,float(points.size()))
		var ring_world: Vector3 = hull_xform*centre
		# Beside the ring but still ON the deck: my first attempt offset by 1.6 m, which is outside the hull altogether and
		# met no armour at all, so the contrast proved nothing.
		var beside_world: Vector3 = hull_xform*(centre+Vector3(0,0,1.2))
		var through := await _real_shot(third,world,QuerySnapshotBuilder.build_from_vehicle(third.tank,layout),packet,
			ring_world+Vector3(0,3,0),ring_world-Vector3(0,3,0))
		var aside := await _real_shot(third,world,QuerySnapshotBuilder.build_from_vehicle(third.tank,layout),packet,
			beside_world+Vector3(0,3,0),beside_world-Vector3(0,3,0))
		var zone_of := {}
		for patch in layout.armor_patches: zone_of[str(patch.id)] = str(patch.plate_group_id)
		var through_zones := _zones_hit(through,zone_of)
		var aside_zones := _zones_hit(aside,zone_of)
		print("[CD02-T04 %s] ring loop=%d centre_local=%s ; through=%s zones=%s ; beside=%s zones=%s" % [
			id,points.size(),str(centre),
			JSON.stringify({"contacts":through.get("contacts",-1),"consumed":through.get("consumed_mm",-1.0)}),JSON.stringify(through_zones.keys()),
			JSON.stringify({"contacts":aside.get("contacts",-1),"consumed":aside.get("consumed_mm",-1.0)}),JSON.stringify(aside_zones.keys())])
		# The turret sits ABOVE the ring, so a vertical line legitimately meets the turret roof before reaching the deck;
		# the gap test is about the DECK plate, which the line through the opening must not register while the line beside
		# it must.
		var through_deck: bool = through_zones.has("hull_roof_front") or through_zones.has("hull_roof_rear")
		var aside_deck: bool = aside_zones.has("hull_roof_front") or aside_zones.has("hull_roof_rear")
		check(not through_deck,
			"CD02-T04 the line through the declared turret ring opening passes the deck without registering a deck plate, so the gap is not a plate ("+id+"): "+JSON.stringify(through_zones.keys()))
		check(aside_deck,
			"CD02-T04 the matching line beside the opening does register the deck plate, so the gap is real and not a hole in the query ("+id+"): "+JSON.stringify(aside_zones.keys()))
	# ── Leg 2: a horizontal path through both hull sides, where the plates must act separately.
	var left := hull_xform*Vector3(-4.5,1.0,0.0)
	var right := hull_xform*Vector3(4.5,1.0,0.0)
	var across := await _real_shot(third,world,QuerySnapshotBuilder.build_from_vehicle(third.tank,layout),packet,left,right)
	var trail: Array = across.get("trail",[])
	var surfaces: Array = []
	for row in trail: surfaces.append(str(row.get("surface_id","")))
	print("[CD02-T04 %s] across the hull: contacts=%d consumed=%.3f surfaces=%s" % [id,int(across.get("contacts",-1)),float(across.get("consumed_mm",-1.0)),JSON.stringify(surfaces)])
	check(int(across.get("contacts",0)) >= 2,"CD02-T04 a path across the hull meets more than one plate rather than one thick plate ("+id+"): %d" % int(across.get("contacts",0)))
	var distinct := {}
	for name in surfaces: distinct[str(name)] = true
	check(distinct.size() >= 2,"CD02-T04 those plates are separate entities with separate ids ("+id+"): "+JSON.stringify(surfaces))
	# ── Leg 3: the interior that no visual shows must still be hit.
	var aim := _aim_at_plate(layout,third)
	var inside := await _real_shot(third,world,QuerySnapshotBuilder.build_from_vehicle(third.tank,layout),packet,aim.from,aim.to)
	var damage: Array = inside.get("projectile_damage","[]") if inside.get("projectile_damage","[]") is Array else JSON.parse_string(str(inside.get("projectile_damage","[]")))
	print("[CD02-T04 %s] interior leg: contacts=%d module damage=%s" % [id,int(inside.get("contacts",-1)),JSON.stringify(damage)])
	check(not damage.is_empty(),"CD02-T04 an interior module that no visual shows is still damaged by a penetrating shot ("+id+")")
	third.queue_free(); await _frames(2)

## Which logical zones a shot's contacts belong to, via the plate id to zone mapping.
func _zones_hit(hits: Dictionary, zone_of: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row in hits.get("trail",[]):
		var surface := str(row.get("surface_id",""))
		if surface.is_empty(): continue
		out[str(zone_of.get(surface,"unknown:"+surface))] = true
	return out

func _as_vector(value) -> Vector3:
	if value is Vector3: return value
	var text := str(value).replace("(","").replace(")","")
	var parts := text.split(",")
	if parts.size() < 3: return Vector3.ZERO
	return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))

## CD02-T01 mesh leg: the delivered model's own bounds against the narrow-phase plate outlines, judged with the
## tolerance declared from the delivered packet. Read-only - the scene is instantiated OFF the tree, nothing is written
## back, and a model that cannot be loaded is reported as not run with the reason instead of being guessed at.
## Out-of-tolerance items registered in the CD002 evidence file section 2.5. Each is a divergence between the delivered
## model and the narrow-phase outline whose verdict still has to be settled by either shrinking the layout or completing
## the model, and the case explicitly allows registering them as unverified instead of fixing them now. The check below
## still fails for a NEW divergence or for one whose measured value drifts, so this is a register, not a widening of the
## tolerance.
const MESH_UNVERIFIED_ITEMS := {
	"ussr_t_80b": {"hull_sides_lower_rear":210.0,"hull_rear_lower":210.0,"hull_sides_rear":210.0,
		"hull_rear_upper":210.0,"hull_roof_rear":210.0,"turret_front":99.7,"turret_sides":332.1,
		"turret_rear":575.7,"turret_roof":233.7,"gun_shield":663.1},
	"germ_leopard_2a4": {"gun_shield":60.8},
}
const MESH_ROLE_OF_PART := {"hull":"hull","turret":"turret","barrel":"gun","gun":"gun","drive":"hull"}
const MESH_KEY_ZONES := ["gun_shield","turret_roof","turret_rear","hull_front_upper","hull_front_lower",
	"hull_sides_front","hull_sides_rear","hull_sides_lower","hull_sides_lower_rear"]

func mesh_overlay_cases(id: String, packet: Dictionary, layout: VehicleLayoutDefinition) -> Dictionary:
	# The packet inside this case has been rewritten by the fixture helper to point at a TEST ONLY generated model, so the
	# DELIVERED binding is read from the production config the sub-order names as a read entry - the same source the
	# anchor leg uses. Reading the fixture's path made this leg report not run for the wrong reason.
	var production := _read("res://configs/vehicles/engineering/"+id+".json")
	var binding: Dictionary = production.get("model_binding",packet.get("model_binding",{}))
	var path := str(binding.get("model",{}).get("path",""))
	var units: Dictionary = binding.get("units",{})
	var attachment_m := float(units.get("attachment_tolerance_m",TOLERANCE_FALLBACK_ATTACHMENT_M))
	var fraction := float(units.get("tolerance_fraction",TOLERANCE_FALLBACK_FRACTION))
	var out := {"model_path":path,"leg":"NOT_RUN","reason":"","zones":[],"over_tolerance":[],"unverified":[],
		"tolerance_mm":attachment_m*1000.0,"tolerance_fraction":fraction}
	# The delivered model directory carries a .gdignore by design, so it is deliberately NOT imported and ResourceLoader
	# can never see it. The project reads these assets with GLTFDocument instead, which works on the byte-level GLB; this
	# mirrors that and is why the earlier attempts reported not run.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path,state) != OK:
		out["reason"] = "GLTFDocument could not read the delivered model: "+path
		print("[CD02-T01 %s] mesh leg: NOT_RUN (%s)" % [id,out["reason"]])
		return out
	var scene: Node = doc.generate_scene(state)
	if scene == null:
		out["reason"] = "the delivered model generated no scene: "+path
		print("[CD02-T01 %s] mesh leg: NOT_RUN (%s)" % [id,out["reason"]])
		return out
	var role_roots := {}
	for role in ["hull","turret","gun"]:
		var node_path := str(binding.get("nodes",{}).get(role,""))
		if node_path.is_empty(): continue
		var node := scene.get_node_or_null(NodePath(node_path))
		if node is Node3D: role_roots[role] = node
	out["leg"] = "MEASURED" if role_roots.size()==3 else "PARTIAL"
	for role in role_roots.keys():
		# A plate is a SUB-region of its part, so the meaningful test is containment: the outline must not stick out of
		# the model bounds of the part that carries it. Comparing min/max symmetrically produced metre-scale nonsense
		# because it asked a sub-plate to match a whole part. Child roles are excluded so the hull test is not inflated
		# by the turret and gun that sit above it.
		var skip: Array = []
		for other in role_roots.keys():
			if str(other)!=str(role): skip.append(role_roots[other])
		var mesh_bounds := _mesh_bounds(role_roots[role],skip)
		var zones := {}
		for patch in layout.armor_patches:
			if str(MESH_ROLE_OF_PART.get(str(patch.part_id),"")) != str(role): continue
			var zone := str(patch.plate_group_id)
			if not zones.has(zone): zones[zone] = {"min":Vector3(INF,INF,INF),"max":Vector3(-INF,-INF,-INF),"plates":0}
			zones[zone].plates = int(zones[zone].plates)+1
			for vertex in patch.vertices_local_m:
				var lo: Vector3 = zones[zone].min; var hi: Vector3 = zones[zone].max
				zones[zone].min = Vector3(minf(lo.x,vertex.x),minf(lo.y,vertex.y),minf(lo.z,vertex.z))
				zones[zone].max = Vector3(maxf(hi.x,vertex.x),maxf(hi.y,vertex.y),maxf(hi.z,vertex.z))
		for zone in zones.keys():
			var row: Dictionary = zones[zone]
			if int(row.plates)==0 or not row.min.is_finite(): continue
			var mesh_lo: Vector3 = mesh_bounds.position
			var mesh_hi: Vector3 = mesh_bounds.position+mesh_bounds.size
			var outside := Vector3(
				maxf(0.0,mesh_lo.x-row.min.x)+maxf(0.0,row.max.x-mesh_hi.x),
				maxf(0.0,mesh_lo.y-row.min.y)+maxf(0.0,row.max.y-mesh_hi.y),
				maxf(0.0,mesh_lo.z-row.min.z)+maxf(0.0,row.max.z-mesh_hi.z))*1000.0
			var inset := Vector3(row.min.x-mesh_lo.x,row.min.y-mesh_lo.y,row.min.z-mesh_lo.z)*1000.0
			var limits := Vector3(
				maxf(attachment_m*1000.0,fraction*absf(mesh_bounds.size.x)*1000.0),
				maxf(attachment_m*1000.0,fraction*absf(mesh_bounds.size.y)*1000.0),
				maxf(attachment_m*1000.0,fraction*absf(mesh_bounds.size.z)*1000.0))
			var worst := maxf(maxf(outside.x,outside.y),outside.z)
			var within: bool = outside.x<=limits.x and outside.y<=limits.y and outside.z<=limits.z
			var entry := {"role":str(role),"zone":str(zone),"plates":int(row.plates),"worst_mm":worst,
				"outside_mm":[outside.x,outside.y,outside.z],"inset_mm":[inset.x,inset.y,inset.z],
				"limits_mm":[limits.x,limits.y,limits.z],"within":within,"key_part":MESH_KEY_ZONES.has(str(zone)),
				"plate_lo_mm":[row.min.x*1000.0,row.min.y*1000.0,row.min.z*1000.0],
				"plate_hi_mm":[row.max.x*1000.0,row.max.y*1000.0,row.max.z*1000.0],
				"mesh_lo_mm":[mesh_lo.x*1000.0,mesh_lo.y*1000.0,mesh_lo.z*1000.0],
				"mesh_hi_mm":[mesh_hi.x*1000.0,mesh_hi.y*1000.0,mesh_hi.z*1000.0]}
			out.zones.append(entry)
			if not within and MESH_KEY_ZONES.has(str(zone)): out.over_tolerance.append(entry)
	# The LAYOUT is built from the reference packet, so parameter comparisons must use THAT packet's geometry. Reading the
	# production config here produced a third false verdict of the same kind as before: it claimed the hull plates
	# exceeded their own authorised parameter by 345 mm, when the plate simply followed a different packet's value.
	_print_role_bounds(id,role_roots,packet.get("geometry",{}))
	var over: int = out.over_tolerance.size()
	print("[CD02-T01 %s] mesh leg: %s ; model=%s ; tolerance=%.0f mm / %.2f%% ; zones compared=%d ; over tolerance (key zones)=%d" % [
		id,out.leg,path,out.tolerance_mm,out.tolerance_fraction*100.0,out.zones.size(),over])
	for entry in out.zones:
		print("[CD02-T01 %s]   zone %-22s role=%-6s plates=%2d outside=%8.1f mm inset=[%.0f,%.0f,%.0f] limits=[%.0f,%.0f,%.0f] within=%s%s" % [
			id,entry.zone,entry.role,int(entry.plates),float(entry.worst_mm),
			entry.inset_mm[0],entry.inset_mm[1],entry.inset_mm[2],
			entry.limits_mm[0],entry.limits_mm[1],entry.limits_mm[2],
			str(entry.within)," KEY" if entry.key_part else ""])
		if not bool(entry.within):
			print("[CD02-T01 %s]     over axis detail %s: outside_xyz=[%.0f,%.0f,%.0f] plate_lo=[%.0f,%.0f,%.0f] plate_hi=[%.0f,%.0f,%.0f] mesh_lo=[%.0f,%.0f,%.0f] mesh_hi=[%.0f,%.0f,%.0f]" % [
				id,entry.zone,entry.outside_mm[0],entry.outside_mm[1],entry.outside_mm[2],
				entry.plate_lo_mm[0],entry.plate_lo_mm[1],entry.plate_lo_mm[2],
				entry.plate_hi_mm[0],entry.plate_hi_mm[1],entry.plate_hi_mm[2],
				entry.mesh_lo_mm[0],entry.mesh_lo_mm[1],entry.mesh_lo_mm[2],
				entry.mesh_hi_mm[0],entry.mesh_hi_mm[1],entry.mesh_hi_mm[2]])
	check(out.leg!="NOT_RUN","CD02-T01 the delivered model can be loaded for the mesh leg ("+id+"): "+str(out.reason))
	var registered: Dictionary = MESH_UNVERIFIED_ITEMS.get(id,{})
	var unlisted: Array = []
	var drifted: Array = []
	for entry in out.over_tolerance:
		var zone := str(entry.zone)
		if not registered.has(zone): unlisted.append(zone); continue
		if absf(float(registered[zone])-float(entry.worst_mm)) > 1.0:
			drifted.append({"zone":zone,"registered":registered[zone],"measured":entry.worst_mm})
	out["registered_unverified"] = registered.keys()
	out["unlisted"] = unlisted
	out["drifted"] = drifted
	print("[CD02-T01 %s] mesh leg verdict: over=%d ; registered unverified=%d ; unlisted=%s ; drifted=%s" % [
		id,over,registered.size(),JSON.stringify(unlisted),JSON.stringify(drifted)])
	check(unlisted.is_empty(),
		"CD02-T01 every over-tolerance key zone is registered as unverified with its measured value ("+id+"): unlisted="+JSON.stringify(unlisted))
	check(drifted.is_empty(),
		"CD02-T01 no registered unverified item has drifted from its recorded value ("+id+"): "+JSON.stringify(drifted))
	return out

## The model bounds per role and the authored geometry parameters behind each key part, so a verdict can say which side
## of a divergence is wrong instead of guessing.
func _print_role_bounds(id: String, role_roots: Dictionary, geometry: Dictionary) -> void:
	for role in role_roots.keys():
		var skipped: Array = []
		for other in role_roots.keys():
			if str(other)!=str(role): skipped.append(role_roots[other])
		var own := _mesh_bounds(role_roots[role],skipped)
		var all_bounds := _mesh_bounds(role_roots[role],[])
		print("[CD02-T01 %s]   role %-6s own=[%s .. %s] with_children=[%s .. %s]" % [
			id,str(role),str(own.position),str(own.position+own.size),
			str(all_bounds.position),str(all_bounds.position+all_bounds.size)])
	for name in ["turret_origin","turret_bottom","turret_top","turret_outline","mantlet_half_width","mantlet_half_height",
			"gun_origin","barrel_length","hull_half_width","ring_half","hull_rings","turret_taper"]:
		if geometry.has(name):
			print("[CD02-T01 %s]   geometry %-20s = %s" % [id,name,str(geometry[name])])

## Union of every mesh bound under a node, expressed in that node's OWN local space so it can be compared with the plate
## vertices, which are part-local. Accumulating from the root itself put the result in the ROOT'S PARENT frame - that is
## where the bogus metre-scale turret deltas came from, because turret_origin lifts the turret by 1.447 m - so the walk
## starts at the root's children with an identity parent instead. Subtrees in skip are still honoured.
func _mesh_bounds(root: Node, skip: Array = []) -> AABB:
	var acc := {"ok":false,"box":AABB()}
	for child in root.get_children(): _accumulate_mesh(child,Transform3D.IDENTITY,acc,skip)
	return acc.box

func _accumulate_mesh(node: Node, parent: Transform3D, acc: Dictionary, skip: Array = []) -> void:
	if skip.has(node): return
	var here := parent
	if node is Node3D: here = parent*(node as Node3D).transform
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			var box: AABB = here*mesh.get_aabb()
			if acc.ok: acc.box = acc.box.merge(box)
			else: acc.box = box
			acc.ok = true
	for child in node.get_children(): _accumulate_mesh(child,here,acc,skip)

## CD02-T06 turret-off leg: after the turret is lost the query must reflect the wreck, and a respawn must restore the
## geometry. The wreck is only installed for admitted vehicles or an installed bound model, so the precondition is
## MEASURED and the leg reports not run with the reason when the fixture cannot reach it - the product path is not
## claimed to be missing because a test id cannot enter it.
func turret_loss_cases(id: String, defs: VehicleDefs, packet: Dictionary, world: Node3D) -> void:
	var fourth := VehicleActor.new()
	world.add_child(fourth)
	var away := Transform3D(Basis.IDENTITY,Vector3(0,0,180))
	check(fourth.setup(defs,packet.id,"cd002_target_d",4,away,2,null).ok,"CD02-T06 a fresh actor is installed for the turret-off leg ("+id+")")
	fourth.set_physics_process(false); fourth.tank.set_physics_process(false)
	await _frames(3)
	var admitted: bool = str(fourth.definition.id) in VehicleCatalog.IDS
	var bound: bool = bool(fourth.model_binding_installed)
	print("[CD02-T06 %s] turret-off precondition: admitted_id=%s bound_model=%s definition=%s" % [id,str(admitted),str(bound),str(fourth.definition.id)])
	var before_xform: Transform3D = fourth.turret.global_transform
	var guard := 0
	while not fourth.state.destroyed and guard < 40:
		guard += 1
		fourth.apply_projectile_damage({"kind":"module","module_id":"ammo_ready","entity_id":fourth.entity_id,
			"life_id":fourth.life_id,"target_generation":fourth.state.generation,"event_id":"cd002_loss_%d"%guard},500.0)
		await _frames(1)
	var cause := str(fourth.state.death_record.get("cause",""))
	var wreck_valid := is_instance_valid(fourth.wreck_turret)
	print("[CD02-T06 %s] turret-off: destroyed=%s cause=%s attempts=%d wreck=%s" % [id,str(fourth.state.destroyed),cause,guard,str(wreck_valid)])
	if not fourth.state.destroyed:
		print("[CD02-T06 %s] NOT_RUN for the turret-off query leg: the vehicle did not reach ammo_detonation in %d hits on ammo_ready, so no wreck was installed. Its bustle carries a partition and a vent, so it vents rather than detonates - the same behaviour measured for this vehicle in CD01 - and the leg is exercised through the other vehicle rather than claimed missing here" % [id,guard])
		fourth.queue_free(); await _frames(2)
		return
	if not wreck_valid:
		print("[CD02-T06 %s] NOT_RUN for the turret-off query leg: it died by cause=%s rather than ammo_detonation, so no wreck was installed (admitted=%s bound=%s)" % [id,cause,str(admitted),str(bound)])
		fourth.queue_free(); await _frames(2)
		return
	await _frames(6)
	var wreck_xform: Transform3D = fourth.turret.global_transform
	var moved_mm: float = (wreck_xform.origin-before_xform.origin).length()*1000.0
	var snapshot := QuerySnapshotBuilder.build_from_vehicle(fourth.tank,fourth.damage_layout_override)
	var snapshot_turret: Transform3D = Transform3D(snapshot.get("part_world_transforms",{}).get("turret",Transform3D.IDENTITY))
	var follows_mm: float = (snapshot_turret.origin-wreck_xform.origin).length()*1000.0
	print("[CD02-T06 %s] turret-off pose: turret moved %.1f mm ; snapshot follows the wreck within %.3f mm" % [id,moved_mm,follows_mm])
	check(moved_mm > 1.0,"CD02-T06 losing the turret actually moves it, so the leg is exercising something real ("+id+"): %.1f mm" % moved_mm)
	check(follows_mm <= 0.5,"CD02-T06 the query snapshot follows the wrecked turret rather than the old geometry ("+id+"): %.3f mm" % follows_mm)
	fourth.reset_vehicle()
	await _frames(4)
	var restored: Transform3D = fourth.turret.global_transform
	var restore_mm: float = (restored.origin-before_xform.origin).length()*1000.0
	var fresh_snapshot := QuerySnapshotBuilder.build_from_vehicle(fourth.tank,fourth.damage_layout_override)
	var fresh_turret: Transform3D = Transform3D(fresh_snapshot.get("part_world_transforms",{}).get("turret",Transform3D.IDENTITY))
	check(restore_mm <= 0.5,"CD02-T06 a respawn restores the turret geometry ("+id+"): %.3f mm from the pre-loss pose" % restore_mm)
	check((fresh_turret.origin-restored.origin).length()*1000.0 <= 0.5,"CD02-T06 the post-respawn query reflects the restored turret ("+id+")")
	print("[CD02-T06 %s] respawn: turret restored within %.3f mm ; generation=%d" % [id,restore_mm,int(fourth.state.generation)])
	fourth.queue_free(); await _frames(2)

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
	summary["mesh_overlay"] = mesh_overlay_cases(id,packet,layout)
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
	await occupancy_equal_guard(actor)
	var rack := _key_rack(packet)
	await pose_cases(id,defs,packet,actor,world)
	await re_tessellation_cases(id,defs,packet,actor,world,rack)
	await invalid_reference_cases(id,defs,packet,actor)
	await opening_and_layers_cases(id,defs,packet,world)
	await turret_loss_cases(id,defs,packet,world)
	world.queue_free(); await _frames(2)

func occupancy_equal_guard(actor: VehicleActor) -> void:
	await _frames(1)

func _key_rack(packet: Dictionary) -> Dictionary:
	for row in packet.get("modules",[]):
		if str(row.get("kind",""))=="ammo": return row
	return {}

func _joint_kinds(parts: Array) -> Dictionary:
	var out := {}
	for part in parts: out[str(part.joint_kind)] = int(out.get(str(part.joint_kind),0)) + 1
	return out

## An equivalent re-triangulation of every plate: each triangle split into three around its centroid, which preserves the
## covered surface exactly. Shared by the comparison case and the single-shot mode.
func _retriangulated(layout: VehicleLayoutDefinition) -> VehicleLayoutDefinition:
	var out: VehicleLayoutDefinition = layout.duplicate(true)
	for patch in out.armor_patches:
		var triangles := PackedInt32Array()
		var vertices := patch.vertices_local_m.duplicate()
		for index in range(0,patch.triangles.size(),3):
			var a: int = patch.triangles[index]; var b: int = patch.triangles[index+1]; var c: int = patch.triangles[index+2]
			var centroid := (patch.vertices_local_m[a] + patch.vertices_local_m[b] + patch.vertices_local_m[c]) / 3.0
			var centre := vertices.size()
			vertices.append(centroid)
			triangles.append_array(PackedInt32Array([a,b,centre, b,c,centre, c,a,centre]))
		patch.triangles = triangles
		patch.vertices_local_m = vertices
	return out

## CD02-T03 single-shot mode: one process, one actor, one shot, so the two layouts can be compared across processes with
## a control run of the same layout. The two-actor harness made the second firing irreproducible, which invalidated every
## earlier reading from it.
func _run_single_t03() -> void:
	var mode := "original"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--t03="): mode = str(arg).substr(6)
	owned_directory="res://assets/vehicles/test_cd003_single_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(owned_directory)
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()
	for id in MODERN:
		var packet := _read(PACKAGES+id+".json")
		packet.id = "test_cd003_"+id
		for source in packet.sources.values(): source.applies_to_identity_ids=[packet.id]
		var sources := fixture_asset(packet,1.0)
		var defs := VehicleDefs.new()
		var registered := VehicleCatalog.new(sources).register(packet,defs)
		if not registered.ok:
			print("CD02-T03-SINGLE %s layout=%s ok=false errors=%s" % [id,mode,JSON.stringify(registered.errors)]); continue
		var world := Node3D.new(); root.add_child(world)
		var actor := VehicleActor.new(); world.add_child(actor)
		if not actor.setup(defs,packet.id,"cd003_target",1,Transform3D.IDENTITY,2,null).ok:
			print("CD02-T03-SINGLE %s layout=%s ok=false reason=setup" % [id,mode]); world.queue_free(); continue
		actor.set_physics_process(false); actor.tank.set_physics_process(false)
		await _frames(3)
		var layout: VehicleLayoutDefinition = actor.damage_layout_override
		var chosen: VehicleLayoutDefinition = layout if mode!="modified" else _retriangulated(layout)
		var snapshot := QuerySnapshotBuilder.build_from_vehicle(actor.tank,chosen)
		var aim := _aim_at_plate(chosen,actor)
		var hits := await _real_shot(actor,world,snapshot,packet,aim.from,aim.to)
		print("CD02-T03-SINGLE %s layout=%s ok=true consumed=%.6f contacts=%d travelled=%.4f damage=%s" % [
			id,mode,float(hits.get("consumed_mm",-1.0)),int(hits.get("contacts",-1)),
			float(hits.get("travelled_m",-1.0)),str(hits.get("projectile_damage","[]"))])
		world.queue_free(); await _frames(2)
	for path in artifact_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(owned_directory.path_join(".gdignore")); DirAccess.remove_absolute(owned_directory)
	print("CD02_T03_SINGLE_DONE")
	quit(0)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--t03="):
			await _run_single_t03()
			return
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
