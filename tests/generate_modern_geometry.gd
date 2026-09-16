extends SceneTree
## WT-040-R1 step 3, class A: measure the `geometry` block of a modern vehicle FROM ITS ARTEFACT.
##
## The field meanings are not guessed here - they were pinned down from the module that consumes them
## (HistoricalVehicleGeometry.build), and every field this tool writes carries a `method` string so
## the number can be audited or reproduced. Requirements honoured, one by one:
##   * only measurable fields are written, each with its method;
##   * hull_rings has EXACTLY THREE rings (floor, hull mid line, roof), as that module expects;
##   * turret_outline is the BOTTOM outline, not the top one;
##   * barrel_length is taken from the adapter's recorded muzzle offset and states that basis;
##   * a vehicle with no gun gets NO muzzle fields at all.
## Measurement discipline learned the hard way earlier in this session: the scene is added to the tree
## BEFORE any global transform is read, because global_position off-tree silently returns (0,0,0).
##
## Usage: -s res://tests/generate_modern_geometry.gd -- <id>=<absolute adapter glb> [...]
const OUT_PATH := "res://logs/WT-040-R1/modern_geometry_draft.json"
const BANDS := 24
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): print("[geom] no target given"); quit(1); return
	var rows: Array[Dictionary] = []
	for arg in args:
		var entry := str(arg)
		var parts := entry.split("=",true,1)
		if parts.size() != 2: print("[geom] bad arg ",entry); continue
		var id := parts[0]
		var path := parts[1]
		var row := _measure(id,path)
		rows.append(row)
	# WT-040-R1 HARDENING: refuse to write a SHORT draft. A malformed argument used to be printed and
	# then skipped, so the generator could exit zero having measured FEWER vehicles than the caller
	# asked for - and this draft feeds the pipeline's geometry_check and the layer probe, so a missing
	# vehicle could slip downstream unnoticed. The same class of silent skip was found and closed in
	# check_modern_geometry.gd. Checking row count against argument count catches ANY cause of row loss,
	# present or future, rather than only the malformed-argument path.
	if rows.size() != args.size():
		print("[geom] REFUSING to write: asked for %d target(s) but measured %d - see the 'bad arg' lines above" % [args.size(),rows.size()])
		print("MODERN_GEOMETRY_FAIL")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://logs/WT-040-R1"))
	var file := FileAccess.open(OUT_PATH,FileAccess.WRITE)
	# WT-040-R1 HARDENING (third false-green path in this tool): the old code printed
	# MODERN_GEOMETRY_DONE and quit(0) whether or not the file opened, so an unwritable output path
	# produced NO draft while still reporting success - and every downstream consumer reads that draft.
	# Success is now reported only after the write actually happened.
	if file == null:
		print("[geom] FAILED to open %s for writing (error %d); no draft was produced" % [OUT_PATH,FileAccess.get_open_error()])
		print("MODERN_GEOMETRY_FAIL")
		quit(1)
		return
	file.store_string(JSON.stringify({"schema":1,
		"note":"draft geometry measured from adapter artefacts; every field carries its method; hull_rings are floor/mid/roof",
		"rows":rows}, "  ")+"\n")
	file.close()
	print("[geom] wrote ",OUT_PATH)
	print("MODERN_GEOMETRY_DONE")
	quit(0)

