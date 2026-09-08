class_name ShotRecordBuilder
extends RefCounted
const SCHEMA_VERSION := 1
const MAX_PATH_POINTS := 512
const MAX_GEOMETRY_FRAMES := 96
const MAX_PATCHES := 256
const MAX_BOXES := 128

static func sample_path(st: ProjectileState) -> void:
	if not st.replay_error.is_empty(): return
	if st.replay_path.size() >= MAX_PATH_POINTS:
		st.replay_error = "path_record_limit"
		return
	if not st.replay_path.is_empty():
		var last: Dictionary = st.replay_path.back()
		if last.time_s == st.age_s and last.point_world == st.position_world:
			return
	st.replay_path.append({"time_s":st.age_s,"point_world":st.position_world,"velocity_world":st.velocity_world})

static func capture_frame(st: ProjectileState, event: Dictionary, snapshots: Array) -> int:
	if not st.replay_error.is_empty(): return -1
	var key := JSON.stringify([event.get("entity_id",""),event.get("life_id",0),event.get("target_generation",-1),Engine.get_physics_frames()])
	if st.replay_frame_keys.has(key): return int(st.replay_frame_keys[key])
	if st.replay_frames.size() >= MAX_GEOMETRY_FRAMES:
		st.replay_error = "geometry_frame_limit"
		return -1
	for snapshot in snapshots:
		if snapshot.get("entity_id","") != event.get("entity_id","") or snapshot.get("life_id",0) != event.get("life_id",0): continue
		if snapshot.get("target_generation",-1) != event.get("target_generation",-1): continue
		var frozen := freeze_geometry(snapshot)
		if not frozen.get("ok",false):
			st.replay_error = frozen.get("reason","invalid_geometry")
			return -1
		var frame: Dictionary = frozen.frame
		frame["frame_id"] = st.replay_frames.size()
		frame["time_s"] = st.age_s
		frame["physics_tick"] = Engine.get_physics_frames()
		st.replay_frames.append(frame)
		st.replay_frame_keys[key] = frame.frame_id
		return int(frame.frame_id)
	st.replay_error = "missing_impact_snapshot"
	return -1

static func freeze_geometry(snapshot: Dictionary) -> Dictionary:
	var layout: VehicleLayoutDefinition = snapshot.get("layout")
	if layout == null: return {"ok":false,"reason":"missing_layout"}
	if layout.armor_patches.size() > MAX_PATCHES or layout.modules.size()+layout.crew_stations.size() > MAX_BOXES:
		return {"ok":false,"reason":"geometry_size_limit"}
	var transforms: Dictionary = snapshot.get("part_world_transforms",{})
	var frame := {"entity_id":snapshot.get("entity_id",""),"life_id":snapshot.get("life_id",0),
		"target_generation":snapshot.get("target_generation",-1),"layout_id":layout.id,
		"layout_revision":layout.schema_version,"content_tier":layout.content_tier,
		"part_world_transforms":transforms.duplicate(true),"patches":[],"boxes":[]}
	for patch in layout.armor_patches:
		if not transforms.has(patch.part_id): return {"ok":false,"reason":"missing_part_pose"}
		var transform: Transform3D = transforms[patch.part_id]
		var vertices: Array = []
		for vertex in patch.vertices_local_m: vertices.append(transform*vertex)
		frame.patches.append({"id":patch.id,"part_id":patch.part_id,"vertices_world":vertices,
			"triangles":Array(patch.triangles),"normal_world":transform.basis*patch.outward_normal_local,
			"has_thickness":patch.has_thickness,"thickness_mm":patch.thickness_mm,"thickness_status":patch.thickness_status})
	for kind in ["module","crew"]:
		var items: Array = layout.modules if kind == "module" else layout.crew_stations
		for item in items:
			if not transforms.has(item.part_id): return {"ok":false,"reason":"missing_box_pose"}
			frame.boxes.append({"id":item.id,"kind":kind,"part_id":item.part_id,
				"box_world_transform":transforms[item.part_id]*item.local_box_transform,"size_m":item.size_m})
	return {"ok":true,"frame":frame}

