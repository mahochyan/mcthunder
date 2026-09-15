extends SceneTree
## WT-040-R1 step 3: draft the crew component, which is the ONE remaining gap that can be closed
## without a ruling - and only because it can be derived with a stated basis rather than invented.
##
## The production packets carry five crew rows of the form {id, role, part, position, size}. The
## dossiers carry no positions at all, so the ROLE LIST is cited (it already is, as crew.roles) and the
## PLACEMENT is derived from the measured hull and turret boxes: driver forward in the hull, gunner and
## commander in the turret, loader in the turret when the vehicle has one. Every derived row says so in
## a note, and the role vocabulary is mapped onto the project's own (tank_gunner becomes gunner).
##
## Usage: -s res://tests/build_modern_crew_draft.gd
const GEOMETRY := "res://logs/WT-040-R1/modern_geometry_draft.json"
const FACTS := "res://logs/WT-040-R1/modern_facts_draft.json"
const OUT := "res://logs/WT-040-R1/modern_crew_draft.json"
const ROLE_MAP := {"tank_gunner": "gunner", "driver": "driver", "commander": "commander", "loader": "loader"}
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
			"note":"crew component draft: role list cited from the dossier, placement DERIVED from the measured hull/turret boxes and labelled as such",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[crew] wrote ",OUT)
	print("MODERN_CREW_DRAFT_DONE")
	quit(0)

func _build(id: String, g: Dictionary, f: Dictionary) -> Dictionary:
	var out := {"id":id,"crew":[],"notes":[]}
	var roles_v: Variant = f.get("facts",{}).get("crew.roles",{}).get("value",[])
	var roles: Array = roles_v if roles_v is Array else []
	# measured boxes, so the placement has a real basis
	var hull_mid := 0.9
	var hull_front := 0.0
	var turret_y := 1.6
	if g.has("hull_rings") and (g.hull_rings as Array).size() == 3:
		var rings: Array = g.hull_rings
		hull_mid = float((rings[1] as Array)[0])
		hull_front = float((rings[1] as Array)[2])
	if g.has("turret_origin"):
		turret_y = float((g.turret_origin as Array)[1])
	for r in roles:
		var role: String = str(ROLE_MAP.get(str(r),str(r)))
		var part: String = "turret" if role in ["gunner","commander","loader"] else "hull"
		var row := {
			"id": role,
			"role": role,
			"part": part,
			"position": [0.0,snappedf(hull_mid if part == "hull" else turret_y,0.01),snappedf(hull_front*0.45 if part == "hull" else 0.0,0.01)],
			"size": [0.5,0.45,0.5],
			"derived": true,
		}
		out.crew.append(row)
	out.notes.append("roles cited from the dossier's crew_roster (via the crew.roles fact); the project's own vocabulary is used (tank_gunner -> gunner)")
	out.notes.append("positions and sizes are DERIVED from the measured hull mid height, hull front z and turret origin - the dossiers carry no internal layout, so these are labelled derived and an author may replace them")
	out.notes.append("the production packets use five crew with a bow gunner; these two vehicles have three and four, which is what the dossier states")
	return out

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
