class_name VehicleCatalog
extends RefCounted
const IDS := ["us_m4a3_75w_vvss_1944","us_m24_m6_t85e1_1951","us_m26_m3_1945","us_m36_m4a1_1945"]
## WT-040-R1 (user ruling 2/3): the two engineering vehicles. They are read from configs/vehicles/engineering
## and go through EXACTLY the same register() path as the historical ones - the full pipeline validation
## plus the model binding check against the delivered artefact - so loading them here is admission, not a
## bypass of the binding gate.
const ENGINEERING_IDS := ["ussr_t_80b","germ_leopard_2a4"]
const ENGINEERING_DIR := "res://configs/vehicles/engineering/"
## WT-040-R1 (2026-09-17 ruling): the explicit vehicle scope. The curated historical roster keeps its contract,
## the engineering vehicles are a separate admitted set, and the training vehicle is a KNOWN third category that
## keeps its own training configuration and its own readiness path. is_combat_vehicle is deliberately
## history-or-engineering only: the garage roster and the historical rotation must not treat the training hull as
## a combat type.
static func is_historical(id: String) -> bool: return id in IDS
static func is_engineering(id: String) -> bool: return id in ENGINEERING_IDS
static func is_combat_vehicle(id: String) -> bool: return is_historical(id) or is_engineering(id)
static func is_training(id: String) -> bool: return id == "player_tank"
static func is_known_vehicle(id: String) -> bool: return is_combat_vehicle(id) or is_training(id)
var packages: Dictionary = {}
var rejected: Dictionary = {}
var model_sources: Dictionary = {}
var model_source_errors: Array[String] = []
const MODEL_SOURCE_REGISTRY := "res://configs/vehicles/model_sources.json"

func _init(sources: Variant = null) -> void:
	if sources==null:
		var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(MODEL_SOURCE_REGISTRY))
		if not registry is Dictionary or registry.get("schema_version")!=1 or not registry.get("models") is Dictionary:
			model_source_errors.append("model_source: malformed project registry"); return
		sources=registry.models
	if not sources is Dictionary:
		model_source_errors.append("model_source: registry must be a dictionary"); return
	model_sources=sources.duplicate(true)

func load_all(defs: VehicleDefs) -> Dictionary:
	var errors: Array[String] = []
	for id in IDS:
		var file := FileAccess.open("res://configs/vehicles/historical/"+id+".json",FileAccess.READ)
		if file == null: errors.append(id+": missing packet"); continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary: errors.append(id+": malformed JSON"); continue
		var result := register(parsed,defs)
		if not result.ok:
			for error in result.errors: errors.append(id+": "+error)
	# WT-040-R1: load_all stays HISTORICAL-ONLY on purpose. Loading the engineering vehicles here changed a
	# historical contract - run_historical_checks asserts exactly four historical configurations - so the
	# engineering vehicles are an explicit, separate admission step, see load_engineering below.
	return {"ok":errors.is_empty(),"errors":errors}

## WT-040-R1: admit the two engineering vehicles from configs/vehicles/engineering. A SEPARATE entry point so
## the historical set stays exactly what it was, while the engineering admission still goes through the same
## register() call: full pipeline validation plus the model binding check against the delivered artefact.
func load_engineering(defs: VehicleDefs) -> Dictionary:
	var errors: Array[String] = []
	for eid in ENGINEERING_IDS:
		var efile := FileAccess.open(ENGINEERING_DIR+eid+".json",FileAccess.READ)
		if efile == null: errors.append(eid+": missing engineering packet"); continue
		var eparsed: Variant = JSON.parse_string(efile.get_as_text())
		if not eparsed is Dictionary: errors.append(eid+": malformed JSON"); continue
		var eresult := register(eparsed,defs)
		if not eresult.ok:
			for error in eresult.errors: errors.append(eid+": "+error)
	return {"ok":errors.is_empty(),"errors":errors}

func register(packet: Dictionary, defs: VehicleDefs) -> Dictionary:
	if not model_source_errors.is_empty(): return {"ok":false,"errors":model_source_errors.duplicate()}
	var result := VehicleContentPipeline.validate_package(packet,model_sources)
	var id := str(packet.get("id",""))
	if not result.ok:
		rejected[id] = result
		return result
	if not packet.has("model_binding") and not ResourceLoader.exists("res://assets/vehicles/"+id+".glb"):
		return {"ok":false,"errors":[id+": missing authored Blender model"]}
	if defs.vehicles.has(id): return {"ok":false,"errors":[id+": duplicate vehicle registration"]}
	var d: Dictionary = result.definitions
	defs.vehicles[id] = d.vehicle; defs.weapons[d.weapon.id] = d.weapon; defs.shells[d.shell.id] = d.shell
	defs.layouts[result.layout.id] = result.layout
	defs.content_packets[id] = packet.duplicate(true)
	if packet.has("model_binding"): defs.model_sources[id]=model_sources[id].duplicate(true)
	packages[id] = result
	return result
