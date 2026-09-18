extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD05-T01 and CD05-T02.
##
## T01 wants the angle series to follow the frozen curve with the angle convention and the penetration table RE-CHECKABLE,
## so the probe recomputes the expected resistance HERE from the profile's own declared fields - corrected angle, cosine
## convention, material coefficient - and compares it with what the resolver returns. Nothing under test supplies the
## expectation.
##
## T02 wants long rod and full calibre separated on the same thin sloped plate: each must use its own rule, and the long rod
## must not inherit full-calibre calibre overmatch. That is measured by varying the CALIBRE, which the full-calibre formula
## uses and the long-rod formula does not contain at all:

const CD5T1_STEP_ANGLES := [0.0,15.0,30.0,45.0,60.0,75.0]
const CD5T1_THICKNESS := 100.0

func _cd5t1_full_calibre(normalization_deg: float) -> Dictionary:
	return {"version":ArmorImpactProfile.VERSION,"family":"AP","provenance":"game_rule",
		"reason":"CD05-T01 probe fixture: the declared full-calibre rule set, recomputed independently below",
		"normalization_deg":normalization_deg,"overmatch_ratio":3.0,"ricochet_deg":70.0,
		"material_coefficients":{"rolled":1.0,"cast":1.1}}

func _cd5t1_long_rod() -> Dictionary:
	return {"version":ArmorImpactProfile.LONG_ROD_VERSION,"family":"APFSDS","provenance":"game_rule",
		"reason":"CD05-T02 probe fixture: a declared long-rod angle curve with no calibre term at all",
		"ricochet_deg":75.0,"angle_resistance_curve":[[0,1.0],[30,1.6],[60,3.2],[90,6.0]],
		"material_coefficients":{"rolled":1.0,"cast":1.1}}

func _cd5t1_event(angle_deg: float) -> Dictionary:
	return {"has_thickness":true,"thickness_mm":CD5T1_THICKNESS,"thickness_status":"estimated","material_kind":"rolled",
		"response_profile":{},"normal_world":Vector3(0,sin(deg_to_rad(angle_deg)),cos(deg_to_rad(angle_deg)))}

func _cd5t1_resolve(profile: Dictionary, effect: String, angle_deg: float, caliber_mm: float, base_mm: float, thickness_mm: float = CD5T1_THICKNESS) -> Dictionary:
	# The thickness is a parameter because my first version was not: the helper always built its event from the hundred
	# millimetre constant, so two legs I described as thirty millimetre plates were actually a hundred, and that is the whole
	# reason a calibre of a hundred and twenty five reported no overmatch against them. Ratios of nought point seven five and
	# one point two five are below the declared three, so the resolver was right and the probe was wrong.
	return ArmorResolver.resolve(_cd5t1_event_with(angle_deg,thickness_mm),Vector3.FORWARD,
		{"base_mm":base_mm,"impact_profile":profile,"effect_policy":effect,"caliber_mm":caliber_mm})

func _cd5t1_event_with(angle_deg: float, thickness_mm: float) -> Dictionary:
	return {"has_thickness":true,"thickness_mm":thickness_mm,"thickness_status":"estimated","material_kind":"rolled",
		"response_profile":{},"normal_world":Vector3(0,sin(deg_to_rad(angle_deg)),cos(deg_to_rad(angle_deg)))}

## The independent expectation for the full-calibre rule, written from the declared fields alone.
func _cd5t1_expected_full(profile: Dictionary, angle_deg: float, material: String) -> float:
	var corrected: float = maxf(0.0,angle_deg-float(profile.normalization_deg))
	return CD5T1_THICKNESS/cos(deg_to_rad(corrected))*float(profile.material_coefficients[material])

## The independent expectation for the long rod, written by hand from the declared curve rather than interpolated by a
## helper: at 45 degrees the curve runs from thirty degrees at factor one point six to sixty at three point two, so the
## factor is two point four and a thirty millimetre plate resists seventy two millimetres. My first version used a helper
## that returned eight point zero for the same point, which is exactly the kind of thing an independent expectation is
## supposed to catch - in this case in the expectation itself, not in the code.
const CD5T2_ROD_EXPECTED_AT_45 := 30.0*2.4*1.0

## The comparison bound is set ABOVE the measured float noise and far below any physical meaning: the recomputation agreed
## with the resolver to one point nine seven times ten to the minus six millimetres, and a bound of a thousandth of a
## millimetre is five hundred times looser than that while still being invisible next to a hundred millimetre plate.
const CD5_LENGTH_BOUND_MM := 1.0e-3
const CD5_ANGLE_BOUND_DEG := 1.0e-3

