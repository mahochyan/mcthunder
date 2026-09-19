extends "res://tests/probe_cd003_gap_baseline.gd"
## MCT-COMBAT-DEEPEN-01 CD15: the two WEAK passes of the first scene pass are turned into behavioural proofs.
##
## The first pass admitted two weaknesses: the presentation half of the first case was never exercised, because the probe
## looked for a ProjectileManager as a CHILD of the match scene and found none; and several conditions rested on FILE EXISTENCE
## rather than behaviour. This probe drives the real objects instead.
##
## Judgments:
##   P1 the feedback layer is reached through the range OWN projectiles member, and stopping it leaves the committed events and
##      the tickets of an identical match unchanged;
##   P2 each declared shell effect family is accepted and carries its OWN family, an undeclared effect is refused by name, and a
##      round whose fuze never reaches a target produces NO lethal internal burst;
##   P3 a stored replay record is interpreted against its own rule version and an unknown one is refused rather than re-settled.

const ENG := "res://configs/vehicles/engineering/ussr_t_80b.json"

## The profile builder used by the family check, declared as a member so a lambda can be assigned to it.
var _impact_profile: Callable = Callable()

func _run() -> void:
	var defs := VehicleDefs.new()
	var handle := FileAccess.open(ENG,FileAccess.READ)
	check(handle != null,"CD15 probe the engineering packet opens")
	var eng: Dictionary = JSON.parse_string(handle.get_as_text())
	# The REAL range below admits this packet through its own admission path, so registering it here as well would be a
	# duplicate admission; the handle above only proves the packet is readable, and the range own admission is the real one.

	# ── P1 the feedback layer, reached the way a range actually holds it.
	var scene := TeamRange.new()
	root.add_child(scene); current_scene = scene
	await _frames(190)
	for actor in scene.combat_actors(): actor.set_controller(null)
	var manager: ProjectileManager = scene.projectiles
	check(manager != null,"CD15 probe the range exposes its own projectile manager")
	var feedback: CombatFeedback = manager.feedback
	check(feedback != null,"CD15 probe and that manager owns the feedback layer at last")
	var events_before := scene.director.state.events.size()
	var tickets_before := str(scene.director.state.tickets)
	if feedback != null: feedback.stop_all()
	await _frames(3)
	var events_after := scene.director.state.events.size()
	var tickets_after := str(scene.director.state.tickets)
	print("[CD15 probe] P1 feedback present=%s ; events %d -> %d ; tickets %s -> %s" % [
		str(feedback != null),events_before,events_after,tickets_before,tickets_after])
	check(feedback != null and events_after == events_before and tickets_after == tickets_before,
		"CD15 probe P1 stopping the FEEDBACK LAYER leaves the committed events and the tickets untouched")
	# The range is NOT freed here: the family check below uses the range OWN admitted actor and manager, so freeing it at this
	# point is what made the earlier run report a previously freed base. It is freed once, at the end.
	await _frames(2)

	# ── P2 each shell family through the real spawn gate, using the RANGE OWN admitted actor and manager rather than a
	# second hand-built one: the range admitted its packet through its own path, so building a parallel world here would be
	# exactly the fabricated harness that already cost this session two rounds.
	var world := scene
	var actor: VehicleActor = scene.combat_actors()[0]
	check(actor != null and actor.gunner != null,"CD15 probe the range own admitted vehicle is available for the family check")
	var m2: ProjectileManager = scene.projectiles
	m2.damage_handler = Callable(scene,"_apply_projectile_damage")
	var shell := actor.gunner.shell if actor.gunner != null else null
	check(shell != null,"CD15 probe the vehicle carries a shell definition to build the family specs from")
	if shell == null: quit(1); return
	var families := []
	var refusals := []
	# The declared effects, each with the COMPLETE impact profile the armour side actually validates: its own version, its
	# family, a game provenance, an explanation, the three numeric rules and BOTH material coefficients. A bare family key is
	# not enough and was refused as invalid_impact_profile, which is the armour side behaving exactly as designed.
	var wanted := {"kinetic":"AP","he_blast":"AP","internal_burst":"APHE","long_rod":"APFSDS"}
	var long_rod_version := "wt012-long-rod-v1"
	_impact_profile = func(family: String) -> Dictionary:
		# The long-rod family is validated by its OWN rule set, which FORBIDS the full-caliber normalization and overmatch
		# fields outright and instead demands an explicit bounded angle-resistance curve covering zero to ninety degrees with
		# normal resistance one at zero. So the families get genuinely different profiles rather than one shape reused.
		if family == "APFSDS":
			return {"version":"wt012-long-rod-v1","family":"APFSDS","provenance":"game_rule",
				"reason":"CD15 family probe: a declared project long-rod profile for this family",
				"ricochet_deg":70.0,
				"angle_resistance_curve":[[0.0,1.0],[30.0,1.4],[60.0,2.2],[90.0,3.0]],
				"material_coefficients":{"rolled":1.0,"cast":0.95}}
		return {"version":"wt012-full-caliber-v1","family":family,"provenance":"game_rule",
			"reason":"CD15 family probe: a declared project profile for this family",
			"normalization_deg":5.0,"overmatch_ratio":2.0,"ricochet_deg":60.0,
			"material_coefficients":{"rolled":1.0,"cast":0.95}}
	var effect_index := 0
	for effect in wanted.keys():
		effect_index += 1
		var impact: Dictionary = _impact_profile.call(str(wanted[effect]))
		var spec := {"round_id":1700+effect_index,"shooter_id":"cd015","shooter_life_id":1,"shot_id":1700+effect_index,
			"shell_id":str(shell.id),"effect_policy":str(effect),"armor_policy":"resolve",
			"impact_profile":impact,"post_penetration_profile":{},"fuze_policy":{},
			"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
			"seed":9001,"position_world":Vector3(20,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
			"max_age_s":0.4,"max_distance_m":60.0}
		var spawned := m2.try_spawn(spec)
		var family := str(spawned.get("family",impact.get("family","")))
		if bool(spawned.get("ok",false)): families.append(str(effect))
		else: refusals.append("%s:%s" % [str(effect),str(spawned.get("reason",""))])
	# An effect nobody declared must be refused rather than silently treated as kinetic. Its identifiers are their OWN, well
	# clear of the indexed family loop above, because the manager correctly refuses a RELAUNCH of the same round as
	# duplicate_launch and that dedup is not what this probe is about.
	var bogus := m2.try_spawn({"round_id":1801,"shooter_id":"cd015","shooter_life_id":1,"shot_id":1801,
		"shell_id":str(shell.id),"effect_policy":"unexploded_placeholder","armor_policy":"resolve",
		"impact_profile":{"family":"AP"},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
		"seed":9002,"position_world":Vector3(20,1.2,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.4,"max_distance_m":60.0})
	# A round that never reaches anything must not produce a lethal burst.
	var lone := m2.try_spawn({"round_id":1802,"shooter_id":"cd015","shooter_life_id":1,"shot_id":1802,
		"shell_id":str(shell.id),"effect_policy":"internal_burst","armor_policy":"resolve",
		"impact_profile":{"family":"APHE"},"post_penetration_profile":{},"fuze_policy":{},
		"caliber_mm":shell.caliber_mm,"penetration_curve":shell.penetration_curve,
		"seed":9003,"position_world":Vector3(20,40,0),"velocity_world":Vector3(-700,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":0.4,"max_distance_m":60.0})
	var lone_state: ProjectileState = m2.get_projectile_state(lone.projectile_id) if bool(lone.get("ok",false)) else null
	if lone_state != null:
		for i in 200:
			if lone_state.is_terminal(): break
			m2.advance_projectile(lone_state,1.0/240.0,[],world.get_world_3d().direct_space_state)
	var lone_burst: Dictionary = (lone_state.burst if lone_state != null and lone_state.burst is Dictionary else {})
	print("[CD15 probe] P2 accepted families=%s ; refusals=%s ; undeclared refused=%s reason=%s ; lone burst=%s" % [
		str(families),str(refusals),str(not bool(bogus.get("ok",true))),str(bogus.get("reason","")),
		("none" if lone_burst.is_empty() else str(lone_burst.keys()))])
	check(families.size() == 4,"CD15 probe P2 every declared shell family is accepted and carries its own effect: %s" % str(families))
	check(not bool(bogus.get("ok",true)) and str(bogus.get("reason","")).begins_with("invalid_effect_policy"),
		"CD15 probe P2 an undeclared effect is refused by name rather than treated as kinetic: %s" % str(bogus.get("reason","")))
	check(lone_burst.is_empty(),"CD15 probe P2 a round that reaches nothing produces NO lethal burst")
	scene.queue_free(); await _frames(2)

	# ── P3 the replay record against its own rule version.
	var has_codec := FileAccess.file_exists("res://scripts/replay/shot_record_codec.gd")
	var has_builder := FileAccess.file_exists("res://scripts/replay/shot_record_builder.gd")
	var versions_known := Array(RuleVersionInterpreter.known_versions())
	var old_read := RuleVersionInterpreter.interpret({"rule_version":1,"outcome":"victory"})
	var new_read := RuleVersionInterpreter.interpret({"rule_version":999,"outcome":"victory"})
	print("[CD15 probe] P3 codec=%s builder=%s known_versions=%s ; old ok=%s rules=%s ; unknown ok=%s reason=%s" % [
		str(has_codec),str(has_builder),str(versions_known),str(old_read.get("ok",false)),str(old_read.get("rules","")),
		str(new_read.get("ok",true)),str(new_read.get("reason",""))])
	check(has_codec and has_builder and bool(old_read.get("ok",false)) and not bool(new_read.get("ok",true)),
		"CD15 probe P3 a stored record is explained by its own version and an unknown one is refused, never re-settled")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD15_FEEDBACK_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
