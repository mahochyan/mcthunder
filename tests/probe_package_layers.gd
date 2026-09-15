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
		# stage 2: the layout validator, given an evidence registry built from the layout's OWN claims
		# (mechanical: it registers exactly the keys and field claims the layout asserts, each pointing
		# at the draft that produced it, so the validator can get past the registry gate and report what
		# it really still needs). This is a probe registry, never a delivered file.
		var registry := _registry_from(layout)
		var lv := LayoutValidator.validate(layout,PackedStringArray(packet.facts.keys()),registry)
		print("[layers]   LayoutValidator.errors=",lv.errors.size()," warnings=",lv.warnings.size()," suspicious=",lv.suspicious_overlaps.size()," registry_keys=",(registry["evidence_keys"] as Array).size()," registry_fields=",(registry["fields"] as Array).size())
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
	var geom := g.duplicate(true)
	# WT-040-R1: HistoricalVehicleGeometry.build reads hull_rings straight off the geometry dictionary,
	# so a vehicle without them crashes there. The Leopard's rings are the recorded author item, so for
	# the probe only - NEVER for a packet - a clearly-labelled placeholder ring set is supplied so the
	# LATER layers become observable. It is derived from the measured turret origin and track width and
	# says so; it is not a measurement and not a claim about the vehicle.
	if not geom.has("hull_rings"):
		var track := float(geom.get("track_width",0.5))
		var half := float(geom.get("turret_origin",[0.0,1.6,0.0])[0])
		var ty := float(geom.get("turret_origin",[0.0,1.6,0.0])[1])
		var tb := float(geom.get("turret_bottom",ty-0.2))
		geom["hull_rings"] = [
			[snappedf(tb-0.6,0.01),1.4,-3.0,3.0],
			[snappedf(tb-0.2,0.01),1.5,-3.2,3.2],
			[snappedf(tb+0.1,0.01),1.5,-3.2,3.0],
		]
		print("[layers]   PLACEHOLDER hull_rings supplied for the probe: derived from turret origin/track width, NOT measured, author item unchanged (track=",track," half=",half,")")
	var packet := {
		"id":id,"display_name":id,"geometry":geom,"armor":ar,"modules":mods,"crew":cr,
		"runtime":{"forward_max_speed":20.83,"reverse_max_speed":2.78,"acceleration":4.0,"hull_turn_speed":30.0,
			"reload_time":1.0,"rounds":38.0,"pitch_min":-10.0,"pitch_max":20.0,"muzzle_velocity":905.0,
			"penetration_curve":[[0.0,150.0],[500.0,125.0]]},
		"assembly":{"variant":"PROBE","suspension":"PROBE","gun":"PROBE","mount":"PROBE","shell":"PROBE","year":1900,"caliber_mm":125.0},
		"facts":f,"sources":{},"compatible_shells":[],"license":"<LAYER PROBE - not a licence decision>",
	}
	for key in rt.keys(): packet["runtime"][key] = rt[key]
	# WT-040-R1: build reads packet.facts["crew.placement"].status, so the fact must exist or the build
	# dies there - the error was a MISSING KEY, not a nesting problem, which the source read corrected.
	if not packet["facts"].has("crew.placement"):
		packet["facts"]["crew.placement"] = {"value":"probe","status":"estimated","origin":"warthunder_reference",
			"source_refs":["wt-2.57.1.137"],"location":"PROBE: exists so the layout build can run"}
	# WT-040-R1: definitions_for line 230 constructs a Vector3 from
	# HistoricalEvidenceGate.value(packet,"dimensions.width_m"), and the gate returns null for a missing
	# or inconsistent fact - which is the "Nonexistent 'Vector3' constructor" error. These probe values
	# exist only so the definition builder can run; the real dimensions are the recorded documentary item.
	if not packet["facts"].has("dimensions.width_m"):
		packet["facts"]["dimensions.width_m"] = {"value":3.0,"status":"reference","origin":"warthunder_reference",
			"source_refs":["wt-2.57.1.137"],"location":"PROBE: width so the definition builder can run"}
	if not packet["facts"].has("dimensions.reference_length_m"):
		packet["facts"]["dimensions.reference_length_m"] = {"value":6.0,"status":"reference","origin":"warthunder_reference",
			"source_refs":["wt-2.57.1.137"],"location":"PROBE: length so the definition builder can run"}
	# and the sources registry HistoricalEvidenceGate requires: a url, a 64-hex sha256, a read state and
	# an applicability list. Probe values, clearly labelled, never a delivered document. The dossier's own
	# source id is registered as well, because the drafts' source_refs point at it - the real dossier has
	# no url, which is one of the recorded input requirements.
	packet["sources"] = {
		"PROBE": {"origin":"mcthunder_pipeline","url":"https://probe.invalid/pipeline",
			"sha256":"0".repeat(64),"read_state":"text_read","applies_to_identity_ids":[id],"excluded_identity_ids":[]},
		"wt-2.57.1.137": {"origin":"warthunder_reference","url":"https://probe.invalid/dossier",
			"sha256":"97947ab4a1cfa8924e1ad63bf874507968732f72fb699c9c139e9ec2ba1813a9",
			"read_state":"text_read","applies_to_identity_ids":[id],"excluded_identity_ids":[]},
	}
	# the fact origins must MATCH the registered source origins, otherwise HistoricalEvidenceGate returns
	# null and the definition builder dies constructing a Vector3 from it - that was the line 230 error.
	for key in packet["facts"].keys():
		var row: Variant = packet["facts"][key]
		if not row is Dictionary: continue
		if str(row.get("origin","")) == "warthunder_reference":
			row["source_refs"] = ["wt-2.57.1.137"] if str(row.get("source_refs",[""])[0]).begins_with("wt-") else row.get("source_refs",[])
	return packet