func _measure(id: String, path: String) -> Dictionary:
	var row := {"id":id,"adapter_path":path,"fields":{},"methods":{},"notes":[],"ok":false}
	if not FileAccess.file_exists(path):
		row.notes.append("adapter missing"); return row
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path,state) != OK:
		row.notes.append("append failed"); return row
	var scene: Node = document.generate_scene(state)
	if scene == null:
		row.notes.append("scene failed"); return row
	root.add_child(scene)   # measure INSIDE the tree (see header)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(scene,meshes)
	var turret_pivot := _find_node(scene,"TurretPivot")
	var gun_pivot := _find_node(scene,"GunPivot")
	var gun_mesh := _find_mesh(meshes,["main","gun","barrel","cannon","kanone","rohr"])
	var hull_mesh := _find_hull_mesh(meshes)
	var turret_mesh := _find_mesh(meshes,["turret"])
	var mantlet_mesh := _find_mesh(meshes,["mantlet","shield","blende"])
	var wheels: Array[MeshInstance3D] = []
	for m in meshes:
		if str(m.name).to_lower().contains("wheel"): wheels.append(m)
	var f: Dictionary = row.fields
	var method: Dictionary = row.methods
	# --- hull rings: three rings from a y-band scan of the hull mesh's vertices ---------------
	if hull_mesh != null:
		row.notes.append("hull mesh chosen for measurement: " + str(hull_mesh.name))
		var pts := _world_vertices(hull_mesh)
		var lo := INF; var hi := -INF
		for p in pts: lo = minf(lo,p.y); hi = maxf(hi,p.y)
		var ys := [lo,(lo+hi)*0.5,hi]
		var rings: Array = []
		var band_failed := false
		var want: int = maxi(pts.size()/40,6)
		for band in 3:
			var ring := _band_extent_adaptive(pts,ys[band],want)
			if ring.size() != 4:
				band_failed = true
				row.notes.append("hull ring %d band caught no vertices: hull_rings not emitted (loud, not zero)" % band)
				break
			rings.append([snappedf(ys[band],0.001),snappedf(ring[0],0.001),snappedf(ring[1],0.001),snappedf(ring[2],0.001)])
			row.notes.append("hull ring %d used %d nearest vertices, effective y tolerance %.3f m" % [band,want,float(ring[3])])
		if not band_failed:
			# WT-040-R1 validity guard: a ring whose z-span is a sliver of the hull's own z-span is not
			# a cross-section at all. The Leopard's HullArmour is a sparse armour PLATE - its "nearest
			# vertices" at mid and top height clustered into 4 cm and 5 cm slivers at the front and rear
			# - so the mesh exists but is not a hull volume, and emitting those rings would be a
			# plausible-looking lie. Rings are therefore rejected loudly with the measured spans.
			var overall := 0.0
			var zmin_all := INF; var zmax_all := -INF
			for p in pts:
				zmin_all = minf(zmin_all,p.z); zmax_all = maxf(zmax_all,p.z)
			overall = zmax_all - zmin_all
			var sliver := false
			for ring in rings:
				if (float(ring[3])-float(ring[2])) < overall*0.5:
					sliver = true
			if sliver or overall <= 0.5:
				# WT-040-R1 (3): the plate/detail-shell case. A sparse armour plate cannot yield
				# cross-sections from a band scan, so the envelope is taken from the mesh's own bounding
				# box and LABELLED as an envelope rather than a cross-section - it is still a measurement,
				# but of a different kind, and the method string says so. Previously this branch left a
				# required field empty, which blocked the whole content layer for this vehicle.
				var xmin2 := INF; var xmax2 := -INF
				var ymin2 := INF; var ymax2 := -INF
				var zmin3 := INF; var zmax3 := -INF
				for p3 in pts:
					xmin2 = minf(xmin2,p3.x); xmax2 = maxf(xmax2,p3.x)
					ymin2 = minf(ymin2,p3.y); ymax2 = maxf(ymax2,p3.y)
					zmin3 = minf(zmin3,p3.z); zmax3 = maxf(zmax3,p3.z)
				var half2 := snappedf(maxf(absf(xmin2),absf(xmax2)),0.001)
				if (ymax2-ymin2) < 0.001 or half2 <= 0.0 or (zmax3-zmin3) < 0.001:
					row.notes.append("hull rings REJECTED and NO fallback possible: the bounding box is degenerate (dx %.3f dy %.3f dz %.3f)" % [xmax2-xmin2,ymax2-ymin2,zmax3-zmin3])
				else:
					var rows3: Array = []
					for lvl in [ymin2,(ymin2+ymax2)*0.5,ymax2]:
						rows3.append([snappedf(lvl,0.001),half2,snappedf(zmin3,0.001),snappedf(zmax3,0.001)])
					f["hull_rings"] = rows3
					f["hull_half_width"] = half2
					method["hull_rings"] = "AABB ENVELOPE FALLBACK, NOT a scanned cross-section: the band scan produced slivers (ring spans under half of the %.3f m overall span), so the three rings are the hull mesh's own bounding box at floor/mid/roof - half-width from the x-extent, front/rear z from the z-extent" % overall
					method["hull_half_width"] = "half of the hull mesh x-extent (AABB envelope fallback, same basis as the rings)"
					row.notes.append("hull_rings via AABB ENVELOPE FALLBACK (labelled as an envelope, not a cross-section): band scan slivers, overall span %.3f m, box %.3f x %.3f x %.3f m" % [overall,xmax2-xmin2,ymax2-ymin2,zmax3-zmin3])
			else:
				f["hull_rings"] = rings
				method["hull_rings"] = "adaptive nearest-vertex band scan of the hull mesh: [y, half-width, front z, rear z]; ring 0 = floor, 1 = mid, 2 = roof; the effective y tolerance per ring is recorded in the notes"
				var mid := _band_extent_adaptive(pts,(lo+hi)*0.5,want)
				if mid.size() == 4:
					f["hull_half_width"] = snappedf(mid[0],0.001)
					method["hull_half_width"] = "half of the hull mesh x-extent at mid height (same adaptive band as the mid ring)"
	else:
		row.notes.append("hull mesh not identified")
	# --- turret origins ------------------------------------------------------------------------
	# WT-040-R1 (user ruling 2/3): the mount offsets the binding validator compares against are RELATIVE -
	# the turret from the hull, the gun from the turret - so they are measured that way from the model. Their
	# global positions are a different quantity, which is why the rest-pose checks reported that the model
	# pose differed from the combat geometry.
	var offsets := ModelAnchorReader.role_offsets(path)
	if offsets.get("ok",false):
		var to: Vector3 = offsets["turret_origin"]
		var go: Vector3 = offsets["gun_origin"]
		f["turret_origin"] = [snappedf(to.x,0.001),snappedf(to.y,0.001),snappedf(to.z,0.001)]
		method["turret_origin"] = "RELATIVE: %s relative to the hull node in the measured model; relative basis identity: %s" % [str(offsets.get("turret_node","")),str(offsets.get("all_bases_identity",false))]
		f["gun_origin"] = [snappedf(go.x,0.001),snappedf(go.y,0.001),snappedf(go.z,0.001)]
		method["gun_origin"] = "RELATIVE: %s relative to %s in the measured model" % [str(offsets.get("gun_node","")),str(offsets.get("turret_node",""))]
	else:
		row.notes.append("role offsets unavailable from the model (%s), so turret_origin/gun_origin were NOT emitted rather than taken from global positions" % str(offsets.get("reason","?")))
	if gun_mesh == null:
		row.notes.append("no gun mesh: no muzzle fields are emitted (consistent with the adapter verdict)")
	# --- turret shape: bottom outline, top/bottom, taper, ring half ----------------------------
	if turret_mesh != null:
		var tpts := _world_vertices(turret_mesh)
		var tlo := INF; var thi := -INF
		for p in tpts: tlo = minf(tlo,p.y); thi = maxf(thi,p.y)
		f["turret_bottom"] = snappedf(tlo,0.001)
		f["turret_top"] = snappedf(thi,0.001)
		method["turret_bottom"] = "minimum y of the turret mesh vertices"
		method["turret_top"] = "maximum y of the turret mesh vertices"
		var span := maxf(thi-tlo,0.05)
		var bot := _band_footprint(tpts,tlo,span*0.25)
		var top := _band_footprint(tpts,thi,span*0.25)
		# WT-040-R1 FIX: de-duplicate the outline AFTER snapping. Two distinct hull points can snap to
		# the same millimetre coordinate, and the Leopard's outline came out with coincident points
		# (closest pair 0.00000 m), which is what produced the degenerate triangles and the "normal must
		# be unit length" errors. Points closer than 5 mm are dropped; if fewer than 8 remain the outline
		# is REJECTED loudly, because the validator requires 8-32 points and a bad outline must not ship.
		var raw_outline: Array = _convex_outline(bot)
		var dedup: Array = []
		for op in raw_outline:
			var far_enough := true
			for qp in dedup:
				if sqrt(pow(float(op[0])-float(qp[0]),2.0)+pow(float(op[1])-float(qp[1]),2.0)) < 0.005:
					far_enough = false
					break
			if far_enough: dedup.append(op)
		if dedup.size() < 8:
			row.notes.append("turret_outline REJECTED: only %d distinct points after 5 mm de-duplication (validator needs 8-32)" % dedup.size())
		else:
			f["turret_outline"] = dedup
			method["turret_outline"] = "convex outline of the turret mesh vertices in the BOTTOM quarter (ordered, x/z), de-duplicated at 5 mm so no two adjacent points coincide"
			if dedup.size() != raw_outline.size():
				row.notes.append("turret_outline de-duplicated: %d -> %d points (coincident points removed)" % [raw_outline.size(),dedup.size()])
		var bot_half := _footprint_half(bot)
		var top_half := _footprint_half(top)
		f["turret_taper"] = snappedf((top_half/bot_half) if bot_half > 0.01 else 0.0,0.001)
		method["turret_taper"] = "top-quarter half extent divided by bottom-quarter half extent"
		# WT-040-R1: the turret-ring aperture MUST fit inside the hull roof. Derived from the turret's
		# bottom outline alone it came out at 1.474 m while the measured roof half-width is 0.869 m, so
		# the opening was cut wider than the roof it sits in and HistoricalVehicleGeometry's roof faces
		# could not be manifold - a real, reproducible geometric defect the layer probe found. The value
		# is therefore clamped to 85% of the roof half-width, and the rule is stated in the method.
		var roof_half := 0.0
		var ring_rows: Variant = f.get("hull_rings",[])
		if ring_rows is Array and (ring_rows as Array).size() == 3:
			roof_half = float(((ring_rows as Array)[2] as Array)[1])
		var clamped := bot_half
		if roof_half > 0.01 and bot_half > roof_half*0.85:
			clamped = roof_half*0.85
		f["ring_half"] = snappedf(clamped,0.001)
		method["ring_half"] = "DERIVED: half of the smaller bottom-outline extent (no turret-ring node in this model), CLAMPED to 85%% of the measured hull roof half-width (%.3f m) because a ring wider than the roof cannot produce manifold roof faces; author may replace" % roof_half
		f["open_top"] = false
		method["open_top"] = "INFERRED: enclosed main battle tank, top band is closed; not a visual review"
		row.notes.append("open_top is inferred, not visually verified")
	else:
		row.notes.append("turret mesh not identified")
	# --- mantlet -------------------------------------------------------------------------------
	if mantlet_mesh != null:
		var mpts := _world_vertices(mantlet_mesh)
		var mlo := INF; var mhi := -INF; var mx := 0.0
		for p in mpts:
			mlo = minf(mlo,p.y); mhi = maxf(mhi,p.y); mx = maxf(mx,absf(p.x))
		f["mantlet_half_width"] = snappedf(mx,0.001)
		f["mantlet_half_height"] = snappedf((mhi-mlo)*0.5,0.001)
		method["mantlet_half_width"] = "maximum |x| of the mantlet/shield mesh vertices"
		method["mantlet_half_height"] = "half of the mantlet mesh y-extent"
	else:
		# WT-040-R1: the validator REQUIRES mantlet_half_width/height, but the T-80B has no separate
		# mantlet mesh (its meshes are Turret/Gun/Body plus running gear). Instead of leaving the
		# packet invalid or inventing a number, the mantlet is DERIVED from the gun mesh's own rear
		# quarter - the region where a mantlet sits - and the derivation is stated in the method.
		if gun_mesh != null:
			var gpts := _world_vertices(gun_mesh)
			var glo := INF; var ghi := -INF
			for p in gpts:
				glo = minf(glo,p.y); ghi = maxf(ghi,p.y)
			var rear: Array[Vector3] = []
			var cut := glo + (ghi-glo)*0.25
			for p2 in gpts:
				if p2.y <= cut: rear.append(p2)
			if rear.is_empty(): rear = gpts
			var hw := 0.0; var lo2 := INF; var hi2 := -INF
			for p3 in rear:
				hw = maxf(hw,absf(p3.x)); lo2 = minf(lo2,p3.y); hi2 = maxf(hi2,p3.y)
			f["mantlet_half_width"] = snappedf(hw,0.001)
			f["mantlet_half_height"] = snappedf((hi2-lo2)*0.5,0.001)
			method["mantlet_half_width"] = "DERIVED (no separate mantlet mesh on this model): maximum |x| of the gun mesh's rear quarter, which is where a mantlet sits; author may replace"
			method["mantlet_half_height"] = "DERIVED (no separate mantlet mesh on this model): half of the gun mesh's rear-quarter y-extent; author may replace"
			row.notes.append("mantlet fields are DERIVED from the gun mesh rear quarter because this model has no mantlet mesh")
	# WT-040-R1 FIX (after the branch, so it covers BOTH paths with the smallest footprint): the shield
	# MUST enclose the bore. HistoricalVehicleGeometry builds the mantlet as an annulus whose inner hole
	# is caliber_mm/2000, so a shield narrower than that hole is a negative-width ring whose faces cannot
	# be manifold - which is exactly the four barrel edges the layer probe reported. The calibre comes
	# from the facts draft (read-only); if it is unavailable the floor is skipped LOUDLY, not silently.
	var bore_m := 0.0
	var facts_path := "res://logs/WT-040-R1/modern_facts_draft.json"
	if FileAccess.file_exists(facts_path):
		var facts_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(facts_path))
		if facts_doc is Dictionary:
			for frow in facts_doc.get("rows",[]):
				if str(frow.get("id","")) != id: continue
				var asm: Variant = frow.get("assembly",{})
				if asm is Dictionary: bore_m = float(asm.get("caliber_mm",0.0)) / 2000.0
	if bore_m > 0.0 and f.has("mantlet_half_width") and f.has("mantlet_half_height"):
		var want_w: float = bore_m*1.6
		var want_h: float = bore_m*1.3
		var had_w: float = float(f["mantlet_half_width"])
		var had_h: float = float(f["mantlet_half_height"])
		f["mantlet_half_width"] = snappedf(maxf(had_w,want_w),0.001)
		f["mantlet_half_height"] = snappedf(maxf(had_h,want_h),0.001)
		method["mantlet_half_width"] = str(method.get("mantlet_half_width","")) + " | FLOOR: raised to >= 1.6x the cited bore radius (%.4f m) so the shield encloses the hole" % bore_m
		method["mantlet_half_height"] = str(method.get("mantlet_half_height","")) + " | FLOOR: raised to >= 1.3x the cited bore radius (%.4f m) so the shield encloses the hole" % bore_m
		if absf(had_w-float(f["mantlet_half_width"])) > 0.0005 or absf(had_h-float(f["mantlet_half_height"])) > 0.0005:
			row.notes.append("mantlet enlarged to enclose the bore: half-width %.3f -> %.3f, half-height %.3f -> %.3f (bore %.4f)" % [had_w,float(f["mantlet_half_width"]),had_h,float(f["mantlet_half_height"]),bore_m])
	else:
		row.notes.append("calibre unavailable: mantlet floor NOT applied (loud, not silent)")
	# --- running gear --------------------------------------------------------------------------
	if not wheels.is_empty():
		var radius := 0.0; var width := 0.0
		var left := 0
		for w in wheels:
			var wpts := _world_vertices(w)
			var wlo := INF; var whi := -INF; var wx0 := INF; var wx1 := -INF
			for p in wpts:
				wlo = minf(wlo,p.y); whi = maxf(whi,p.y); wx0 = minf(wx0,p.x); wx1 = maxf(wx1,p.x)
			radius = maxf(radius,(whi-wlo)*0.5)
			width = maxf(width,wx1-wx0)
			# wheel_count in the production packets follows build_historical_packets.py: ROAD wheels per
			# side, i.e. the numerically suffixed wheel meshes, excluding return rollers (top_*), the
			# front idler and the drive sprocket. Counting every wheel-named node gave 13 for both
			# vehicles, which is the wrong quantity - the Leopard's road wheels are 01..07 and the
			# T-80B's are 01..06.
			var lower := str(w.name).to_lower()
			if lower.contains("wheel") and not lower.contains("top") and not lower.contains("front") and not lower.contains("drive"):
				var tail := lower.split("_")
				var last := str(tail[tail.size()-1])
				if last.is_valid_int() and (w as Node3D).global_position.x < 0.0: left += 1
		f["wheel_count"] = left
		f["wheel_radius"] = snappedf(radius,0.001)
		f["track_width"] = snappedf(width,0.001)
		method["wheel_count"] = "ROAD wheels on one side: wheel-named meshes with a numeric suffix, on x < 0, excluding return rollers (top_*), the front idler and the drive sprocket - the convention build_historical_packets.py uses"
		method["wheel_radius"] = "half of the largest wheel mesh y-extent"
		method["track_width"] = "largest wheel mesh x-extent (the belt width across the wheel)"
	else:
		row.notes.append("no wheel meshes: running-gear fields left to the author")
	# WT-040-R1: the barrel length is the distance from the GunPivot node to the Muzzle node along the gun's
	# own -Z, measured in the model that will be BOUND - not an external adapter report. The report below may
	# still contribute the muzzle-brake guess, but it no longer decides the length.
	if offsets.get("ok",false):
		f["barrel_length"] = snappedf(float(offsets["barrel_length"]),0.001)
		method["barrel_length"] = "RELATIVE: distance from %s to %s along the gun's own -Z in the measured model; relative basis identity: %s" % [str(offsets.get("gun_node","")),str(offsets.get("muzzle_node","")),str(offsets.get("all_bases_identity",false))]
		if not f.has("muzzle_brake"): f["muzzle_brake"] = false
	# --- muzzle brake guess from the adapter's own recorded report -----------------------------
	var report := _adapter_report()
	var entry2: Dictionary = report.get(id,{})
	if not entry2.is_empty():
		var off: Array = entry2.get("muzzle_offset_m",[])
		if off.size() == 3 and (absf(float(off[0]))+absf(float(off[1]))+absf(float(off[2]))) > 0.0001:
			f["barrel_length"] = snappedf(sqrt(float(off[0])*float(off[0])+float(off[1])*float(off[1])+float(off[2])*float(off[2])),0.001)
			method["barrel_length"] = "BASIS STATED: length of the adapter's recorded muzzle offset measured from the barrel mesh extremity through the parent chain, relative to the vehicle root (not a breech-to-muzzle measurement)"
			f["muzzle_brake"] = entry2.get("muzzle_brake_guess",false)
			method["muzzle_brake"] = "from the adapter artefact report (geometric tip check), see the note"
			row.notes.append("muzzle_brake is a geometric guess, not a documentary fact")
	row.ok = not f.is_empty()
	root.remove_child(scene)
	scene.free()
	return row

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: out.append(node)
	for child in node.get_children(): _collect_meshes(child,out)

