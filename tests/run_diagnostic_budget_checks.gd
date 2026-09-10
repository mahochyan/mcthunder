extends SceneTree
const APP_SCENE = preload("res://scenes/app.tscn")
var checks:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var folder:="user://tests/diagnostic033_%d"%Time.get_ticks_usec()
	var telemetry:=TrafficTelemetry.new()
	var valid:=true
	for match_id in 27:
		telemetry.clock=match_id
		valid=telemetry.write_evidence(TrafficTelemetry.match_evidence_path(match_id,folder)) and valid
	check(valid and DirAccess.get_files_at(folder).size()==10,"27 completed-match logs use ten bounded slots")
	var path:=TrafficTelemetry.match_evidence_path(26,folder)
	var previous:=FileAccess.get_file_as_string(path)
	check(JSON.parse_string(previous).clock==26,"wrapped slot contains newest complete diagnostic")
	telemetry.planning["oversized_fixture"]="x".repeat(TrafficTelemetry.MAX_EVIDENCE_BYTES)
	check(not telemetry.write_evidence(path) and FileAccess.get_file_as_string(path)==previous,"oversized diagnostic refuses write before replacing previous evidence")
	check(TrafficTelemetry.match_evidence_path(-1,folder).get_file()=="match_09.json","slot mapping remains bounded for all integer identities")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("DIAGNOSTIC_BUDGET_CHECKS_PASS" if failed==0 else "DIAGNOSTIC_BUDGET_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