static func freeze(st: ProjectileState, terminal: Dictionary) -> Dictionary:
	var complete := st.replay_error.is_empty()
	var reason := st.replay_error
	for contact in st.contacts+st.damage_records:
		if int(contact.get("geometry_frame",-1)) < 0:
			complete = false
			reason = "missing_contact_frame"
	var record := {"schema_version":SCHEMA_VERSION,
		"rules_versions":{"armor":GameConfig.ARMOR_RULES_VERSION,"damage":GameConfig.DAMAGE_RULES_VERSION,"recovery":RecoveryRules.VERSION},
		"record_id":JSON.stringify([st.round_id,st.shooter_id,st.shooter_life_id,st.shot_id,st.projectile_id]),
		"identity":{"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,
			"shooter_team_id":st.shooter_team_id,"shot_id":st.shot_id,"projectile_id":st.projectile_id,"shell_id":st.shell_id,"seed":st.seed},
		"launch":{"position_world":st.launch_position,"velocity_world":st.launch_velocity,"gravity_world":st.gravity_world,
			"physics_tick":st.born_physics_tick,"armor_policy":st.armor_policy},
		"complete":complete,"unavailable_reason":reason,"path":st.replay_path.duplicate(true),
		"frames":st.replay_frames.duplicate(true),"contacts":st.contacts.duplicate(true),
		"burst":st.burst.duplicate(true),"fragments":st.fragments.duplicate(true),
		"damage":st.damage_records.duplicate(true),"terminal":terminal.duplicate(true)}
	# Terminal already has the same events; avoid storing a second full copy inside it.
	record.terminal.erase("contacts")
	record.terminal.erase("damage_records")
	record.terminal.erase("burst")
	record.terminal.erase("fragments")
	freeze_containers(record)
	return record

static func freeze_containers(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): freeze_containers(child)
		value.make_read_only()
	elif value is Array:
		for child in value: freeze_containers(child)
		value.make_read_only()

