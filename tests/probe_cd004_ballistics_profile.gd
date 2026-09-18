extends "res://tests/run_cd002_geometry_probe.gd"
## MCT-COMBAT-DEEPEN-01 CD004 design point 1 + case CD04-T02 (first half): the versioned BallisticsProfile, and the proof
## that the LEGACY path is the same curve it always was rather than a silently changed one.
##
## T02's expectation splits in two: the profile must match its frozen declared curve (the drag table itself is exercised by
## the speed-retention measurement once the drag term is integrated), and historical data that was never measured must not be
## labelled validated_history. This probe checks the second half and the resolution rules, plus an independent check of the
## drag term's own arithmetic. The old-behaviour control is the T01 zero-drag baseline, re-run as its own process.

func _run() -> void:
	print("[CD004 T02] profile version=%s units=%s" % [BallisticsProfile.VERSION,JSON.stringify(BallisticsProfile.UNITS)])

	# (i) An undeclared shell is the LEGACY case: v1 vacuum, named as such, with no drag.
	var legacy := BallisticsProfile.resolve({})
	check(str(legacy.get("source",""))=="legacy_v1_vacuum","CD004 an undeclared shell resolves to the explicit legacy v1 vacuum, not to a guessed curve: %s" % str(legacy.get("source","")))
	check(str(legacy.get("profile",""))==BallisticsProfile.PROFILE_VACUUM,"CD004 the legacy resolution names the vacuum profile: %s" % str(legacy.get("profile","")))
	check(str(legacy.get("drag_model",""))=="none" and float(legacy.get("drag_k_per_m",-1.0))==0.0,
		"CD004 the legacy resolution carries no drag term at all: model=%s k=%s" % [str(legacy.get("drag_model","")),str(legacy.get("drag_k_per_m",""))])

	# (ii) An explicit v1 vacuum declaration is the SAME curve, parameter for parameter - so wiring the profile in cannot
	# change what existing shots do.
	var explicit_vacuum := BallisticsProfile.resolve({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_VACUUM}})
	var same_model := str(explicit_vacuum.get("drag_model",""))==str(legacy.get("drag_model",""))
	var same_k := float(explicit_vacuum.get("drag_k_per_m",-1.0))==float(legacy.get("drag_k_per_m",-2.0))
	check(same_model and same_k,"CD004 an explicit v1 vacuum declaration is parameter-identical to the legacy path (drag_model=%s k=%s)" % [str(explicit_vacuum.get("drag_model","")),str(explicit_vacuum.get("drag_k_per_m",""))])

	# (iii) The one engineering approximation exists, is named, and is a DESIGN value - never validated_history.
	var drag := BallisticsProfile.resolve({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_QUADRATIC}})
	check(not drag.is_empty(),"CD004 the engineering drag profile resolves")
	check(str(drag.get("drag_model",""))=="quadratic_speed","CD004 the engineering profile uses exactly one declared model: %s" % str(drag.get("drag_model","")))
	check(str(drag.get("provenance",""))=="design" and not BallisticsProfile.is_validated_history(drag),
		"CD004 the engineering curve is labelled a design value and NOT validated_history (provenance=%s)" % str(drag.get("provenance","")))

	# (iv) A bad declaration is refused BY NAME instead of falling back to a different curve behind the caller's back.
	var refused := {"unknown":BallisticsProfile.validate({"ballistics_profile":{"profile":"no_such_curve"}}),
		"drag_k":BallisticsProfile.validate({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_QUADRATIC,"drag_k_per_m":-1.0}}),
		"max_age":BallisticsProfile.validate({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_VACUUM,"max_age_s":0.0}}),
		"max_dist":BallisticsProfile.validate({"ballistics_profile":{"profile":BallisticsProfile.PROFILE_VACUUM,"max_distance_m":-5.0}})}
	for key in refused.keys():
		var row: Dictionary = refused[key]
		print("[CD004 T02] refusal %s => ok=%s reason=%s" % [key,str(row.get("ok",true)),str(row.get("reason",""))])
		check(not bool(row.get("ok",true)),"CD004 an invalid ballistics declaration is refused rather than silently replaced: %s" % key)

	# (v) The declared curve is frozen, monotone and carries its own tolerance (the table the simulation must hold to).
	var curve := BallisticsProfile.retention_curve(BallisticsProfile.PROFILE_QUADRATIC)
	var rows: Array = curve.get("declared_retention",[])
	check(rows.size()==4 and absf(float(curve.get("tolerance",0.0))-0.010)<=1e-9,
		"CD004 the engineering profile declares four sampled ranges and a tolerance of %.3f" % float(curve.get("tolerance",0.0)))
	var monotone := true
	var previous := 1.1
	for row in rows:
		var retention := float(row[1])
		if retention > previous or retention <= 0.0 or retention >= 1.0: monotone = false
		previous = retention
	check(monotone,"CD004 the declared retention curve decreases with range and stays inside (0,1): %s" % JSON.stringify(rows))

	# (vi) The drag term's own arithmetic, checked against an independent expression: a = -k*|v|*v, and exactly zero for
	# vacuum - which is what makes the legacy curve untouched by construction.
	var test_velocity := Vector3(700.0,-30.0,0.0)
	var vacuum_drag := BallisticsProfile.drag_acceleration(legacy,test_velocity)
	var quad_drag := BallisticsProfile.drag_acceleration(drag,test_velocity)
	var expected_magnitude := 2.2e-5*test_velocity.length()*test_velocity.length()
	check(vacuum_drag==Vector3.ZERO,"CD004 the vacuum profile applies exactly zero drag to a moving shell: %s" % str(vacuum_drag))
	check(absf(quad_drag.length()-expected_magnitude)<=1e-6,"CD004 the quadratic drag magnitude is k*|v|^2 as declared: got %.6f expected %.6f" % [quad_drag.length(),expected_magnitude])
	check(quad_drag.normalized().dot(test_velocity.normalized())<=-0.9999,"CD004 the drag acceleration opposes the velocity: dot=%.6f" % quad_drag.normalized().dot(test_velocity.normalized()))

	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD004_BALLISTICS_PROFILE_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
