extends SceneTree
func _initialize() -> void:
	ShotQueryService.measure_enabled=false
	ShotQueryService.measured_calls=0; ShotQueryService.measured_usec=0; ShotQueryService.measured_sources.clear()
	var checks := 0; var failures := 0
	for prefix in ["aim_","proj_","fragment_","fixture_"]:
		var request := {"query_id":prefix+"1","from_world":Vector3.ZERO,"to_world":Vector3(0,0,10)}
		ShotQueryService.measure_enabled=false
		var before := ShotQueryService.measured_calls
		var expected := ShotQueryService.query(request,[])
		var disabled_unchanged := before==ShotQueryService.measured_calls
		ShotQueryService.measure_enabled=true
		var actual := ShotQueryService.query(request,[])
		var ok := expected==actual and disabled_unchanged and ShotQueryService.measured_calls==before+1
		checks+=1
		if not ok: failures+=1
		print(("[PASS] " if ok else "[FAIL] ")+prefix+" metrics preserve result and honor enable flag")
	var calls := 0; var usec := 0
	for row in ShotQueryService.measured_sources.values(): calls+=int(row.calls); usec+=int(row.cpu_usec)
	var reconciled := calls==4 and calls==ShotQueryService.measured_calls and usec==ShotQueryService.measured_usec and ShotQueryService.measured_sources.size()==4
	checks+=1
	if not reconciled: failures+=1
	print(("[PASS] " if reconciled else "[FAIL] ")+"bounded source buckets reconcile with total time and calls")
	ShotQueryService.measure_enabled=false
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("QUERY_METRICS_CHECKS_PASS" if failures==0 else "QUERY_METRICS_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
