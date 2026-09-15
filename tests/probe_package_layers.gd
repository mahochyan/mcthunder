extends SceneTree
## WT-040-R1 step 3: probe the layers that live BEYOND check_shape.
##
## validate_package calls check_shape first and returns immediately if it reports anything, so the
## content body, the layout build, the layout validator, the shell catalog and the definition
## validators have never been exercised on these two vehicles - the nine shape gaps are still open and
## they are external inputs. This probe therefore calls those public stages DIRECTLY, with the drafts
## plus clearly-labelled probe values for the nine, so the real remaining scope becomes a list instead
## of a guess. Probe values are never written to a packet and nothing is registered or admitted.
##
## Usage: -s res://tests/probe_package_layers.gd
const GEOMETRY := "res://logs/WT-040-R1/modern_geometry_draft.json"
const FACTS := "res://logs/WT-040-R1/modern_facts_draft.json"
const CREW := "res://logs/WT-040-R1/modern_crew_draft.json"
const MODULES := "res://logs/WT-040-R1/modern_modules_draft.json"
const ARMOR := "res://logs/WT-040-R1/modern_armor_draft.json"
const EVIDENCE := "res://logs/WT-040-R1/modern_evidence_record.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var geo := {}
	var runtime := {}
	var facts := {}
	for r in _read(GEOMETRY).get("rows",[]):
		if r is Dictionary: geo[str(r.get("id",""))] = r.get("fields",{})
	for f in _read(FACTS).get("rows",[]):
		if not f is Dictionary: continue
		var id := str(f.get("id",""))
		runtime[id] = f.get("runtime",{})
		facts[id] = f.get("facts",{})
	var crew := {}
	for c in _read(CREW).get("rows",[]):
		if c is Dictionary: crew[str(c.get("id",""))] = c.get("crew",[])
	var modules := {}
	for m in _read(MODULES).get("rows",[]):
		if m is Dictionary: modules[str(m.get("id",""))] = m.get("modules",[])
	var armor := {}
	var armor_facts := {}
	for a in _read(ARMOR).get("rows",[]):
		if not a is Dictionary: continue
		armor[str(a.get("id",""))] = a.get("armor",{})
		armor_facts[str(a.get("id",""))] = a.get("facts",{})
	var evidence := {}
	for e in _read(EVIDENCE).get("rows",[]):
		if e is Dictionary: evidence[str(e.get("id",""))] = e.get("facts",{})
	for id in geo.keys():
		print("[layers] ===== ",id)
		var merged_facts: Dictionary = facts.get(id,{}).duplicate(true)
		for extra in [armor_facts.get(id,{}),evidence.get(id,{})]:
			for key in (extra as Dictionary).keys(): merged_facts[key] = extra[key]
		var packet := _packet(str(id),geo[id],runtime.get(id,{}),armor.get(id,{}),modules.get(id,[]),crew.get(id,[]),merged_facts)
		# stage 1: the layout build (the content body calls this at line 42)
		var layout: VehicleLayoutDefinition = null
		var built := false
		layout = HistoricalVehicleGeometry.build(packet)
		built = layout != null
		print("[layers]   geometry.build -> ",("ok, parts="+str(layout.parts.size())+" armor_patches="+str(layout.armor_patches.size()) if built else "FAILED"))
		if not built: continue
		# stage 2: the layout validator
		var lv := LayoutValidator.validate(layout,PackedStringArray(packet.facts.keys()),VehicleContentPipeline.layout_evidence(packet,layout))
		print("[layers]   LayoutValidator.errors=",lv.errors.size()," warnings=",lv.warnings.size()," suspicious=",lv.suspicious_overlaps.size())
		for err in lv.errors: print("[layers]     ! ",str(err))
		for w in lv.warnings: print("[layers]     ~ ",str(w))
		# stage 3: the shell catalog
		var shells := VehicleShellCatalog.build(packet)
		print("[layers]   VehicleShellCatalog.ok=",shells.get("ok",false)," errors=",(shells.get("errors",[]) as Array).size()," options=",(shells.get("options",[]) as Array).size())
		for se in shells.get("errors",[]): print("[layers]     ! ",str(se))
		# stage 4: the definitions and their own validators (the final gate)
		var defs := VehicleContentPipeline.definitions_for(packet,layout)
		for d in [defs.vehicle,defs.weapon,defs.shell]:
			var dv: Dictionary = d.validate()
			print("[layers]   definition ",str(d.id)," errors=",(dv.get("errors",[]) as Array).size())
			for de in dv.get("errors",[]): print("[layers]     ! ",str(d.id),": ",str(de))
	print("MODERN_LAYER_PROBE_DONE")
	quit(0)

func _packet(id: String, g: Dictionary, rt: Dictionary, ar: Dictionary, mods: Array, cr: Array, f: Dictionary) -> Dictionary:
	var packet := {
		"id":id,"display_name":id,"geometry":g,"armor":ar,"modules":mods,"crew":cr,
		"runtime":{"forward_max_speed":20.83,"reverse_max_speed":2.78,"acceleration":4.0,"hull_turn_speed":30.0,
			"reload_time":1.0,"rounds":38.0,"pitch_min":-10.0,"pitch_max":20.0,"muzzle_velocity":905.0,
			"penetration_curve":[[0.0,150.0],[500.0,125.0]]},
		"assembly":{"variant":"PROBE","suspension":"PROBE","gun":"PROBE","mount":"PROBE","shell":"PROBE","year":1900,"caliber_mm":125.0},
		"facts":f,"sources":{},"compatible_shells":[],"license":"<LAYER PROBE - not a licence decision>",
	}
	for key in rt.keys(): packet["runtime"][key] = rt[key]
	return packet

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in b.keys(): out[key] = b[key]
	return out

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
