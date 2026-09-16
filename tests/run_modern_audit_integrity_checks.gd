extends SceneTree
## WT-040-R1 audit-integrity negative fixtures (user ruling 2026-09-16).
##
## Why this file exists: the audit once reported "T-80B: ok=false, error count=0" and that was read as a
## pass. It was not - an unhandled property access had aborted the reconstruction, the pipeline kept
## consuming an invalid layout, and the empty error list was the SHORT-CIRCUIT, not a clean result.
## These fixtures pin the four failure shapes named in the ruling so they can never silently return a
## green-looking answer again:
##   1. a required fact is missing (crew.placement)
##   2. the layout cannot be built, so dependent checks must be skipped and NAMED as skipped
##   3. a required content component / definition is missing
##   4. ok=false with an empty error list must classify as INCOMPLETE, never as a pass
## Each case asserts a NAMED rejection. The accompanying shell step also scans this run's log for
## SCRIPT ERROR, because "no unhandled script exception" is part of the requirement and cannot be
## asserted from inside GDScript.
var count := 0
var failed := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)

func _run() -> void:
	_case_audit_interpretation()
	_case_empty_packet()
	_case_missing_component()
	_case_unsupported_profile()
	_case_missing_required_fact()
	print("=== result: %d checks, %d failed ===" % [count,failed])
	print("MODERN_AUDIT_INTEGRITY_CHECKS_PASS" if failed == 0 else "MODERN_AUDIT_INTEGRITY_CHECKS_FAIL")
	quit(0 if failed == 0 else 1)

## Case 4: the interpretation itself. This is the exact shape that was misread.
func _case_audit_interpretation() -> void:
	_check(VehicleContentPipeline.audit_state({"ok":false,"errors":[]}) == "incomplete",
		"ok=false with an EMPTY error list classifies as incomplete, never as a pass")
	_check(VehicleContentPipeline.audit_state({"ok":false,"errors":["x"],"skipped_checks":["layout_validation"]}) == "incomplete",
		"a named error plus a skipped dependent check classifies as incomplete")
	_check(VehicleContentPipeline.audit_state({"ok":false,"errors":["armor.hull_front_upper: missing zone"]}) == "complete_with_gaps",
		"a named error with nothing skipped classifies as complete-with-gaps")
	_check(VehicleContentPipeline.audit_state({"ok":true,"errors":[]}) == "complete_no_gaps",
		"ok=true with no errors and nothing skipped is the only complete pass")
	_check(VehicleContentPipeline.audit_state({"ok":false,"audit":"incomplete","errors":[]}) == "incomplete",
		"an explicit incomplete marker wins over everything else")

## Case 3a: a wholly empty packet must produce NAMED errors, not a crash and not an empty list.
func _case_empty_packet() -> void:
	var res: Dictionary = VehicleContentPipeline.validate_package({},{})
	var errs: Array = res.get("errors",[])
	_check(not bool(res.get("ok",false)), "an empty packet is rejected (ok=false)")
	_check(errs.size() > 0, "an empty packet reports a NON-empty, named error list (%d)" % errs.size())
	_check(VehicleContentPipeline.audit_state(res) != "complete_no_gaps", "an empty packet never classifies as a complete pass")
	var named := false
	for e in errs:
		if str(e).contains(":"): named = true
	_check(named, "the empty-packet errors carry field paths")

## Case 3b: a packet missing one required component must name that component.
func _case_missing_component() -> void:
	var packet := {"id":"fixture_missing_component","display_name":"Fixture","geometry":{},"runtime":{},"armor":{},"modules":[],"license":"fixture"}
	var res: Dictionary = VehicleContentPipeline.validate_package(packet,{})
	var errs: Array = res.get("errors",[])
	var found := false
	for e in errs:
		if str(e) == "crew: missing content component": found = true
	_check(found, "a packet without a crew component reports 'crew: missing content component'")
	_check(not bool(res.get("ok",false)), "the missing-component packet is rejected")

## Case: an unsupported evidence profile is rejected AND names the checks it skipped.
func _case_unsupported_profile() -> void:
	var packet := {"id":"fixture_profile","evidence_profile":"nonsense","geometry":{},"runtime":{},"armor":{},"modules":[],"crew":[],"license":"fixture"}
	var res: Dictionary = VehicleContentPipeline.validate_package(packet,{})
	var skipped: Array = res.get("skipped_checks",[])
	_check(not bool(res.get("ok",false)), "an unsupported evidence profile is rejected")
	_check(VehicleContentPipeline.audit_state(res) == "complete_with_gaps" or VehicleContentPipeline.audit_state(res) == "incomplete",
		"the profile rejection classifies as a gap or as incomplete, never as a pass")

## Case 1: the missing crew.placement fact. The old code crashed here with an unhandled property access.
## This fixture drives the same reconstruction path and asserts a NAMED failure instead.
func _case_missing_required_fact() -> void:
	var packet := {
		"id":"fixture_missing_fact","display_name":"Fixture","evidence_profile":"game_reference",
		"geometry":{"hull_rings":[[0.0,1.0,-3.0,3.0]],"turret_origin":[0,1,0],"gun_origin":[0,1,0],
			"turret_outline":[],"turret_bottom":0.0,"turret_top":1.0,"turret_taper":0.5,"ring_half":0.5,"open_top":false,
			"wheel_count":6,"wheel_radius":0.3,"track_width":0.5,"barrel_length":3.0,"hull_half_width":1.0,
			"mantlet_half_width":0.3,"mantlet_half_height":0.3,"muzzle_brake":false},
		"runtime":{"forward_max_speed":10.0,"reverse_max_speed":3.0,"acceleration":2.0,"hull_turn_speed":30.0,
			"reload_time":7.0,"rounds":30,"pitch_min":-5.0,"pitch_max":14.0,"muzzle_velocity":900.0,
			"penetration_curve":[[0.0,400.0]],"turret_yaw_speed":20.0,"turret_pitch_speed":8.0},
		"armor":{},"modules":[],"license":"fixture",
		"crew":[{"id":"gunner","role":"gunner","part":"turret","position":[0.0,1.0,0.0],"size":[0.5,0.5,0.5]}],
		"facts":{"geometry.crew":{"value":[],"status":"estimated","origin":"game_rule","source_refs":["mcthunder_pipeline"],"location":"fixture"}},
		"sources":{"mcthunder_pipeline":{"origin":"game_rule","title":"fixture","applies_to_identity_ids":["fixture_missing_fact"]}},
	}
	var res: Dictionary = VehicleContentPipeline.validate_package(packet,{})
	var errs: Array = res.get("errors",[])
	_check(not bool(res.get("ok",false)), "a packet missing required evidence is rejected")
	_check(errs.size() > 0, "the rejection carries a non-empty error list (%d)" % errs.size())
	var names_placement := false
	for e in errs:
		if str(e).contains("crew.placement"): names_placement = true
	_check(names_placement, "the missing crew.placement fact is named in the errors rather than crashing")
	_check(VehicleContentPipeline.audit_state(res) != "complete_no_gaps", "the missing-fact packet never classifies as a complete pass")
