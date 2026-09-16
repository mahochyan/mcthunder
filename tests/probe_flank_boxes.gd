extends SceneTree
## WT-040-R1: the flank shot's outcome is now compressed to one measurable question - where are the target's
## interior boxes really, and which of them does the barrel line actually enter first? Three measured runs agree
## on the height (contact y 2.004 dev / 1.999 package) but disagree in depth by about 0.45 m, and a rearward aim
## at turret-local z 0.85 traversed two walls without touching the rack, so the packet's stated size cannot be
## the whole story. This prints, for every interior item, its world box from the layout itself, its turret-local
## z span, and the perpendicular distance and entry parameter of the line the PACKAGE actually fired along -
## the muzzle and aim point it printed. No scene is needed, so nothing is inferred from a different run.
const PACKET := "res://configs/vehicles/historical/us_m4a3_75w_vvss_1944.json"
const TARGET_POS := Vector3(0, 0.03, -20)
const TARGET_YAW := PI
# From the package run (10908aa5): [aim] camera=(-26.8473, 6.41, -21.41172) muzzle=(-13.47157, 2.24751, -20.88576)
# and the converged aim point was (-0.0, 1.99, -20.28) (rack centre, turret-local (0,0.08,0.7)).
const MUZZLE := Vector3(-13.47157, 2.24751, -20.88576)
const AIM := Vector3(-0.0, 1.99, -20.28)
# And the dev-tree run that DID credit ammo_ready, for contrast: muzzle=(-13.44369, 2.262987, -21.01591).
const MUZZLE_DEV := Vector3(-13.44369, 2.262987, -21.01591)

func _initialize() -> void: call_deferred("_run")

func _report(label: String, muzzle: Vector3) -> void:
	var dir := (AIM - muzzle).normalized()
	print("=== line ", label, "  muzzle=", muzzle, "  aim=", AIM, "  dir=", dir)
	var rows: Array = []
	for station in _layout.crew_stations: rows.append([str(station.id), str(station.part_id), station.size_m, station.local_box_transform])
	for module in _layout.modules: rows.append([str(module.id), str(module.part_id), module.size_m, module.local_box_transform])
	for row in rows:
		var id := str(row[0]); var part := str(row[1]); var size: Vector3 = row[2]
		var box_world: Transform3D = (_part_world[part] as Transform3D) * (row[3] as Transform3D)
		var centre := box_world.origin
		var to_c := centre - muzzle
		var t_c := to_c.dot(dir)
		var perp := (to_c - dir*t_c).length()
		# turret-local z span of the box, for the depth argument
		var zspan := "n/a"
		if part == "turret":
			var zc: float = (row[3] as Transform3D).origin.z
			zspan = "%.3f..%.3f" % [zc - size.z*0.5, zc + size.z*0.5]
		print("  %-16s part=%-8s size=%s  world_centre=%s  t=%.3f m  perp=%.4f m  turret_local_z=%s" % [
			id, part, str(size), str(centre.snapped(Vector3(0.001,0.001,0.001))), t_c, perp, zspan])

var _layout: Variant
var _part_world := {}

func _run() -> void:
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKET))
	if packet.is_empty(): print("[ray] packet missing"); quit(1); return
	_layout = HistoricalVehicleGeometry.build(packet)
	var world := Transform3D(Basis(Vector3.UP, TARGET_YAW), TARGET_POS)
	for part in _layout.parts: _part_world[str(part.id)] = world * part.bind_local
	print("[ray] target pose pos=", TARGET_POS, " yaw=", TARGET_YAW, " parts=", _part_world.keys())
	_report("PACKAGE (failed: hit loader, rack untouched)", MUZZLE)
	_report("DEV TREE (credited ammo_ready)", MUZZLE_DEV)
	print("FLANK_BOX_PROBE_DONE")
	quit(0)