func _run() -> void:
	owned_directory="res://assets/vehicles/test_cd005_t01_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(owned_directory)==OK,"CD05 T01 creates its own TEST ONLY model directory")
	var ignore := FileAccess.open(owned_directory.path_join(".gdignore"),FileAccess.WRITE); ignore.close()

	# ── T01: the angle series against an independent recomputation of the frozen rule.
	var full := _cd5t1_full_calibre(4.0)
	check(ArmorImpactProfile.validate(full,"kinetic").is_empty(),"CD05 T01 the full-calibre fixture profile validates")
	print("[CD05 T01] full calibre, %.0f mm plate, normalization %.0f deg, rolled coefficient %.2f" % [
		CD5T1_THICKNESS,float(full.normalization_deg),float(full.material_coefficients.rolled)])
	var worst := 0.0
	for angle in CD5T1_STEP_ANGLES:
		var result := _cd5t1_resolve(full,"kinetic",float(angle),120.0,400.0)
		var measured := float(result.get("effective_mm",-1.0))
		var expected := _cd5t1_expected_full(full,float(angle),"rolled")
		var adjusted := float(result.get("adjusted_angle_deg",-1.0))
		worst = maxf(worst,absf(measured-expected))
		print("[CD05 T01] %5.1f deg: measured %9.4f mm | recomputed %9.4f mm | adjusted angle %5.2f | verdict %-9s" % [
			float(angle),measured,expected,adjusted,str(result.get("result",""))])
		check(absf(measured-expected)<=CD5_LENGTH_BOUND_MM,
			"CD05 T01 the %.1f degree effective thickness matches the recomputed frozen rule: %.4f vs %.4f" % [float(angle),measured,expected])
		check(absf(adjusted-maxf(0.0,float(angle)-float(full.normalization_deg)))<=CD5_ANGLE_BOUND_DEG,
			"CD05 T01 the %.1f degree adjusted angle follows the declared normalization: %.2f" % [float(angle),adjusted])
	print("[CD05 T01] worst deviation across the series: %.9f mm" % worst)

	# ── T02: long rod against full calibre on the same thin sloped plate, with the CALIBRE varied.
	var rod := _cd5t1_long_rod()
	check(ArmorImpactProfile.validate(rod,"long_rod").is_empty(),"CD05 T02 the long-rod fixture profile validates")
	check(not ArmorImpactProfile.validate(rod,"kinetic").is_empty(),"CD05 T02 a long-rod profile is refused for a full-calibre effect, so rules cannot be borrowed across families")
	var thin := 30.0
	var rod_75 := ArmorResolver.resolve({"has_thickness":true,"thickness_mm":thin,"thickness_status":"estimated","material_kind":"rolled",
		"response_profile":{},"normal_world":Vector3(0,sin(deg_to_rad(45.0)),cos(deg_to_rad(45.0)))},Vector3.FORWARD,
		{"base_mm":400.0,"impact_profile":rod,"effect_policy":"long_rod","caliber_mm":75.0})
	var rod_125 := ArmorResolver.resolve({"has_thickness":true,"thickness_mm":thin,"thickness_status":"estimated","material_kind":"rolled",
		"response_profile":{},"normal_world":Vector3(0,sin(deg_to_rad(45.0)),cos(deg_to_rad(45.0)))},Vector3.FORWARD,
		{"base_mm":400.0,"impact_profile":rod,"effect_policy":"long_rod","caliber_mm":125.0})
	var full_75 := _cd5t1_resolve(full,"kinetic",45.0,75.0,400.0,thin)
	var full_125 := _cd5t1_resolve(full,"kinetic",45.0,125.0,400.0,thin)
	print("[CD05 T02] at 45 deg on a %.0f mm plate:" % thin)
	print("[CD05 T02]   long rod 75 mm calibre => effective %.4f mm overmatch=%s" % [float(rod_75.get("effective_mm",-1.0)),str(rod_75.get("overmatch",""))])
	print("[CD05 T02]   long rod 125 mm calibre => effective %.4f mm overmatch=%s" % [float(rod_125.get("effective_mm",-1.0)),str(rod_125.get("overmatch",""))])
	print("[CD05 T02]   full cal 75 mm calibre => effective %.4f mm overmatch=%s" % [float(full_75.get("effective_mm",-1.0)),str(full_75.get("overmatch",""))])
	print("[CD05 T02]   full cal 125 mm calibre => effective %.4f mm overmatch=%s" % [float(full_125.get("effective_mm",-1.0)),str(full_125.get("overmatch",""))])
	check(absf(float(rod_75.get("effective_mm",-1.0))-CD5T2_ROD_EXPECTED_AT_45)<=CD5_LENGTH_BOUND_MM,
		"CD05 T02 the long rod follows its own declared angle curve: %.4f vs %.4f" % [float(rod_75.get("effective_mm",-1.0)),CD5T2_ROD_EXPECTED_AT_45])
	check(absf(float(rod_75.get("effective_mm",-1.0))-float(rod_125.get("effective_mm",-1.0)))<=CD5_LENGTH_BOUND_MM,
		"CD05 T02 the long rod does NOT use calibre at all, so changing it changes nothing: %.4f vs %.4f" % [float(rod_75.get("effective_mm",-1.0)),float(rod_125.get("effective_mm",-1.0))])
	var direct_125 := ArmorImpactProfile.response(full,"rolled",125.0,thin,45.0)
	var direct_75 := ArmorImpactProfile.response(full,"rolled",75.0,thin,45.0)
	print("[CD05 T02]   direct response: 125/30 => overmatch=%s ; 75/30 => overmatch=%s (ratio declared %.1f)" % [
		str(direct_125.get("overmatch","")),str(direct_75.get("overmatch","")),float(full.overmatch_ratio)])
	check(bool(direct_125.get("overmatch",false)) and not bool(direct_75.get("overmatch",false)),
		"CD05 T02 the full calibre DOES use calibre overmatch, which is exactly why the two rules must not be shared: 125 mm overmatch=%s, 75 mm overmatch=%s" % [str(full_125.get("overmatch","")),str(full_75.get("overmatch",""))])
	check(absf(float(full_75.get("effective_mm",-1.0))-(30.0/cos(deg_to_rad(41.0))*float(full.material_coefficients.rolled)))<=CD5_LENGTH_BOUND_MM,
		"CD05 T02 the full calibre follows its own recomputed rule on the same plate: %.4f" % float(full_75.get("effective_mm",-1.0)))
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD05_ANGLE_SERIES_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
