extends SceneTree
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	var args := OS.get_cmdline_user_args()
	var runs := 10
	var out_dir := "res://logs/019/wip-uncommitted/batch"
	var index := args.find("--runs")
	if index>=0 and index+1<args.size(): runs = clampi(int(args[index+1]),1,10)
	index = args.find("--report-dir")
	if index>=0 and index+1<args.size(): out_dir = args[index+1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var baseline := {}
	var reports: Array = []
	for number in runs:
		var runner := MatchScenarioRunner.new()
		var report := await runner.run(self,19001+number*137)
		check(report.finished_once and not report.result.is_empty() and report.result.reason in ["tickets","time_limit"],"T019-01 seed %d naturally settles exactly once"%report.seed)
		check(report.bounded,"T019-02 seed %d keeps actors/wrecks/projectiles/cameras within budget"%report.seed)
		check(report.approached.size() == 8 and report.shots > 0 and report.vehicle_contacts > 0,"all eight AI slots reach approaches and actual shots contact vehicles")
		check(report.deaths == report.unique_deaths and report.ended_shots == report.shots,"unique death ledger and one terminal record for every accepted shot")
		if number == 0: baseline = report.cleanup.duplicate()
		check(report.cleanup.nodes == baseline.nodes and report.cleanup.orphans == baseline.orphans and report.cleanup.resources<=baseline.resources+8,"T019-03 complete match cleanup stays bounded across restart %d"%(number+1))
		print("[match result] seed=%d outcome=%s seconds=%s deaths=%d shots=%d max=%s cleanup=%s"%[report.seed,report.result.get("outcome","missing"),report.result.get("seconds",0),report.deaths,report.shots,report.max,report.cleanup])
		var file := FileAccess.open(out_dir.path_join("seed_%d.json"%report.seed),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
		else: check(false,"cannot save actual match evidence")
		reports.append({"seed":report.seed,"result":report.result,"max":report.max,"cleanup":report.cleanup,"wall_seconds":report.wall_seconds})
	var summary := FileAccess.open(out_dir.path_join("SUMMARY.json"),FileAccess.WRITE)
	if summary != null: summary.store_string(JSON.stringify(reports,"  ")); summary.close()
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MATCH_BATCH_CHECKS_PASS" if failed == 0 else "MATCH_BATCH_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)
