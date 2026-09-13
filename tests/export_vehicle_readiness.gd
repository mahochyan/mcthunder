extends SceneTree
# WT-031-R1 export tool: writes the readiness ledger artifact that the report
# references. It performs no assertions; assertions live in run_vehicle_readiness_checks.gd.
var out_path := "res://docs/wt/continuation/VEHICLE_READINESS.json"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--out")
	if at >= 0 and at+1 < args.size(): out_path = args[at+1]
	var catalog := VehicleCatalog.new()
	var evidence_path := "res://docs/wt/continuation/VEHICLE_EVIDENCE.json"
	var evidence: Dictionary = {}
	if FileAccess.file_exists(evidence_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(evidence_path))
		if parsed is Dictionary: evidence = parsed
	var ledger := VehicleReadiness.ledger(catalog,evidence)
	ledger["schema"] = 1
	ledger["work_order"] = "WT-031-R1"
	ledger["generated_at_utc"] = Time.get_datetime_string_from_system(true)+"Z"
	ledger["evidence_registry"] = evidence_path
	ledger["gate_entry"] = "VehicleReadiness.eligible(id, mode, profile, catalog)"
	ledger["gate_callers"] = ["scripts/garage/lineup.gd","scripts/battle/team_range.gd:vehicle_id_for_slot"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	var text := JSON.stringify(ledger,"  ")
	var file := FileAccess.open(out_path,FileAccess.WRITE)
	if file == null:
		print("[FAIL] cannot write ",out_path)
		quit(1); return
	file.store_string(text+"\n")
	file.close()
	print("[ledger] wrote ",out_path," (",text.length()," bytes)")
	var summary: Dictionary = ledger.get("catalog_summary",{})
	print("[ledger] ladder: ",summary.get("ladder",""))
	print("[ledger] combat_ready=",ledger.get("combat_ready",-1)," blocked=",ledger.get("blocked",-1))
	print("VEHICLE_READINESS_EXPORT_DONE")
	quit(0)
