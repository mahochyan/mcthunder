extends SceneTree
## WT-040-R1 step 3: draft the modules component the same way as crew - the project's own vocabulary,
## positions derived from the measured boxes and labelled as such, and one hard rule honoured exactly:
## the ammunition capacities must sum to the runtime round count (the validator compares them).
##
## Kinds follow the production packets: ammo, engine, transmission, fuel, breech, turret_drive, track.
## The loadout split mirrors theirs (a ready rack plus hull racks) and the two hull racks are sized so
## the total is EXACTLY the dossier's main-gun capacity - 38 for the T-80B, 42 for the Leopard.
##
## Usage: -s res://tests/build_modern_modules_draft.gd
const GEOMETRY := "res://logs/WT-040-R1/modern_geometry_draft.json"
const FACTS := "res://logs/WT-040-R1/modern_facts_draft.json"
const OUT := "res://logs/WT-040-R1/modern_modules_draft.json"
const READY_RACK := 10
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var geo := {}
	for r in _read(GEOMETRY).get("rows",[]):
		if r is Dictionary: geo[str(r.get("id",""))] = r.get("fields",{})
	var facts := {}
	for f in _read(FACTS).get("rows",[]):
		if f is Dictionary: facts[str(f.get("id",""))] = f
	var rows: Array[Dictionary] = []
	for id in facts.keys():
		rows.append(_build(str(id),geo.get(id,{}),facts[id]))
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"modules component draft: project vocabulary, positions DERIVED from the measured boxes, ammunition split so the capacities sum EXACTLY to runtime.rounds",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[mods] wrote ",OUT)
	print("MODERN_MODULES_DRAFT_DONE")
	quit(0)

func _build(id: String, g: Dictionary, f: Dictionary) -> Dictionary:
	var out := {"id":id,"modules":[],"notes":[],"ammo_total":0}
	# measured basis for the derived placements
	var floor_y := 0.4
	var mid_y := 0.9
	var roof_y := 1.6
	var front_z := -3.0
	var rear_z := 3.0
	var half_w := 1.5
	if g.has("hull_rings") and (g.hull_rings as Array).size() == 3:
		var rings: Array = g.hull_rings
		floor_y = float((rings[0] as Array)[0])
		mid_y = float((rings[1] as Array)[0])
		roof_y = float((rings[2] as Array)[0])
		front_z = float((rings[1] as Array)[2])
		rear_z = float((rings[1] as Array)[3])
		half_w = float((rings[1] as Array)[1])
	var capacity: float = 0.0
	var cap_v: Variant = f.get("facts",{}).get("weapon.capacity",{}).get("value",null)
	if cap_v != null: capacity = float(cap_v)
	var total := int(capacity)
	var rest: int = maxi(total-READY_RACK,0)
	var half: int = int(rest/2)
	var other: int = rest-half
	out.ammo_total = READY_RACK+half+other if total >= READY_RACK else total
	# WT-040-R1: the split is arranged so the capacities sum EXACTLY to the main-gun capacity.
	if total < READY_RACK:
		out.notes.append("main-gun capacity %d is below the ready-rack size, so a single rack is used and the sum is still exact" % total)
		out.modules.append(_mod("ammo_ready","ammo","turret",[0.0,mid_y,0.0],[0.5,0.12,0.35],total))
	else:
		out.modules.append(_mod("ammo_ready","ammo","turret",[0.0,mid_y,0.0],[0.5,0.12,0.35],READY_RACK))
		out.modules.append(_mod("ammo_hull_left","ammo","hull",[-half_w*0.5,floor_y+0.2,0.0],[0.4,0.25,0.7],half))
		out.modules.append(_mod("ammo_hull_right","ammo","hull",[half_w*0.5,floor_y+0.2,0.0],[0.4,0.25,0.7],other))
	out.modules.append(_mod("engine","engine","hull",[0.0,mid_y,rear_z*0.45],[half_w*0.8,0.6,0.9]))
	out.modules.append(_mod("transmission","transmission","hull",[0.0,mid_y,rear_z*0.85],[half_w*0.8,0.4,0.5]))
	out.modules.append(_mod("fuel","fuel","hull",[-half_w*0.5,mid_y,rear_z*0.45],[0.25,0.45,0.7]))
	out.modules.append(_mod("breech","breech","turret",[0.0,mid_y,front_z*0.35],[0.4,0.4,0.6]))
	out.modules.append(_mod("turret_drive","turret_drive","hull",[0.0,roof_y-0.2,0.0],[0.6,0.2,0.6]))
	out.modules.append(_mod("track_left","track","hull",[-half_w*0.9,floor_y+0.2,0.0],[0.3,0.3,(rear_z-front_z)*0.8]))
	out.modules.append(_mod("track_right","track","hull",[half_w*0.9,floor_y+0.2,0.0],[0.3,0.3,(rear_z-front_z)*0.8]))
	out.notes.append("kinds follow the production packets (ammo, engine, transmission, fuel, breech, turret_drive, track)")
	out.notes.append("positions and sizes are DERIVED from the measured hull rings and turret origin - the dossiers carry no internal layout - and an author may replace them")
	out.notes.append("ammunition capacities sum to %d, the dossier's cited main-gun capacity, because the validator compares that total with runtime.rounds" % out.ammo_total)
	return out

func _mod(mid: String, kind: String, part: String, pos: Array, size: Array, cap: int = -1) -> Dictionary:
	var row := {"id":mid,"kind":kind,"part":part,
		"position":[snappedf(float(pos[0]),0.01),snappedf(float(pos[1]),0.01),snappedf(float(pos[2]),0.01)],
		"size":[snappedf(float(size[0]),0.01),snappedf(float(size[1]),0.01),snappedf(float(size[2]),0.01)],
		"external":false,"derived":true}
	if cap >= 0: row["ammo_capacity"] = cap
	return row

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
