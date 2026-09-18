extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05 design point 4: the geometry normal, the front or back facing and the local inclination must
## all come from ONE collision event, and the penetration budget must stay in an explicit unit.
##
## The judgment, recomputed HERE from the very direction and normal the event carries: the reported angle must equal the
## unsigned angle between the flight direction and that normal, the reported facing must equal the sign of their dot, and
## the reported budget unit must name the game RHA equivalent rather than being a bare number. If any of the three were
## taken from a different normal or a stale frame, the recomputation would part company with the report.

const CD5D4_STEP := 1.0/240.0

func _cd5d4_passive() -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"AP","provenance":"game_rule",
		"reason":"CD05-D4 probe fixture: the passive rule set for the same-event geometry checks",
		"normalization_deg":0.0,"overmatch_ratio":0.0,"ricochet_deg":89.0,
		"material_coefficients":{"rolled":1.0,"cast":1.0}}

## One event, one direction, one normal - and the expectations recomputed from exactly those two vectors.
func _cd5d4_case(angle_deg: float, inward: bool) -> Dictionary:
	var flight := Vector3(0,0,-1)
	var normal := Vector3(0,sin(deg_to_rad(angle_deg)),cos(deg_to_rad(angle_deg)))
	if inward: normal = -normal
	var event := {"has_thickness":true,"thickness_mm":100.0,"thickness_status":"estimated","material_kind":"rolled",
		"response_profile":{},"normal_world":normal}
	var result := ArmorResolver.resolve(event,flight,
		{"base_mm":900.0,"impact_profile":_cd5d4_passive(),"effect_policy":"kinetic","caliber_mm":120.0})
	var dot := flight.dot(normal)
	var expected_angle := rad_to_deg(acos(clampf(absf(dot),0.0,1.0)))
	var expected_backface := dot > 0.0
	return {"result":result,"dot":dot,"expected_angle":expected_angle,"expected_backface":expected_backface,
		"reported_angle":float(result.get("angle_deg",-1.0)),"reported_backface":bool(result.get("backface",false)),
		"budget_unit":str(result.get("budget_unit","")),"normal":normal,"flight":flight}

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_d4_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 D4 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	print("[CD05 D4] recomputing the angle and the facing from the SAME direction and normal the event carries")
	var worst_angle := 0.0
	for row in [{"tag":"0 deg front","angle":0.0,"inward":false},{"tag":"30 deg front","angle":30.0,"inward":false},
			{"tag":"60 deg front","angle":60.0,"inward":false},{"tag":"30 deg from inside","angle":30.0,"inward":true}]:
		var case := _cd5d4_case(float(row.angle),bool(row.inward))
		var angle_error: float = absf(float(case.reported_angle)-float(case.expected_angle))
		worst_angle = maxf(worst_angle,angle_error)
		print("[CD05 D4] %-18s dot=%+.4f | reported angle %.4f vs recomputed %.4f | reported backface=%s vs recomputed=%s | unit=%s" % [
			str(row.tag),float(case.dot),float(case.reported_angle),float(case.expected_angle),
			str(case.reported_backface),str(case.expected_backface),str(case.budget_unit)])
		check(angle_error<=1e-3,
			"CD05 D4 the reported angle equals the recomputation from the same normal (%s): %.4f vs %.4f" % [str(row.tag),float(case.reported_angle),float(case.expected_angle)])
		check(bool(case.reported_backface)==bool(case.expected_backface),
			"CD05 D4 the reported facing equals the sign of the same dot product (%s): %s vs %s" % [str(row.tag),str(case.reported_backface),str(case.expected_backface)])
		check(str(case.budget_unit)==ArmorImpactProfile.UNIT and not str(case.budget_unit).is_empty(),
			"CD05 D4 the budget names its unit explicitly rather than being a bare number (%s): %s" % [str(row.tag),str(case.budget_unit)])
	print("[CD05 D4] worst angle deviation across the cases: %.9f deg" % worst_angle)
	check(str(ArmorImpactProfile.UNIT)=="game_rha_equivalent_mm",
		"CD05 D4 the declared unit is the game RHA equivalent the order names: %s" % ArmorImpactProfile.UNIT)

	# The two cases that must differ do differ, so the checks above are not all comparing one constant.
	var front := _cd5d4_case(30.0,false)
	var inside := _cd5d4_case(30.0,true)
	check(bool(front.reported_backface)!=bool(inside.reported_backface),
		"CD05 D4 the same angle seen from the front and from inside resolves to different facings, so the check above is meaningful")
	check(absf(float(front.reported_angle)-float(inside.reported_angle))<=1e-3,
		"CD05 D4 the unsigned inclination is the same either way, which is what an inclination means: %.4f vs %.4f" % [
			float(front.reported_angle),float(inside.reported_angle)])
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_SAME_EVENT_GEOMETRY_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