static func validate(record: Dictionary) -> Dictionary:
	if record.get("schema_version",0) != SCHEMA_VERSION: return _bad("unsupported_schema")
	var versions: Dictionary = record.get("rules_versions",{}) if record.get("rules_versions") is Dictionary else {}
	if versions.get("armor","") != GameConfig.ARMOR_RULES_VERSION or versions.get("damage","") != GameConfig.DAMAGE_RULES_VERSION or versions.get("recovery","") != RecoveryRules.VERSION:
		return _bad("unsupported_rules")
	for key in ["identity","launch","terminal"]:
		if not record.get(key) is Dictionary: return _bad("missing_"+key)
	for key in ["path","frames","contacts","damage"]:
		if not record.get(key) is Array: return _bad("missing_"+key)
	if not record.get("complete") is bool or not record.get("record_id") is String: return _bad("invalid_header")
	if not record.identity.get("shooter_id") is String or record.identity.shooter_id.is_empty(): return _bad("invalid_identity")
	for key in ["round_id","shooter_life_id","projectile_id","shot_id","seed"]:
		var value: Variant = record.identity.get(key)
		if not _number(value) or int(value) != value: return _bad("invalid_identity_number")
	if record.identity.projectile_id <= 0: return _bad("invalid_projectile_id")
	if record.record_id != identity_key(record.identity): return _bad("record_identity_mismatch")
	for key in ["position_world","velocity_world","gravity_world"]:
		if not record.launch.get(key) is Vector3 or not record.launch[key].is_finite(): return _bad("invalid_launch")
	if not record.terminal.get("reason") is String or not _number(record.terminal.get("flight_time_s")): return _bad("invalid_terminal")
	if not record.terminal.get("impact_point") is Vector3 or not record.terminal.impact_point.is_finite(): return _bad("invalid_terminal_point")
	if record.path.is_empty() or record.path.size()>MAX_PATH_POINTS or record.frames.size()>MAX_GEOMETRY_FRAMES: return _bad("record_limits")
	if record.contacts.size()>GameConfig.ARMOR_CONTACTS_PER_SHOT or record.damage.size()>GameConfig.DAMAGE_MAX_CONTACTS: return _bad("event_limits")
	var fragment_check := validate_fragments(record)
	if not fragment_check.ok: return fragment_check
	var previous := -1.0
	for point in record.path:
		if not point is Dictionary or not point.get("point_world") is Vector3 or not point.get("velocity_world") is Vector3: return _bad("invalid_path_point")
		if not _number(point.get("time_s")): return _bad("invalid_path_time")
		var time := float(point.time_s)
		if not is_finite(time) or time < 0 or time < previous or not point.point_world.is_finite() or not point.velocity_world.is_finite(): return _bad("invalid_path_time")
		previous = time
	if record.get("complete",false) and (absf(previous-float(record.terminal.flight_time_s))>1e-5 or record.path.back().point_world.distance_to(record.terminal.impact_point)>1e-4): return _bad("terminal_path_mismatch")
	var frame_index := 0
	for frame in record.frames:
		if not frame is Dictionary or not frame.get("patches") is Array or not frame.get("boxes") is Array: return _bad("invalid_frame")
		if not _number(frame.get("frame_id")) or frame.frame_id != frame_index or not _number(frame.get("time_s")) or frame.time_s < 0: return _bad("invalid_frame_time")
		frame_index += 1
		if not frame.get("entity_id") is String or not frame.get("part_world_transforms") is Dictionary: return _bad("invalid_frame_identity")
		for transform in frame.part_world_transforms.values():
			if not transform is Transform3D or not transform.is_finite(): return _bad("invalid_part_transform")
		if frame.patches.size()>MAX_PATCHES or frame.boxes.size()>MAX_BOXES: return _bad("geometry_limits")
		for patch in frame.patches:
			if not patch is Dictionary or not patch.get("vertices_world") is Array or not patch.get("triangles") is Array: return _bad("invalid_patch")
			if patch.vertices_world.size()<3 or patch.vertices_world.size()>1024 or patch.triangles.is_empty() or patch.triangles.size()%3 != 0: return _bad("invalid_triangles")
			if not patch.get("normal_world") is Vector3 or not patch.normal_world.is_finite(): return _bad("invalid_normal")
			for vertex in patch.vertices_world:
				if not vertex is Vector3 or not vertex.is_finite(): return _bad("invalid_vertex")
			for index in patch.triangles:
				if not (index is int or index is float) or int(index) != index or index < 0 or index >= patch.vertices_world.size(): return _bad("invalid_index")
			if not ArmorPatchMesh.validate_geometry(PackedVector3Array(patch.vertices_world),PackedInt32Array(patch.triangles),patch.normal_world).is_empty(): return _bad("invalid_patch_geometry")
		for box in frame.boxes:
			if not box is Dictionary or not box.get("box_world_transform") is Transform3D or not box.get("size_m") is Vector3: return _bad("invalid_box")
			if not box.box_world_transform.is_finite() or not box.size_m.is_finite() or box.size_m.x<=0 or box.size_m.y<=0 or box.size_m.z<=0: return _bad("invalid_box_dimensions")
			if not LayoutMath.is_rigid(box.box_world_transform): return _bad("invalid_box_transform")
	if record.get("complete",false):
		for event in record.contacts+record.damage:
			if not event is Dictionary or not _number(event.get("geometry_frame")) or int(event.geometry_frame)!=event.geometry_frame or event.geometry_frame<0 or event.geometry_frame>=record.frames.size(): return _bad("invalid_event_frame")
			if not _number(event.get("flight_time_s")) or not event.get("impact_point") is Vector3: return _bad("invalid_event_time")
			if event.flight_time_s < 0 or event.flight_time_s > record.terminal.flight_time_s+1e-5 or not event.impact_point.is_finite(): return _bad("invalid_event_range")
			if not event.get("kind") is String or event.kind not in ["armor","module","crew"]: return _bad("invalid_event_kind")
			var frame: Dictionary = record.frames[int(event.geometry_frame)]
			if event.get("target_id","") != frame.entity_id or event.get("target_life_id",-1) != frame.life_id: return _bad("event_target_mismatch")
	return {"ok":true}

static func identity_key(identity: Dictionary) -> String:
	return JSON.stringify([int(identity.round_id),identity.shooter_id,int(identity.shooter_life_id),int(identity.shot_id),int(identity.projectile_id)])

static func append_fragments(st: ProjectileState) -> Dictionary:
	# FragmentSystem already committed actual outcomes; this never generates random paths.
	return {"burst":st.burst.duplicate(true),"fragments":st.fragments.duplicate(true)}

