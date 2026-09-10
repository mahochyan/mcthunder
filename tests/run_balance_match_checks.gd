extends SceneTree
const APP_SCENE = preload("res://scenes/app.tscn")
const VILLAGE = preload("res://tests/fixtures/balance_village.gd")
const INDUSTRIAL = preload("res://tests/fixtures/balance_industrial.gd")
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func run() -> void:
	var out := "res://logs/032-wip/matches"
	var args := OS.get_cmdline_user_args(); var index := args.find("--report-dir")
	if index>=0 and index+1<args.size(): out=args[index+1]
	DirAccess.make_dir_recursive_absolute(out)
	var reports: Array=[]
	for map_id in ["village","industrial"]:
		for match_seed in [32001,32138]:
			for swapped in [false,true]:
				var scene: VillageRange = VILLAGE.new() if map_id=="village" else INDUSTRIAL.new()
				scene.swapped=swapped; scene.selected_vehicle_id=VehicleCatalog.IDS[0]
				var runner:=MatchScenarioRunner.new()
				var report:=await runner.run(self,match_seed,scene)
				report.merge({"map":map_id,"swapped":swapped,"difficulty":"normal","roster":VehicleCatalog.IDS,"kind":"small_sample_screening"})
				var label:="%s seed=%d swapped=%s"%[map_id,match_seed,swapped]
				check(report.finished_once and not report.result.is_empty(),label+" naturally finishes once")
				check(report.bounded and report.deaths==report.unique_deaths,label+" preserves lifecycle and object budgets")
				check(report.shots>0 and report.vehicle_contacts>0,label+" actual four-vehicle rosters engage")
				var file:=FileAccess.open(out.path_join("%s_%d_%s.json"%[map_id,match_seed,swapped]),FileAccess.WRITE)
				check(file!=null,label+" report saved")
				if file!=null: file.store_string(JSON.stringify(report,"  ")); file.close()
				reports.append({"map":map_id,"seed":match_seed,"swapped":swapped,"result":report.result,"shots":report.shots,"deaths":report.deaths,"cleanup":report.cleanup,"wall_seconds":report.wall_seconds})
	var summary:=FileAccess.open(out.path_join("SUMMARY.json"),FileAccess.WRITE)
	if summary!=null: summary.store_string(JSON.stringify(reports,"  ")); summary.close()
	else: check(false,"summary writable")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	print("BALANCE_MATCH_CHECKS_PASS" if failed==0 else "BALANCE_MATCH_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
