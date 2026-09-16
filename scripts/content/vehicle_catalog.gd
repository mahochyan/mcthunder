class_name VehicleCatalog
extends RefCounted
const IDS := ["us_m4a3_75w_vvss_1944","us_m24_m6_t85e1_1951","us_m26_m3_1945","us_m36_m4a1_1945"]
## WT-040-R1 (user ruling 2/3): the two engineering vehicles. They are read from configs/vehicles/engineering
## and go through EXACTLY the same register() path as the historical ones - the full pipeline validation
## plus the model binding check against the delivered artefact - so loading them here is admission, not a
## bypass of the binding gate.
const ENGINEERING_IDS := ["ussr_t_80b","germ_leopard_2a4"]
const ENGINEERING_DIR := "res://configs/vehicles/engineering/"
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
	# The engineering vehicles load through the same register() call, so a rejected one is named, not hidden.
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
