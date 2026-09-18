extends SceneTree
func _initialize() -> void:
	var failures := 0
	var cases := [
		{"name":"apfsds","expect_sub":true},
		{"name":"ap","expect_sub":false},
	]
	for row in cases:
		var shell := {"shape_kind":("long_rod" if row.name=="apfsds" else "full_caliber")}
		var res := ProjectileShapeProfile.resolve(shell)
		var ok := bool(res.get("ok",false))
		var prof: Dictionary = res.get("profile",{})
		var sub := ProjectileShapeProfile.is_sub_calibre(prof)
		var plan: Dictionary = res.get("sampling",{})
		var expected_bound: float = (float(prof.get("core_diameter_m",0.0))*0.5)*(1.0-cos(PI/float(prof.get("rays",1))))
		var bound_ok: bool = absf(float(plan.get("error_bound_m",-1.0))-expected_bound) < 1e-12
		print("  [%s] ok=%s probe=%s/%s mm sub_calibre=%s(expect %s) rays=%d bound=%.6f mm bound_matches_independent=%s" % [
			row.name,str(ok),float(prof.get("bore_caliber_mm",0.0)),float(prof.get("core_diameter_m",0.0))*1000.0,
			str(sub),str(row.expect_sub),int(plan.get("rays",0)),float(plan.get("error_bound_mm",-1.0)),str(bound_ok)])
		if not ok or sub != bool(row.expect_sub) or not bound_ok: failures += 1
	var refused := ProjectileShapeProfile.resolve({"shape_kind":"unknown_round"})
	print("  refusal for an unprofiled shell: ok=%s reason=%s" % [str(refused.get("ok",false)),str(refused.get("reason",""))])
	if refused.get("ok",false): failures += 1
	var bad := ProjectileShapeProfile.resolve({"shape_profile":{"kind":"long_rod","bore_caliber_mm":125.0,"core_diameter_m":0.500,"core_length_m":0.6,"rays":7,"provenance":"design","note":"x"}})
	print("  refusal when the core exceeds the bore: ok=%s errors=%s" % [str(bad.get("ok",false)),str(bad.get("errors",[]))])
	if bad.get("ok",false): failures += 1
	print("SHAPE_PROFILE_SELF_TEST_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
