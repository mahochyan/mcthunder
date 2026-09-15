extends SceneTree
## WT-040-R1 step 3: turn "what is still missing" into the validator's OWN list instead of my prose.
##
## The draft geometry measured from the artefact is fed into a packet whose other required components
## are present but EMPTY, purely so that VehicleContentPipeline.validate_package reports every missing
## runtime field, every missing armour zone and any geometry complaint in one run. This is a GAP
## AUDIT, not a claim of completeness: the placeholders are empty on purpose and the packet is never
## registered, written or admitted.
##
## Usage: -s res://tests/check_modern_package_gaps.gd
const DRAFT := "res://logs/WT-040-R1/modern_geometry_draft.json"
const FACTS := "res://logs/WT-040-R1/modern_facts_draft.json"
const CREW := "res://logs/WT-040-R1/modern_crew_draft.json"
const MODULES := "res://logs/WT-040-R1/modern_modules_draft.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var draft := _read_json(DRAFT)
	var rows: Array = draft.get("rows",[])
	if rows.is_empty(): print("[gaps] no draft geometry found"); quit(1); return
	# WT-040-R1: the cited facts draft is merged in, so the gap count can be watched FALLING as real
	# fields arrive instead of the audit always reporting the same wall of missing keys.
	var facts_by_id := {}
	var runtime_by_id := {}
	var assembly_by_id := {}
	var crew_by_id := {}
	var modules_by_id := {}
	for c in _read_json(CREW).get("rows",[]):
		if c is Dictionary: crew_by_id[str(c.get("id",""))] = c.get("crew",[])
	for m in _read_json(MODULES).get("rows",[]):
		if m is Dictionary: modules_by_id[str(m.get("id",""))] = m.get("modules",[])
	for f in _read_json(FACTS).get("rows",[]):
		if not f is Dictionary: continue
		facts_by_id[str(f.get("id",""))] = f.get("facts",{})
		runtime_by_id[str(f.get("id",""))] = f.get("runtime",{})
		# WT-040-R1: the assembly component draft has to reach the packet too - the runtime values
		# closed as soon as they were wired in, and leaving assembly out repeated the same wiring
		# mistake the audit had just taught me about.
		assembly_by_id[str(f.get("id",""))] = f.get("assembly",{})
	for row in rows:
		var id := str(row.get("id",""))
		var packet := {
			"id": id,
			"display_name": id,
			"geometry": row.get("fields",{}),
			"runtime": runtime_by_id.get(id,{}),
			"armor": {},
			"modules": modules_by_id.get(id,[]),
			"crew": crew_by_id.get(id,[]),
			# WT-040-R1: the validator checks SHAPE before content, so empty-but-shape-valid
			# placeholders are supplied for the fields that are not measured yet. They are deliberately
			# empty: the point is to reach the content checks and let the validator itself enumerate the
			# missing runtime fields and armour zones instead of me describing them.
			"facts": facts_by_id.get(id,{}),
			"sources": {},
			"assembly": assembly_by_id.get(id,{}),
			"compatible_shells": [],
			"license": "<GAP AUDIT PLACEHOLDER - not a licence decision>",
		}
		print("[gaps] ===== ", id)
		var result := VehicleContentPipeline.validate_package(packet,{})
		print("[gaps] ok=", result.get("ok",false))
		var errors: Array = result.get("errors",[])
		print("[gaps] error count=", errors.size())
		var groups := {}
		for e in errors:
			var text := str(e)
			var head := text.split(":")[0]
			groups[head] = int(groups.get(head,0)) + 1
		for key in groups:
			print("[gaps]   ", key, " → ", groups[key], " 项")
		for e2 in errors:
			print("[gaps]     - ", str(e2))
	print("MODERN_PACKAGE_GAP_AUDIT_DONE")
	quit(0)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