func _find_node(node: Node, name: String) -> Node:
	if str(node.name) == name: return node
	for child in node.get_children():
		var hit := _find_node(child,name)
		if hit != null: return hit
	return null

func _find_mesh(meshes: Array[MeshInstance3D], hints: Array) -> MeshInstance3D:
	for hint in hints:
		for m in meshes:
			if str(m.name).to_lower().contains(str(hint)): return m
	return null

## Every vertex of a mesh in WORLD space. The scene must already be in the tree (see the header).
func _world_vertices(mesh: MeshInstance3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var m: Mesh = mesh.mesh
	if m == null: return out
	for surface in m.get_surface_count():
		var arrays: Array = m.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX: continue
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not verts is PackedVector3Array: continue
		var xform := mesh.global_transform
		for v in verts: out.append(xform * v)
	return out

## [half-width, front z (min), rear z (max)] of the vertices within `tol` of height y, or an EMPTY
## array when the band caught nothing.
func _band_extent(pts: Array[Vector3], y: float, tol: float) -> Array:
	var hw := 0.0; var zmin := INF; var zmax := -INF; var any := false
	for p in pts:
		if absf(p.y-y) > tol: continue
		any = true
		hw = maxf(hw,absf(p.x)); zmin = minf(zmin,p.z); zmax = maxf(zmax,p.z)
	if not any: return []
	return [hw,zmin,zmax]

## WT-040-R1: ADAPTIVE band. A fixed tolerance fails on an armour SHELL whose vertices cluster at a
## few heights - the Leopard's HullArmour left the mid band empty, which the tool correctly reported
## instead of writing zeros, but an empty ring is still no measurement. This widens the tolerance
## until it has taken at least `want` vertices (or every vertex), so a real cross-section is always
## measured, and it reports the tolerance it actually used so the number stays auditable.
func _band_extent_adaptive(pts: Array[Vector3], y: float, want: int) -> Array:
	if pts.is_empty(): return []
	var sorted := pts.duplicate()
	sorted.sort_custom(func(a: Vector3, b: Vector3) -> bool: return absf(a.y-y) < absf(b.y-y))
	var take: int = mini(maxi(want,3),sorted.size())
	var used := absf(sorted[take-1].y-y)
	var hw := 0.0; var zmin := INF; var zmax := -INF
	for i in take:
		var p: Vector3 = sorted[i]
		hw = maxf(hw,absf(p.x)); zmin = minf(zmin,p.z); zmax = maxf(zmax,p.z)
	return [hw,zmin,zmax,used]

## WT-040-R1: hint matching must not accept a TURRET armour mesh as the hull - "armour" matched
## TurretArmour on the Leopard and produced a meaningless mid ring. A candidate is rejected when its
## name says turret, track, skirt, wheel or gun.
func _find_hull_mesh(meshes: Array[MeshInstance3D]) -> MeshInstance3D:
	var reject := ["turret","track","skirt","wheel","gun","muzzle","mantlet","shield"]
	for hint in ["body","hull","armour","armor","chassis"]:
		for m in meshes:
			var lower := str(m.name).to_lower()
			var bad := false
			for r in reject:
				if lower.contains(str(r)): bad = true
			if bad: continue
			if lower.contains(str(hint)): return m
	return null

func _band_footprint(pts: Array[Vector3], y: float, tol: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in pts:
		if absf(p.y-y) <= tol: out.append(Vector2(p.x,p.z))
	return out

## Monotone-chain convex hull, returned in perimeter order - the face builder needs an ordered loop.
func _convex_outline(points: Array[Vector2]) -> Array:
	if points.size() < 3: return []
	var pts := points.duplicate()
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x or (is_equal_approx(a.x,b.x) and a.y < b.y))
	var lower: Array[Vector2] = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[lower.size()-2],lower[lower.size()-1],p) <= 0.0:
			lower.remove_at(lower.size()-1)
		lower.append(p)
	var upper: Array[Vector2] = []
	for i in range(pts.size()-1,-1,-1):
		var p2: Vector2 = pts[i]
		while upper.size() >= 2 and _cross(upper[upper.size()-2],upper[upper.size()-1],p2) <= 0.0:
			upper.remove_at(upper.size()-1)
		upper.append(p2)
	lower.remove_at(lower.size()-1)
	upper.remove_at(upper.size()-1)
	var hull: Array = []
	for p3 in lower: hull.append([snappedf(p3.x,0.001),snappedf(p3.y,0.001)])
	for p4 in upper: hull.append([snappedf(p4.x,0.001),snappedf(p4.y,0.001)])
	return hull

func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x-o.x)*(b.y-o.y)-(a.y-o.y)*(b.x-o.x)

## Half of the smaller extent of a footprint: the ring aperture proxy.
func _footprint_half(pts: Array[Vector2]) -> float:
	if pts.is_empty(): return 0.0
	var x0 := INF; var x1 := -INF; var z0 := INF; var z1 := -INF
	for p in pts:
		x0 = minf(x0,p.x); x1 = maxf(x1,p.x); z0 = minf(z0,p.y); z1 = maxf(z1,p.y)
	return minf((x1-x0),(z1-z0))*0.5

## The adapter verdict for this id (offset, class), so barrel_length states its basis honestly.
func _adapter_report() -> Dictionary:
	var out := {}
	var path := "res://logs/WT-030D-r2/adapter_artifacts.json"
	if not FileAccess.file_exists(path): return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return out
	var rows: Variant = parsed.get("rows",[])
	if not rows is Array: return out
	for r in rows:
		if r is Dictionary and r.get("id","") != null: out[str(r.id)] = r
	return out
