class_name VehicleCatalog
extends RefCounted
const IDS := ["us_m4a3_75w_vvss_1944","us_m24_m6_t85e1_1951","us_m26_m3_1945","us_m36_m4a1_1945"]
var packages: Dictionary = {}
var rejected: Dictionary = {}

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
	return {"ok":errors.is_empty(),"errors":errors}

func register(packet: Dictionary, defs: VehicleDefs) -> Dictionary:
	var result := VehicleContentPipeline.validate_package(packet)
	var id := str(packet.get("id",""))
	if not result.ok:
		rejected[id] = result
		return result
	if not ResourceLoader.exists("res://assets/vehicles/"+id+".glb"):
		return {"ok":false,"errors":[id+": missing authored Blender model"]}
	if defs.vehicles.has(id): return {"ok":false,"errors":[id+": duplicate vehicle registration"]}
	var d: Dictionary = result.definitions
	defs.vehicles[id] = d.vehicle; defs.weapons[d.weapon.id] = d.weapon; defs.shells[d.shell.id] = d.shell
	defs.layouts[result.layout.id] = result.layout
	defs.content_packets[id] = packet.duplicate(true)
	packages[id] = result
	return result