## Mechanical probe registry: register exactly the evidence keys and field claims the built layout
## asserts, each attributed to the draft it came from. Nothing here is a delivered document.
func _registry_from(layout: VehicleLayoutDefinition) -> Dictionary:
	var keys: Dictionary = {}
	var fields: Array = []
	for group in [layout.parts,layout.armor_patches,layout.modules,layout.crew_stations]:
		for item in group:
			if item == null: continue
			for k in item.evidence_keys:
				if not keys.has(str(k)):
					# WT-040-R1: the applicability list must name the identity, or the validator says the
					# key does not apply to it - which is what produced hundreds of the errors.
					keys[str(k)] = {"key":str(k),"source_id":"PROBE","origin":"mcthunder_pipeline",
						"title":"probe registration for "+str(k),"applies_to":"probe only",
						"read_state":"probe","applies_to_identity_ids":[layout.historical_identity_id],
						"excluded_identity_ids":[]}
	for patch in layout.armor_patches:
		if patch == null: continue
		# WT-040-R1: a field record's source_refs must name an EVIDENCE KEY (keys_in_doc), not a source
		# id - referencing "PROBE" produced every "references unregistered source" error. The patch's own
		# evidence_keys are exactly the right evidence for its own claims.
		var refs_p: Array = []
		for k2 in patch.evidence_keys: refs_p.append(str(k2))
		if refs_p.is_empty(): refs_p = ["geometry.exterior"]
		for claim in [["thickness_mm",patch.thickness_status],["geometry_status",patch.geometry_status],["has_thickness",patch.thickness_status]]:
			if str(claim[1]) == "unknown": continue
			fields.append({"field_path":"armor_patches.%s.%s" % [patch.id,str(claim[0])],"origin":"mcthunder_pipeline",
				"status":str(claim[1]),"source_refs":refs_p,"original_value":"PROBE",
				"original_unit":"","derivation":"probe","uncertainty_note":"probe"})
	for station in layout.crew_stations:
		if station == null: continue
		var refs_s: Array = []
		for k3 in station.evidence_keys: refs_s.append(str(k3))
		if refs_s.is_empty(): refs_s = ["geometry.crew"]
		for claim2 in [["role_placement",station.role_placement_status],["local_box_transform",station.position_status],["size_m",station.volume_status]]:
			if str(claim2[1]) == "unknown": continue
			fields.append({"field_path":"crew_stations.%s.%s" % [station.id,str(claim2[0])],"origin":"mcthunder_pipeline",
				"status":str(claim2[1]),"source_refs":refs_s,"original_value":"PROBE",
				"original_unit":"","derivation":"probe","uncertainty_note":"probe"})
	# the registry's source_registry has its OWN shape (id -> title/agency/date/sha256/local_path), which
	# is different from packet.sources (id -> origin/url/sha256/read_state/applicability).
	var src := {}
	for sid in ["PROBE","mcthunder_pipeline","wt-2.57.1.137"]:
		src[sid] = {"title":"probe source "+sid,"agency":"mcthunder_pipeline","date":"2026-09-15",
			"sha256":"0".repeat(64),"local_path":"logs/WT-040-R1"}
	return {"identity_id":layout.historical_identity_id,"runtime_note":"probe",
		"source_registry":src,"evidence_keys":keys.values(),"fields":fields}

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for key in b.keys(): out[key] = b[key]
	return out

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
