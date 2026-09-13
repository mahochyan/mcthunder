extends SceneTree
# WT-030: the reusable vehicle content record. Facts are read from the repository, field
# provenance is explicit, responsibilities are separate fields, a missing muzzle/pivot/
# layout reports its own name instead of falling back to a default combat vehicle, an LOD
# swap never touches the combat configuration, and source/licence blocks distribution only.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(180.0)
	timer.timeout.connect(func() -> void: print("[FAIL] record suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _record(vehicle_id: String) -> Dictionary:
	var built := VehicleContentRecord.build(vehicle_id)
	return built.get("record",{})
func _valid_record() -> Dictionary:
	var record := _record("ussr_t_80b").duplicate(true)
	record.armor.layout_id = "layout:test"
	record.modules.layout_id = "layout:test"
	record.armor.provenance = "author"
	record.modules.provenance = "author"
	record.licence = "redistributable"
	record.redistributable = true
	return record
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. records are built from measured in-repo facts ---
	for vehicle_id in VehicleContentRecord.pilot_ids():
		var built := VehicleContentRecord.build(vehicle_id)
		_check(built.ok,"%s builds a content record"%vehicle_id)
		var record: Dictionary = built.record
		_check(bool(record.model.present) and int(record.model.bytes) > 0,"%s records the real model size (%d bytes)"%[vehicle_id,int(record.model.bytes)])
		_check(str(record.model.sha256).length() == 64,"%s records the real model hash"%vehicle_id)
		_check(bool(record.reference_entry.present) and str(record.reference_entry.sha256).length() == 64,"%s records the real reference entry"%vehicle_id)
		_check(not bool(record.model.import_companion),"%s has no import companion, so the model is bytes rather than a loadable resource"%vehicle_id)
		_check(str(record.mount.root) != "" and str(record.mount.gun_mesh) != "","%s carries its authored mount specification"%vehicle_id)
		for key in VehicleContentRecord.RESPONSIBILITIES:
			_check(record.has(key),"%s keeps %s as its own field"%[vehicle_id,key])
	_check(str(VehicleContentRecord.build("not_a_vehicle").reason) == "unknown_vehicle","an unknown vehicle has no record")
	# --- 2. field provenance is explicit ---
	var provenance := VehicleContentRecord.field_provenance(_record("ussr_t_80b"))
	var all_declared := true
	for field in provenance:
		if not VehicleContentRecord.PROVENANCE.has(str(provenance[field].provenance)): all_declared = false
	_check(all_declared,"every field names a declared provenance")
	_check(str(provenance.model.provenance) == "fact" and str(provenance.reference_entry.provenance) == "fact","measured artifacts are marked as facts")
	_check(str(provenance.armor.provenance) == "unknown","an unattached layout is honestly marked unknown rather than assumed")
	_check(str(provenance.licence.provenance) == "unknown","an unestablished licence is marked unknown")
	# --- 3. the pilots fail validation with NAMED reasons, not a default fallback ---
	var pilot_validation := VehicleContentRecord.validate(_record("ussr_t_80b"))
	_check(not pilot_validation.ok,"an incomplete pilot record does not validate")
	_check(pilot_validation.errors.has("missing_layout"),"the missing layout is reported by name")
	var synthetic := _valid_record()
	var synthetic_validation := VehicleContentRecord.validate(synthetic)
	_check(synthetic_validation.ok,"a complete record validates, so the checks are not vacuous")
	# --- 4. individual failures each report themselves ---
	var cases: Array = [
		{"mutate":func(r: Dictionary) -> void: r.model.present = false,"error":"missing_model"},
		{"mutate":func(r: Dictionary) -> void: r.model.sha256 = "","error":"unhashed_model"},
		{"mutate":func(r: Dictionary) -> void: r.muzzle_and_pivot.erase("muzzle_m"),"error":"missing_muzzle"},
		{"mutate":func(r: Dictionary) -> void: r.muzzle_and_pivot.erase("pivot_m"),"error":"missing_pivot"},
		{"mutate":func(r: Dictionary) -> void: r.scale = [1.0,1.0,1.0],"error":""},
		{"mutate":func(r: Dictionary) -> void: r.scale = [-1.0,1.0,1.0],"error":"negative_scale"},
		{"mutate":func(r: Dictionary) -> void: r.scale = [5.0,1.0,1.0],"error":"scale_out_of_range"},
		{"mutate":func(r: Dictionary) -> void: r.scale = [NAN,1.0,1.0],"error":"non_finite_scale"},
		{"mutate":func(r: Dictionary) -> void: r.scale = [1.0,1.0],"error":"malformed_scale"},
		{"mutate":func(r: Dictionary) -> void: r.forward_axis = "+Z","error":"coordinate_convention_mismatch"},
		{"mutate":func(r: Dictionary) -> void: r.muzzle_and_pivot.muzzle_m = [0.0,50.0,0.0],"error":"transform_inconsistent"},
		{"mutate":func(r: Dictionary) -> void: r.evidence_grade = "vibes","error":"unknown_evidence_grade"},
		{"mutate":func(r: Dictionary) -> void: r.licence = "probably_fine","error":"unknown_licence_state"},
	]
	for case in cases:
		var mutated := synthetic.duplicate(true)
		(case.mutate as Callable).call(mutated)
		var verdict := VehicleContentRecord.validate(mutated)
		if str(case.error).is_empty():
			_check(verdict.ok,"an untouched scale validates")
		else:
			_check(not verdict.ok and verdict.errors.has(str(case.error)),"a %s failure is reported by name"%case.error)
	# --- 5. an LOD swap never changes the combat configuration ---
	var swap := VehicleContentRecord.lod_switch_keeps_combat(_record("germ_leopard_2a4"),"res://assets/research/models/germ_leopard_2a4.glb")
	_check(bool(swap.combat_unchanged),"switching the model leaves armour, modules, collision and muzzle untouched")
	var missing_swap := VehicleContentRecord.lod_switch_keeps_combat(_record("germ_leopard_2a4"),"res://assets/research/models/does_not_exist.glb")
	_check(bool(missing_swap.combat_unchanged),"even switching to a missing LOD leaves the combat configuration alone")
	# --- 6. source and licence gate distribution only ---
	var gate := VehicleContentRecord.distribution_gate(_record("ussr_t_80b"))
	_check(not gate.ok and str(gate.decision) == "blocked_pending_source","an unknown source blocks distribution pending provenance")
	_check(not bool(gate.blocks_game_use) and bool(gate.blocks_public_candidate),"an unknown source blocks the public candidate without blocking game use")
	_check(VehicleContentRecord.distribution_gate(_valid_record()).ok,"a redistributable record passes the gate")
	var non_redistributable := _valid_record()
	non_redistributable.licence = "non_redistributable"
	_check(str(VehicleContentRecord.distribution_gate(non_redistributable).decision) == "blocked_non_redistributable","declared non-redistributable material is blocked by name")
	# --- 7. portability: no dependency on this machine's absolute paths ---
	for vehicle_id in VehicleContentRecord.pilot_ids():
		_check(bool(VehicleContentRecord.portability(_record(vehicle_id)).ok),"%s references only res:// paths"%vehicle_id)
	var absolute := _valid_record()
	absolute.model.path = "E:/AIprogram/aimodel/ussr/vehicle.glb"
	var portability := VehicleContentRecord.portability(absolute)
	_check(not portability.ok and portability.offenders.size() == 1,"an absolute local path is detected and reported")
	# --- 8. the real registry state of the in-repo research models ---
	var registry := VehicleContentRecord.registry_report()
	_check(registry.ok and int(registry.models) > 100,"the registry report enumerates the in-repo research models (%d)"%int(registry.models))
	_check(int(registry.with_import_companion) == 0,"none of them has an import companion")
	_check(int(registry.registered_in_model_sources) == 0,"none of them is registered in model_sources.json yet")
	var none_loadable := true
	for row in registry.rows:
		if bool(row.resource_loadable): none_loadable = false
	_check(none_loadable,"every research model is bytes-only for the resource loader")
	# --- 9. the rebuildable source -> export -> integration checklist ---
	var checklist := VehicleContentRecord.rebuild_checklist("ussr_t_80b")
	_check(checklist.size() == 4,"the pilot checklist has source, model, mount and integration steps")
	var hashed := true
	for step in checklist:
		if str(step.step) == "model" and str(step.sha256).length() != 64: hashed = false
		if str(step.step) == "source_entry" and int(step.bytes) <= 0: hashed = false
	_check(hashed,"every artifact step carries its real size or hash")
	_check(str(checklist[3].artifact) == "configs/vehicles/model_sources.json","the integration step names the registry that is still empty")
	var snapshot := VehicleContentRecord.snapshot("ussr_t_80b")
	for field in ["record","provenance","validation","distribution","portability","checklist"]:
		_check(snapshot.has(field),"the snapshot exposes %s"%field)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("CONTENT_RECORD_CHECKS_PASS" if failed == 0 else "CONTENT_RECORD_CHECKS_FAIL")
	quit(1 if failed else 0)
