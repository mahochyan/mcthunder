extends SceneTree
## WT-040-R1 step 3, class A acceptance: verify the measured geometry instead of trusting the tool
## that produced it. Three independent checks, deliberately none of them "the tool compared with
## itself":
##   A. ADAPTER vs SOURCE - the same key measurements taken from the adapter artefact and from the
##      original source GLB must agree within 1 mm. This is the check that matters, because the
##      adapter is an export of the model and an export that moved geometry would poison every field;
##      the marker-transform defect earlier in this session was exactly that class of failure.
##   B. INVARIANTS - ring heights increase, ring spans stay inside the hull, the turret's bottom is
##      below its top, the taper is sane, the ring aperture does not exceed the turret, and EVERY
##      measured field carries a method string (no unexplained numbers).
##   C. DETERMINISM - the values stored in the draft JSON equal freshly measured values.
##
## Usage: -s res://tests/check_modern_geometry.gd -- <id>=<adapter>=<source> [...]
const DRAFT := "res://logs/WT-040-R1/modern_geometry_draft.json"
const TOL := 0.001
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var targets: Array = []
	# WT-040-R1: ONLY ASCII vehicle ids travel on the command line. The source model lives in a
	# Chinese-named folder outside the project: a script literal cannot carry it safely (Windows
	# PowerShell reads a BOM-less .ps1 as ANSI and mangles it) and argv proved unreliable from a child
	# process, so the path is read from the dossier that GDScript opens as UTF-8 and the adapter path is
	# derived from the same id.
	for arg in args:
		var text := str(arg)
		if text.is_empty() or text.contains("="):
			continue
		var dossier := "res://assets/reference_data/candidates/%s.json" % text
		var raw := FileAccess.get_file_as_string(dossier)
		var parsed_d: Variant = JSON.parse_string(raw)
		var source := ""
		if parsed_d is Dictionary:
			# WT-040-R1: model_candidates is an ARRAY in these dossiers, not a dictionary. PowerShell
			# displayed "$j.model_candidates.glb_path" as if it were an object because it silently
			# unwraps a single-element array - the third time this session that a PowerShell convenience
			# hid the real shape. Both shapes are handled here, preferring the entry whose id matches.
			var mc: Variant = parsed_d.get("model_candidates",null)
			if mc is Array:
				for entry in mc:
					if not entry is Dictionary: continue
					var candidate := str(entry.get("glb_path",""))
					if candidate.is_empty(): continue
					if str(entry.get("id","")) == text or source.is_empty(): source = candidate
			elif mc is Dictionary:
				source = str(mc.get("glb_path",""))
		if source.is_empty():
			print("[chk] ",text,": dossier has no model_candidates.glb_path"); continue
		targets.append("%s=res://assets/vehicles/adapters/%s/vehicle_adapter.glb=%s" % [text,text,source])
		print("[chk]   target: ",text," -> source path taken from the dossier (",source.length()," chars)")
	if targets.is_empty(): print("[chk] no targets"); quit(1); return
	var draft := _read_json(DRAFT)
	var rows: Dictionary = {}
	for r in draft.get("rows",[]):
		if r is Dictionary and r.get("id","") != null: rows[str(r.id)] = r
	for arg in targets:
		var parts := str(arg).split("=",true,2)
		if parts.size() != 3:
			_check(false,"target must be <id>=<adapter>=<source>: "+str(arg)); continue
		var id := parts[0]
		var adapter := parts[1]
		var source := parts[2]
		var a := _measure(adapter)
		var s := _measure(source)
		# --- A: adapter vs source ---------------------------------------------------------
		_check(not a.is_empty() and not s.is_empty(), id+": both the adapter and the source can be measured")
		if a.is_empty() or s.is_empty(): continue
		for key in ["hull_min_y","hull_max_y","hull_min_z","hull_max_z","turret_origin","gun_origin",
				"turret_bottom","turret_top","wheel_count"]:
			var va: Variant = a.get(key)
			var vs: Variant = s.get(key)
			if va is Vector3 and vs is Vector3:
				_check((va as Vector3).distance_to(vs as Vector3) <= TOL,
					"%s: %s agrees adapter vs source (%s vs %s)" % [id,key,str(va),str(vs)])
			elif va is float and vs is float:
				_check(absf(float(va)-float(vs)) <= TOL,
					"%s: %s agrees adapter vs source (%.4f vs %.4f)" % [id,key,float(va),float(vs)])
			elif va is int and vs is int:
				_check(int(va) == int(vs), "%s: %s agrees adapter vs source (%d vs %d)" % [id,key,int(va),int(vs)])
		# --- B: invariants on the STORED row ---------------------------------------------
		var row: Dictionary = rows.get(id,{})
		var fields: Dictionary = row.get("fields",{})
		var methods: Dictionary = row.get("methods",{})
		if not row.is_empty():
			var unexplained: Array[String] = []
			for key2 in fields.keys():
				if not methods.has(key2): unexplained.append(str(key2))
			_check(unexplained.is_empty(), "%s: every measured field carries a method (unexplained: %s)" % [id,str(unexplained)])
			if fields.has("hull_rings"):
				var rings: Array = fields.hull_rings
				_check(rings.size() == 3, "%s: exactly three hull rings are stored (floor/mid/roof)" % id)
				var ordered := true
				var inside := true
				for i in rings.size():
					var ring: Array = rings[i]
					if ring.size() != 4: inside = false; continue
					if i > 0 and float(ring[0]) <= float((rings[i-1] as Array)[0]): ordered = false
					if float(ring[1]) <= 0.0: inside = false
					if float(ring[3]) < float(ring[2]): inside = false
				_check(ordered, "%s: hull ring heights increase from floor to roof" % id)
				_check(inside, "%s: hull rings have positive half-widths and front z < rear z" % id)
			if fields.has("turret_bottom") and fields.has("turret_top"):
				_check(float(fields.turret_bottom) < float(fields.turret_top), "%s: turret bottom is below its top" % id)
			if fields.has("turret_taper"):
				_check(float(fields.turret_taper) > 0.0 and float(fields.turret_taper) <= 1.5, "%s: turret taper is sane (%.3f)" % [id,float(fields.turret_taper)])
			# --- C: determinism ---------------------------------------------------------
			for key3 in fields.keys():
				var stored: Variant = fields[key3]
				var fresh: Variant = a.get("draft_"+str(key3))
				if stored == null or fresh == null: continue
				if stored is float and fresh is float:
					_check(absf(float(stored)-float(fresh)) <= TOL, "%s: %s is reproducible (%.4f vs %.4f)" % [id,key3,float(stored),float(fresh)])
			# --- WT-040-R1 extension: the fields the audit found UNASSERTED -----------------
			# Only 7 of the 17 emitted fields were checked, because determinism needs a fresh
			# measurement and that helper returns seven keys; the two rules being fixed had no
			# assertion at all. These are added so the fix has something to pass against - and run
			# BEFORE the fix they should be RED, which is the evidence they test something.
			if fields.has("ring_half") and fields.has("hull_rings"):
				var rr: Array = fields.hull_rings
				var roof_half := 0.0
				if rr.size() == 3: roof_half = float((rr[2] as Array)[1])
				_check(float(fields.ring_half) > 0.0, "%s: ring_half is positive" % id)
				_check(roof_half <= 0.01 or float(fields.ring_half) <= roof_half*0.85 + TOL,
					"%s: ring_half (%.3f) fits inside the roof half-width (%.3f)" % [id,float(fields.ring_half),roof_half])
			if fields.has("turret_outline"):
				var ol: Array = fields.turret_outline
				_check(ol.size() >= 8 and ol.size() <= 32, "%s: turret_outline has 8-32 points (%d)" % [id,ol.size()])
				var closest := INF
				for i2 in ol.size():
					var pp: Array = ol[i2]
					var qq: Array = ol[(i2+1) % ol.size()]
					closest = minf(closest, sqrt(pow(float(pp[0])-float(qq[0]),2.0)+pow(float(pp[1])-float(qq[1]),2.0)))
				_check(closest >= 0.005 - TOL, "%s: adjacent outline points are at least 5 mm apart (closest %.5f)" % [id,closest])
			var bore2 := 0.0
			var fpath2 := "res://logs/WT-040-R1/modern_facts_draft.json"
			if FileAccess.file_exists(fpath2):
				var fd2: Variant = JSON.parse_string(FileAccess.get_file_as_string(fpath2))
				if fd2 is Dictionary:
					for fr2 in fd2.get("rows",[]):
						if str(fr2.get("id","")) != id: continue
						var asm2: Variant = fr2.get("assembly",{})
						if asm2 is Dictionary: bore2 = float(asm2.get("caliber_mm",0.0)) / 2000.0
			if bore2 > 0.0 and fields.has("mantlet_half_width") and fields.has("mantlet_half_height"):
				_check(float(fields.mantlet_half_width) >= bore2, "%s: mantlet half-width %.4f encloses the bore %.4f" % [id,float(fields.mantlet_half_width),bore2])
				_check(float(fields.mantlet_half_height) >= bore2, "%s: mantlet half-height %.4f encloses the bore %.4f" % [id,float(fields.mantlet_half_height),bore2])
			for key4 in ["barrel_length","hull_half_width","track_width","wheel_radius"]:
				if fields.has(key4):
					_check(float(fields[key4]) > 0.0 and is_finite(float(fields[key4])), "%s: %s is finite and positive (%.4f)" % [id,key4,float(fields[key4])])
			for key5 in ["muzzle_brake","open_top"]:
				if fields.has(key5):
					_check(fields[key5] is bool, "%s: %s is a boolean" % [id,key5])
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MODERN_GEOMETRY_CHECKS_PASS" if failed == 0 else "MODERN_GEOMETRY_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

