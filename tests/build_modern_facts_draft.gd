extends SceneTree
## WT-040-R1 step 3: build the facts draft from the dossier's OWN normalized candidate layer.
##
## The dossiers carry a `fields` array whose entries have a stable `key`, an SI-unit
## `candidate_value`, an explicit `historical_verified` flag and a `locator` naming the group, line and
## section - that locator is exactly the citation a fact needs, so facts are built from THAT layer
## rather than from the raw text. Only decision-independent keys are emitted here: mobility and weapon
## figures that the dossier states outright. Armour is NOT emitted, because the zone mapping is still
## awaiting review, and dimensions are NOT emitted, because the dossiers do not contain them and using
## my own measurement as the "reference" would make the validator's sixteen percent envelope check
## circular.
##
## Nothing is registered, written into a config or admitted: this is a draft beside the geometry draft.
##
## Usage: -s res://tests/build_modern_facts_draft.gd -- <id>=<dossier json> [...]
const OUT := "res://logs/WT-040-R1/modern_facts_draft.json"
const SOURCE_LABEL := "warthunder_reference"
const SOURCE_VERSION := "2.57.1.137"
## candidate key -> project fact key, with the note that goes into the fact
const MAPPED := {
	"drive.forward_speed_candidate": "mobility.forward_speed_mps",
	"drive.reverse_speed_candidate": "runtime.reverse_max_speed",
	"drive.hull_turn_candidate": "runtime.hull_turn_speed",
	"drive.design_mass": "mobility.design_mass_kg",
	"drive.engine": "mobility.engine",
}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): print("[facts] no target"); quit(1); return
	var rows: Array[Dictionary] = []
	for arg in args:
		var parts := str(arg).split("=",true,1)
		if parts.size() != 2: print("[facts] bad arg ",str(arg)); continue
		rows.append(_build(parts[0],parts[1]))
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema":1,
			"note":"facts draft built from the dossiers' normalized candidate layer; each fact carries its locator; armour and dimensions deliberately absent (see header)",
			"rows":rows}, "  ")+"\n")
		file.close()
		print("[facts] wrote ",OUT)
	print("MODERN_FACTS_DRAFT_DONE")
	quit(0)

func _build(id: String, path: String) -> Dictionary:
	var row := {"id":id,"dossier":path,"facts":{},"emitted":[],"skipped":[],"notes":[]}
	if not FileAccess.file_exists(path):
		row.notes.append("dossier missing"); return row
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		row.notes.append("dossier unparsable"); return row
	var fields: Variant = parsed.get("fields",[])
	if not fields is Array:
		row.notes.append("no candidate field layer"); return row
	for entry in fields:
		if not entry is Dictionary: continue
		var key := str(entry.get("key",""))
		var value: Variant = entry.get("candidate_value",null)
		if not MAPPED.has(key): continue
		if value == null:
			row.skipped.append(key+" (no candidate value)")
			continue
		var locator: Array = entry.get("locator",[])
		var where := ""
		var line := -1
		if not locator.is_empty() and locator[0] is Dictionary:
			line = int(locator[0].get("line",-1))
			where = "%s line %d (%s)" % [SOURCE_LABEL,line,str(locator[0].get("section",""))]
		var fact_key := str(MAPPED[key])
		row.facts[fact_key] = {
			"value": value,
			"status": "reference",
			"origin": SOURCE_LABEL,
			"source_refs": ["wt-%s#L%d" % [SOURCE_VERSION,line]],
			"location": "%s: %s = %s" % [where,key,str(value)],
		}
		row.emitted.append(fact_key+" ← "+key+" (line %d)" % line)
	# the same numeric value also satisfies the runtime fields the validator names explicitly
	var speed: Variant = row.facts.get("mobility.forward_speed_mps",{}).get("value",null)
	if speed != null:
		row.facts["runtime.forward_max_speed"] = {
			"value": speed, "status": "reference", "origin": SOURCE_LABEL,
			"source_refs": row.facts["mobility.forward_speed_mps"].source_refs,
			"location": "same figure as mobility.forward_speed_mps: the dossier's forward speed candidate",
		}
		row.emitted.append("runtime.forward_max_speed ← mobility.forward_speed_mps")
	# WT-040-R1 correction: the validator reads the VALUES from the `runtime` COMPONENT, while facts
	# supply provenance (and the keys other checks look up, such as mobility.forward_speed_mps). My
	# first version put runtime values into the facts dictionary only, and the gap audit showed they
	# were still missing - a category error the audit caught, which is exactly why it exists.
	row.runtime = {}
	if speed != null:
		row.runtime["forward_max_speed"] = speed
		row.emitted.append("runtime component: forward_max_speed ← mobility.forward_speed_mps")
	var rev: Variant = row.facts.get("runtime.reverse_max_speed",{}).get("value",null)
	if rev != null:
		row.runtime["reverse_max_speed"] = rev
		row.emitted.append("runtime component: reverse_max_speed ← drive.reverse_speed_candidate")
	var turn: Variant = row.facts.get("runtime.hull_turn_speed",{}).get("value",null)
	if turn != null:
		row.runtime["hull_turn_speed"] = turn
		row.emitted.append("runtime component: hull_turn_speed ← drive.hull_turn_candidate")
	var accel: Variant = null
	for entry2 in fields:
		if entry2 is Dictionary and str(entry2.get("key","")) == "drive.acceleration_candidate":
			accel = entry2.get("candidate_value",null)
	if accel == null:
		# the dossier states deceleration/acceleration as "4.0 / 8.0" in the raw text; take the first
		# figure only if the candidate layer exposes it, otherwise leave it to design
		row.skipped.append("drive.acceleration_candidate absent: acceleration left to design")
	else:
		row.runtime["acceleration"] = accel
		row.emitted.append("runtime component: acceleration ← drive.acceleration_candidate")
	row.notes.append("armour facts are NOT emitted: the zone mapping is awaiting review")
	row.notes.append("dimensions facts are NOT emitted: the dossier has none, and my own measurement must not serve as the reference for a check that compares against it")
	row.notes.append("the dossier's own arcade power multiplier note is a warning, not a value to import")
	return row
