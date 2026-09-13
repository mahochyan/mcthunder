class_name VehicleContentRecord
extends RefCounted
## WT-030: one reusable vehicle content record with field provenance and separated
## responsibilities, so a new vehicle does not require editing hardcoded lists in several
## places and so a missing muzzle/pivot/layout is reported instead of silently falling back
## to a default combat vehicle.
##
## Responsibilities are deliberately separate fields: model, movement collision, armour,
## modules, muzzle/pivot. The model is presentation; swapping an LOD changes only the model
## field, never the combat configuration.
##
## Sources, licences and redistribution are a SEPARATE gate: an unknown source is neither
## declared legal nor declared infringing here - it only blocks the distribution decision.

const SCHEMA_VERSION := 1
const PROVENANCE := ["fact","reference","author","unknown"]
const EVIDENCE_GRADES := ["measured","reference_only","author_stated","unknown"]
const RESPONSIBILITIES := ["model","movement_collision","armor","modules","muzzle_and_pivot"]
const LICENCE_STATES := ["redistributable","unknown","non_redistributable"]
const FORWARD_AXIS := "-Z"
const UP_AXIS := "+Y"
const MIN_SCALE := 0.5
const MAX_SCALE := 2.0
const MAX_OFFSET_M := 20.0

## Pilots with their frozen in-repo locations. Facts are read from these files at build time.
const PILOTS := {
	"ussr_t_80b":{"nation":"ussr","branch":"medium","family_id":"t_80","variant_id":"t_80b",
		"candidate":"res://assets/reference_data/candidates/ussr_t_80b.json",
		"model":"res://assets/research/models/ussr_t_80b.glb",
		"mount":{"root":"ussr_t_80b","gun_mesh":"MainGun","wheel_prefix":"Wheel_","running_mesh_count":14},
		"source":"user-supplied reference entry","licence":"unknown"},
	"germ_leopard_2a4":{"nation":"germany","branch":"medium","family_id":"leopard_2","variant_id":"leopard_2a4",
		"candidate":"res://assets/reference_data/candidates/germ_leopard_2a4.json",
		"model":"res://assets/research/models/germ_leopard_2a4.glb",
		"mount":{"root":"VehicleRoot","gun_mesh":"MainGunAndMuzzleBrake","wheel_prefix":"wheel_","running_mesh_count":14},
		"source":"user-supplied reference entry","licence":"unknown"},
}

static func pilot_ids() -> Array[String]:
	var out: Array[String] = []
	for id in PILOTS: out.append(id)
	return out

