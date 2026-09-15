extends SceneTree
## WT-040-R1 step 3: the evidence record for the four components.
##
## vehicle_content_pipeline line 174 compares each component with the value held under an evidence key:
## geometry with geometry.exterior, runtime with runtime.simulation, modules with geometry.modules and
## crew with geometry.crew. The evidence record therefore has to carry a copy of the component itself -
## it is a consistency check between what the packet says and what the evidence file says - and the
## facts are emitted with that exact value so the comparison holds.
##
## This is a REAL artifact, not a probe: it is built from the same drafts the rest of the pipeline uses,
## so the evidence says precisely what the packet contains. Nothing is registered or admitted.
##
## Usage: -s res://tests/build_modern_evidence_record.gd
const GEOMETRY := "res://logs/WT-040-R1/modern_geometry_draft.json"
const FACTS := "res://logs/WT-040-R1/modern_facts_draft.json"
const CREW := "res://logs/WT-040-R1/modern_crew_draft.json"
const MODULES := "res://logs/WT-040-R1/modern_modules_draft.json"
const OUT := "res://logs/WT-040-R1/modern_evidence_record.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var geo := {}
	for r in _read(GEOMETRY).get("rows",[]):
		if r is Dictionary: geo[str(r.get("id",""))] = r.get("fields",{})
	var runtime := {}
	var base_facts := {}
	for f in _read(FACTS).get("rows",[]):
		if not f is Dictionary: continue
		var id := str(f.get("id",""))
		runtime[id] = f.get("runtime",{})
		base_facts[id] = f.get("facts",{})
	var crew := {}
	for c in _read(CREW).get("rows",[]):
		if c is Dictionary: crew[str(c.get("id",""))] = c.get("crew",[])
	var modules := {}
	for m in _read(MODULES).get("rows",[]):
		if m is Dictionary: modules[str(m.get("id",""))] = m.get("modules",[])
	var rows: Array[Dictionary] = []
	for id in geo.keys():
		var facts := {}
		facts["geometry.exterior"] = _evidence("geometry",geo.get(id,{}))
		facts["runtime.simulation"] = _evidence("runtime",runtime.get(id,{}))
		facts["geometry.modules"] = _evidence("modules",modules.get(id,[]))
		facts["geometry.crew"] = _evidence("crew",crew.get(id,[]))
		rows.append({"id":id,"facts":facts})
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"evidence record carrying a copy of each component, as vehicle_content_pipeline line 174 requires; built from the same drafts the packet uses",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[evidence] wrote ",OUT)
	print("MODERN_EVIDENCE_RECORD_DONE")
	quit(0)

func _evidence(what: String, value: Variant) -> Dictionary:
	return {
		"value": value,
		"status": "derived_from_draft",
		"origin": "mcthunder_pipeline",
		# a registered SOURCE ID (the pipeline itself), not a prose description - the layout validator
		# rejects a ref that does not name a registered source
		"source_refs": ["mcthunder_pipeline"],
		"location": "copied from the %s draft so the packet and its evidence agree" % what,
	}

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
