class_name AssetRegistryAudit
extends RefCounted
## WT-030D: the factual audit of `assets/vehicles/`, and the register of corrections it
## forced.
##
## This module exists because an earlier claim in this batch ("ZTZ-99A has no model in the
## repository", "M1A1 is an unintegrated LOD study", "the pilots only have research models")
## was made from a CONTENT grep, which cannot see file names. The real directory listing
## shows canonical GLBs with import companions for M1A1 and ZTZ-99A, and canonical copies of
## both pilots inside an ignored directory. This module measures the truth and records the
## corrections, so the frozen segment data can be corrected rather than left wrong.

const VEHICLE_DIRS := ["m1a1","ztz99a","leopard2a7v","modern_bound"]
const KNOWN_VEHICLES := {
	"us_m1a1_abrams":{"dir":"m1a1","canonical":"res://assets/vehicles/m1a1/m1a1.glb"},
	"cn_ztz_99a":{"dir":"ztz99a","canonical":"res://assets/vehicles/ztz99a/ztz99a_1000.glb"},
	"ussr_t_80b":{"dir":"modern_bound","canonical":"res://assets/vehicles/modern_bound/ussr_t_80b.glb"},
	"germ_leopard_2a4":{"dir":"modern_bound","canonical":"res://assets/vehicles/modern_bound/germ_leopard_2a4.glb"},
}

## Statements from earlier work orders that this audit could not confirm.
const CORRECTIONS := [
	{"earlier_claim":"cn_ztz_99a has no model in the repository",
		"evidence":"assets/vehicles/ztz99a/ztz99a_1000.glb (2,913,008 B) plus .import and a manifest",
		"corrected":"ZTZ-99A HAS a canonical GLB with an import companion and a manifest; what it lacks is a reference entry in the content tree",
		"source_order":"WT-029-R1"},
	{"earlier_claim":"us_m1a1_abrams is an unintegrated LOD study",
		"evidence":"assets/vehicles/m1a1/m1a1.glb and m1a1_1k.glb both carry .import companions (18,071,366 B total)",
		"corrected":"M1A1 HAS import-visible assets in the project; the isolated LOD study mentioned in the plan is a different artifact",
		"source_order":"WT-029-R1"},
	{"earlier_claim":"the two pilots only have research models",
		"evidence":"assets/vehicles/modern_bound/{ussr_t_80b,germ_leopard_2a4}.glb exist, but the directory carries .gdignore",
		"corrected":"canonical copies exist for both pilots, deliberately hidden from the resource loader by .gdignore; the research copies remain byte-only",
		"source_order":"WT-030-R1"},
]

static func file_facts(path: String) -> Dictionary:
	var present := FileAccess.file_exists(path)
	return {"path":path,"present":present,
		"bytes":int(FileAccess.get_file_as_bytes(path).size()) if present else 0,
		"sha256":FileAccess.get_sha256(path) if present else "",
		"import_companion":FileAccess.file_exists(path+".import")}

static func dir_facts(dir_name: String) -> Dictionary:
	var base := "res://assets/vehicles/"+dir_name
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(base)):
		return {"dir":base,"present":false,"files":0}
	var files: Array[Dictionary] = []
	var total := 0
	var dir := DirAccess.open(base)
	if dir != null:
		for file in dir.get_files():
			var path := base+"/"+file
			var bytes := int(FileAccess.get_file_as_bytes(path).size())
			total += bytes
			files.append({"name":file,"bytes":bytes,"import_companion":FileAccess.file_exists(path+".import")})
	return {"dir":base,"present":true,"gdignore":FileAccess.file_exists(base+"/.gdignore"),
		"files":files.size(),"total_bytes":total,"entries":files}

static func vehicle_facts(vehicle_id: String) -> Dictionary:
	if not KNOWN_VEHICLES.has(vehicle_id): return {"ok":false,"reason":"unknown_vehicle"}
	var spec: Dictionary = KNOWN_VEHICLES[vehicle_id]
	var canonical := file_facts(str(spec.canonical))
	var dir := dir_facts(str(spec.dir))
	var manifest := file_facts(str(spec.canonical).get_basename()+".manifest.json")
	return {"ok":true,"vehicle_id":vehicle_id,"canonical":canonical,"directory":dir,
		"manifest":manifest,"dir_ignored":bool(dir.get("gdignore",false))}

## Can this vehicle be registered as a bound model today? The consumer requires a canonical
## `assets/vehicles/` path, an explicit model_binding in the packet, and three source fields.
static func registry_eligibility(vehicle_id: String) -> Dictionary:
	var facts := vehicle_facts(vehicle_id)
	if not facts.ok: return {"ok":false,"reason":"unknown_vehicle"}
	var blockers: Array[String] = []
	if not bool(facts.canonical.present): blockers.append("canonical_glb_missing")
	if not bool(facts.canonical.import_companion): blockers.append("no_import_companion")
	if bool(facts.dir_ignored): blockers.append("directory_ignored_by_gdignore")
	blockers.append("packet_has_no_model_binding")
	blockers.append("registry_entry_absent")
	var registry := _registry_entries()
	return {"ok":true,"vehicle_id":vehicle_id,"canonical_path":str(facts.canonical.path),
		"canonical_present":bool(facts.canonical.present),"import_companion":bool(facts.canonical.import_companion),
		"registry_entry_present":registry.has(vehicle_id),"blockers":blockers,
		"required_source_fields":["delivery_status","provenance","resource_version"]}

static func _registry_entries() -> Dictionary:
	if not FileAccess.file_exists(VehicleCatalog.MODEL_SOURCE_REGISTRY): return {}
	var text := FileAccess.get_file_as_string(VehicleCatalog.MODEL_SOURCE_REGISTRY)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary: return {}
	return parsed.get("models",{})

## The measured state of every `assets/vehicles/` directory.
static func scan() -> Dictionary:
	var rows: Array[Dictionary] = []
	for dir_name in VEHICLE_DIRS: rows.append(dir_facts(dir_name))
	var registry := _registry_entries()
	return {"schema":1,"directories":rows,"registry_entries":registry.size(),
		"registry_path":VehicleCatalog.MODEL_SOURCE_REGISTRY,
		"known_vehicles":KNOWN_VEHICLES.keys(),"corrections":CORRECTIONS.size()}

## The registry is deliberately NOT filled yet: every known vehicle is blocked by a missing
## packet model_binding plus three source fields, and filling it blindly would switch the
## historical four onto the stricter bound path.
static func registration_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for vehicle_id in KNOWN_VEHICLES:
		var eligibility := registry_eligibility(vehicle_id)
		plan.append({"vehicle_id":vehicle_id,"eligible_now":false,
			"canonical_glb_present":bool(eligibility.canonical_present),
			"import_companion":bool(eligibility.import_companion),
			"blockers":eligibility.blockers,
			"required_source_fields":eligibility.required_source_fields,
			"decision":"deferred_pending_model_binding_and_source_fields"})
	return plan

static func snapshot() -> Dictionary:
	return {"scan":scan(),"plan":registration_plan(),"corrections":CORRECTIONS.duplicate(true)}