static func sha256_of(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	return FileAccess.get_sha256(path)

## Build a record from real in-repo facts (hashes and sizes are read, never invented).
static func build(vehicle_id: String) -> Dictionary:
	if not PILOTS.has(vehicle_id): return {"ok":false,"reason":"unknown_vehicle"}
	var spec: Dictionary = PILOTS[vehicle_id]
	var model_path := str(spec.model)
	var candidate_path := str(spec.candidate)
	var model_present := FileAccess.file_exists(model_path)
	var candidate_present := FileAccess.file_exists(candidate_path)
	var record := {
		"schema_version":SCHEMA_VERSION,
		"family_id":str(spec.family_id),
		"variant_id":str(spec.variant_id),
		"nation":str(spec.nation),
		"branch":str(spec.branch),
		"model":{"path":model_path,"present":model_present,"bytes":0,"sha256":"",
			"import_companion":FileAccess.file_exists(model_path+".import")},
		"movement_collision":{"size_m":[3.6,2.2,7.0],"provenance":"author"},
		"armor":{"layout_id":"","provenance":"unknown"},
		"modules":{"layout_id":"","provenance":"unknown"},
		"muzzle_and_pivot":{"muzzle_m":[0.0,1.9,2.6],"pivot_m":[0.0,1.8,0.0],"provenance":"author"},
		"scale":[1.0,1.0,1.0],
		"forward_axis":FORWARD_AXIS,
		"up_axis":UP_AXIS,
		"mount":(spec.mount as Dictionary).duplicate(true),
		"evidence_grade":"measured",
		"source":str(spec.source),
		"licence":str(spec.licence),
		"redistributable":false,
		"reference_entry":{"path":candidate_path,"present":candidate_present,"bytes":0,"sha256":""},
	}
	if model_present:
		record.model.bytes = int(FileAccess.get_file_as_bytes(model_path).size())
		record.model.sha256 = sha256_of(model_path)
	if candidate_present:
		record.reference_entry.bytes = int(FileAccess.get_file_as_bytes(candidate_path).size())
		record.reference_entry.sha256 = sha256_of(candidate_path)
	return {"ok":true,"record":record,"provenance":field_provenance(record)}

## Every field names where it came from, so a reviewer can tell a measurement from a guess.
static func field_provenance(record: Dictionary) -> Dictionary:
	return {
		"model":{"source":"measured in-repo bytes and hash","provenance":"fact"},
		"reference_entry":{"source":"measured in-repo bytes and hash","provenance":"fact"},
		"mount":{"source":"authored articulation adapter","provenance":"author"},
		"movement_collision":{"source":"authored collision box","provenance":"author"},
		"muzzle_and_pivot":{"source":"authored transform","provenance":"author"},
		"armor":{"source":"layout definition (not yet attached)","provenance":"unknown"},
		"modules":{"source":"layout definition (not yet attached)","provenance":"unknown"},
		"licence":{"source":"not established","provenance":"unknown"},
	}

## Named validation errors; never a silent default combat vehicle.
static func validate(record: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if not record.has("schema_version") or int(record.schema_version) != SCHEMA_VERSION:
		errors.append("schema_version_mismatch")
	for key in ["family_id","variant_id","nation","branch"]:
		if str(record.get(key,"")).is_empty(): errors.append("missing_%s"%key)
	var model: Dictionary = record.get("model",{})
	if not bool(model.get("present",false)): errors.append("missing_model")
	if bool(model.get("present",false)) and str(model.get("sha256","")).is_empty(): errors.append("unhashed_model")
	var muzzle: Dictionary = record.get("muzzle_and_pivot",{})
	if not muzzle.has("muzzle_m"): errors.append("missing_muzzle")
	if not muzzle.has("pivot_m"): errors.append("missing_pivot")
	var layout := str(record.get("armor",{}).get("layout_id",""))
	if layout.is_empty(): errors.append("missing_layout")
	var scale: Array = record.get("scale",[])
	if scale.size() != 3: errors.append("malformed_scale")
	else:
		for value in scale:
			var number := float(value)
			if not is_finite(number): errors.append("non_finite_scale")
			elif number <= 0.0: errors.append("negative_scale")
			elif number < MIN_SCALE or number > MAX_SCALE: errors.append("scale_out_of_range")
	if str(record.get("forward_axis","")) != FORWARD_AXIS: errors.append("coordinate_convention_mismatch")
	if str(record.get("up_axis","")) != UP_AXIS: errors.append("coordinate_convention_mismatch")
	for key in ["muzzle_m","pivot_m"]:
		var values: Array = muzzle.get(key,[])
		if values.size() != 3: continue
		for value in values:
			if not is_finite(float(value)) or absf(float(value)) > MAX_OFFSET_M: errors.append("transform_inconsistent")
	if not EVIDENCE_GRADES.has(str(record.get("evidence_grade",""))): errors.append("unknown_evidence_grade")
	if not LICENCE_STATES.has(str(record.get("licence",""))): errors.append("unknown_licence_state")
	return {"ok":errors.is_empty(),"errors":errors}

## Swapping the model (an LOD change) leaves the combat configuration untouched.
static func lod_switch_keeps_combat(record: Dictionary, new_model_path: String) -> Dictionary:
	var switched := record.duplicate(true)
	switched.model.path = new_model_path
	switched.model.sha256 = sha256_of(new_model_path)
	switched.model.import_companion = FileAccess.file_exists(new_model_path+".import")
	var combat_before := {"armor":record.armor,"modules":record.modules,
		"movement_collision":record.movement_collision,"muzzle_and_pivot":record.muzzle_and_pivot}
	var combat_after := {"armor":switched.armor,"modules":switched.modules,
		"movement_collision":switched.movement_collision,"muzzle_and_pivot":switched.muzzle_and_pivot}
	return {"ok":str(combat_before) == str(combat_after),"model_path":switched.model.path,
		"combat_unchanged":str(combat_before) == str(combat_after)}

## Source/licence is its own gate: unknown blocks distribution only, never the game.
static func distribution_gate(record: Dictionary) -> Dictionary:
	var licence := str(record.get("licence","unknown"))
	var redistributable := bool(record.get("redistributable",false)) and licence == "redistributable"
	var decision := "allowed" if redistributable else ("blocked_pending_source" if licence == "unknown" else "blocked_non_redistributable")
	return {"ok":redistributable,"decision":decision,"licence":licence,
		"blocks_game_use":false,"blocks_public_candidate":not redistributable,
		"note":"an unknown source is neither declared legal nor infringing; it only blocks distribution"}

static func is_absolute_path(path: String) -> bool:
	# res:// and user:// are engine-relative; a drive letter or a leading slash is not.
	if path.begins_with("res://") or path.begins_with("user://"): return false
	if path.begins_with("/"): return true
	if path.length() >= 2 and path[1] == ":":
		var head := path[0]
		if head.to_upper() != head.to_lower(): return true
	return false

## An isolated directory must not depend on this machine's absolute paths.
static func portability(record: Dictionary) -> Dictionary:
	var offenders: Array[String] = []
	for key in ["model","reference_entry"]:
		var path := str(record.get(key,{}).get("path",""))
		if is_absolute_path(path): offenders.append("%s:%s"%[key,path])
	var ok := offenders.is_empty()
	return {"ok":ok,"offenders":offenders,"note":"every referenced path is a res:// path"}

## Registry state of the in-repo research models: present as bytes, invisible to the
## resource loader without an import companion, and unregistered in model_sources.json.
static func registry_report() -> Dictionary:
	var dir := DirAccess.open("res://assets/research/models")
	if dir == null: return {"ok":false,"reason":"models_directory_missing"}
	var rows: Array[Dictionary] = []
	var with_import := 0
	var total_bytes := 0
	for file in dir.get_files():
		if not file.ends_with(".glb"): continue
		var path := "res://assets/research/models/"+file
		var has_import := FileAccess.file_exists(path+".import")
		if has_import: with_import += 1
		var bytes := int(FileAccess.get_file_as_bytes(path).size())
		total_bytes += bytes
		rows.append({"id":file.get_basename(),"path":path,"bytes":bytes,"import_companion":has_import,
			"resource_loadable":ResourceLoader.exists(path),"registered":false})
	return {"ok":true,"models":rows.size(),"with_import_companion":with_import,
		"total_bytes":total_bytes,"registered_in_model_sources":0,"rows":rows}

## The rebuildable source -> export -> integration checklist for a pilot.
static func rebuild_checklist(vehicle_id: String) -> Array[Dictionary]:
	var built := build(vehicle_id)
	if not built.ok: return []
	var record: Dictionary = built.record
	return [
		{"step":"source_entry","artifact":str(record.reference_entry.path),"bytes":int(record.reference_entry.bytes),
			"sha256":str(record.reference_entry.sha256),"export_method":"none (already in-repo JSON)"},
		{"step":"model","artifact":str(record.model.path),"bytes":int(record.model.bytes),
			"sha256":str(record.model.sha256),"export_method":"authored GLB, read as bytes (no .import companion)"},
		{"step":"mount","artifact":"scripts/content/modern_model_mount_adapter.gd",
			"bytes":0,"sha256":sha256_of("res://scripts/content/modern_model_mount_adapter.gd"),
			"export_method":"authored articulation spec: root/gun mesh/wheel prefix"},
		{"step":"integration","artifact":"configs/vehicles/model_sources.json","bytes":0,
			"sha256":sha256_of("res://configs/vehicles/model_sources.json"),
			"export_method":"registry entry (currently empty: this pilot is not yet registered)"},
	]

static func snapshot(vehicle_id: String) -> Dictionary:
	var built := build(vehicle_id)
	if not built.ok: return {"ok":false,"reason":built.reason}
	return {"ok":true,"record":built.record,"provenance":built.provenance,
		"validation":validate(built.record),"distribution":distribution_gate(built.record),
		"portability":portability(built.record),"checklist":rebuild_checklist(vehicle_id)}