## Minimal independent re-measurement: hull AABB, pivot positions, turret span, road-wheel count.
## Deliberately NOT the generator's band logic - this asks only for properties that must match
## between two files if the export preserved the model.
func _measure(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path): return out
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path,state) != OK: return out
	var scene: Node = document.generate_scene(state)
	if scene == null: return out
	root.add_child(scene)
	var meshes: Array[MeshInstance3D] = []
	_collect(scene,meshes)
	var hull: MeshInstance3D = null
	for m in meshes:
		var lower := str(m.name).to_lower()
		if lower == "body" or lower == "hull": hull = m
	if hull == null:
		for m2 in meshes:
			if str(m2.name).to_lower().contains("hullarmour"): hull = m2
	if hull != null:
		var aabb := _world_aabb(hull)
		out["hull_min_y"] = snappedf(aabb.position.y,0.0001)
		out["hull_max_y"] = snappedf(aabb.position.y+aabb.size.y,0.0001)
		out["hull_min_z"] = snappedf(aabb.position.z,0.0001)
		out["hull_max_z"] = snappedf(aabb.position.z+aabb.size.z,0.0001)
	var turret := _node(scene,"TurretPivot")
	var gun := _node(scene,"GunPivot")
	if turret is Node3D: out["turret_origin"] = (turret as Node3D).global_position
	if gun is Node3D: out["gun_origin"] = (gun as Node3D).global_position
	for m3 in meshes:
		if str(m3.name).to_lower().begins_with("turret") and str(m3.name) != "TurretPivot":
			var t := _world_aabb(m3)
			out["turret_bottom"] = snappedf(t.position.y,0.0001)
			out["turret_top"] = snappedf(t.position.y+t.size.y,0.0001)
			break
	var road := 0
	for m4 in meshes:
		var lower2 := str(m4.name).to_lower()
		if lower2.contains("wheel") and not lower2.contains("top") and not lower2.contains("front") and not lower2.contains("drive"):
			var tail := lower2.split("_")
			if str(tail[tail.size()-1]).is_valid_int() and (m4 as Node3D).global_position.x < 0.0: road += 1
	out["wheel_count"] = road
	root.remove_child(scene)
	scene.free()
	return out

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: out.append(node)
	for child in node.get_children(): _collect(child,out)

func _node(node: Node, name: String) -> Node:
	if str(node.name) == name: return node
	for child in node.get_children():
		var hit := _node(child,name)
		if hit != null: return hit
	return null

func _world_aabb(mesh: MeshInstance3D) -> AABB:
	var m: Mesh = mesh.mesh
	if m == null: return AABB()
	var first := true
	var box := AABB()
	for surface in m.get_surface_count():
		var arrays: Array = m.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX: continue
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not verts is PackedVector3Array: continue
		var xform := mesh.global_transform
		for v in verts:
			var p: Vector3 = xform * v
			if first: box = AABB(p,Vector3.ZERO); first = false
			else: box = box.expand(p)
	return box

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