static func validate_fragments(record: Dictionary) -> Dictionary:
	var burst: Variant = record.get("burst",{})
	var fragments: Variant = record.get("fragments",[])
	if not burst is Dictionary or not fragments is Array or fragments.size()>ShellEffectPolicy.MAX_FRAGMENTS: return _bad("invalid_fragments")
	if burst.is_empty(): return {"ok":true} if fragments.is_empty() else _bad("missing_burst")
	if burst.get("rules_version","") != ShellEffectPolicy.VERSION: return _bad("unsupported_fragment_rules")
	if not burst.get("point_world") is Vector3 or not burst.point_world.is_finite() or not _number(burst.get("time_s")): return _bad("invalid_burst_point")
	if burst.time_s < 0 or burst.time_s > record.terminal.flight_time_s+1e-5: return _bad("invalid_burst_time")
	if not _number(burst.get("seed")) or burst.seed!=record.identity.seed: return _bad("invalid_burst_seed")
	if record.complete:
		if not _number(burst.get("geometry_frame")) or int(burst.geometry_frame)!=burst.geometry_frame or burst.geometry_frame<0 or burst.geometry_frame>=record.frames.size(): return _bad("invalid_burst_frame")
		var frame: Variant = record.frames[int(burst.geometry_frame)]
		if not frame is Dictionary or burst.get("target_id")!=frame.get("entity_id") or burst.get("target_life_id")!=frame.get("life_id"): return _bad("invalid_burst_target")
	var linked_damage := {}
	for i in fragments.size():
		var fragment: Variant = fragments[i]
		if not fragment is Dictionary or fragment.get("id",-1) != i or not fragment.get("path") is Array or not fragment.get("contacts") is Array or not fragment.get("damage_indices") is Array: return _bad("invalid_fragment")
		if fragment.path.is_empty() or fragment.path.size()>ShellEffectPolicy.FRAGMENT_CONTACTS+1 or fragment.contacts.size()>ShellEffectPolicy.FRAGMENT_CONTACTS: return _bad("fragment_limits")
		if not fragment.get("direction") is Vector3 or not fragment.direction.is_finite() or absf(fragment.direction.length()-1.0)>0.001: return _bad("invalid_fragment_direction")
		if not _number(fragment.get("queries")) or int(fragment.queries)!=fragment.queries or fragment.queries<0 or fragment.queries>ShellEffectPolicy.FRAGMENT_CONTACTS or not fragment.get("reason") is String: return _bad("invalid_fragment_metadata")
		var length := 0.0
		var previous: Vector3 = burst.point_world
		for point in fragment.path:
			if not point is Vector3 or not point.is_finite(): return _bad("invalid_fragment_point")
			length += previous.distance_to(point); previous = point
		if length > ShellEffectPolicy.FRAGMENT_RANGE_M+0.001 or fragment.path[0].distance_to(burst.point_world)>0.001: return _bad("fragment_range")
		for index in fragment.damage_indices:
			if not _number(index) or int(index)!=index or index<0 or index>=record.damage.size() or not record.damage[int(index)] is Dictionary or record.damage[int(index)].get("fragment_id",-1)!=i or linked_damage.has(int(index)): return _bad("invalid_fragment_damage")
			linked_damage[int(index)] = true
		for contact in fragment.contacts:
			if not contact is Dictionary or not contact.get("point_world") is Vector3 or not contact.point_world.is_finite() or not contact.get("result") is String: return _bad("invalid_fragment_contact")
			if record.complete:
				if not _number(contact.get("geometry_frame")) or int(contact.geometry_frame)!=contact.geometry_frame or contact.geometry_frame<0 or contact.geometry_frame>=record.frames.size(): return _bad("invalid_fragment_contact_frame")
				var frame: Variant = record.frames[int(contact.geometry_frame)]
				if not frame is Dictionary or contact.get("entity_id")!=frame.get("entity_id") or contact.get("life_id")!=frame.get("life_id"): return _bad("invalid_fragment_contact_target")
	for index in record.damage.size():
		var event: Variant = record.damage[index]
		if not event is Dictionary: return _bad("invalid_fragment_damage_event")
		if event.get("fragment_id",-1)!=-1 and not linked_damage.has(index): return _bad("unlinked_fragment_damage")
	return {"ok":true}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)

static func _bad(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}
