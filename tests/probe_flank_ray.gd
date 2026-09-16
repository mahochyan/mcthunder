extends SceneTree
## WT-040-R1: decide between the two remaining branches with a measurement, not an inference. The target in
## flank_hunter is the M4 at (0, 0.03, -20) with yaw PI, and the verifier's shot produced world contacts at
## (-0.868, 2.131, -20.405) and (0.895, 2.112, -20.310). This builds the SAME layout from the SAME packet,
## transforms every interior box to world space the way the layout defines it (a station's box is relative to
## its own part, so world = world_pose * part_bind * station_box) and slab-tests the segment against each box.
## If nothing is hit, the aim line genuinely misses and the fix is on the test side; if something is hit but
## the recorded damage was empty, the defect is in the interior eligibility path.
const PACKET := "res://configs/vehicles/historical/us_m4a3_75w_vvss_1944.json"
const TARGET_POS := Vector3(0, 0.03, -20)
const TARGET_YAW := PI
const P0 := Vector3(-0.868, 2.131, -20.405)
const P1 := Vector3(0.895, 2.112, -20.310)

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKET))
	if packet.is_empty(): print("[ray] packet missing"); quit(1); return
	var layout := HistoricalVehicleGeometry.build(packet)
	var world := Transform3D(Basis(Vector3.UP, TARGET_YAW), TARGET_POS)
	var part_world := {}
	for part in layout.parts:
		part_world[str(part.id)] = world * part.bind_local
	print("[ray] parts=", part_world.keys())
	var direction := (P1 - P0)
	var length := direction.length()
	var dir := direction / length
	print("[ray] segment length=%.3f m  P0=%s  P1=%s" % [length, str(P0), str(P1)])
	var hits: Array = []
	for station in layout.crew_stations:
		hits.append([str(station.id), str(station.part_id), station.size_m, station.local_box_transform, station])
	for module in layout.modules:
		hits.append([str(module.id), str(module.part_id), module.size_m, module.local_box_transform, module])
	for row in hits:
		var id := str(row[0]); var part := str(row[1]); var size: Vector3 = row[2]
		var local_xf: Transform3D = row[3]
		if not part_world.has(part):
			print("  %-16s part=%s NO PART TRANSFORM" % [id, part]); continue
		var box_world: Transform3D = (part_world[part] as Transform3D) * local_xf
		var inv := box_world.affine_inverse()
		var o := inv * P0
		var d := (inv.basis * dir)
		var half := size * 0.5
		var tmin := 0.0; var tmax := length; var ok := true
		for axis in 3:
			var oa: float = o[axis]; var da: float = d[axis]; var ha: float = half[axis]
			if absf(da) < 1e-6:
				if oa < -ha or oa > ha: ok = false; break
			else:
				var t1 := (-ha - oa) / da; var t2 := (ha - oa) / da
				if t1 > t2: var tmp := t1; t1 = t2; t2 = tmp
				tmin = maxf(tmin, t1); tmax = minf(tmax, t2)
				if tmin > tmax: ok = false; break
		if ok:
			print("  HIT  %-16s part=%-8s size=%s  entry_t=%.3f m" % [id, part, str(size), tmin])
	print("[ray] interior boxes hit: (see HIT lines above)")
	print("FLANK_RAY_PROBE_DONE")
	quit(0)