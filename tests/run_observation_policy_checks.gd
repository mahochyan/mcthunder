extends SceneTree
# WT-017: the observation contract. Four information classes stay apart; visual
# attenuation and physical blocking are separate; a medium opts in per channel; gameplay
# occlusion is independent of display quality; a respawned enemy does not inherit an old
# marker; replay/spectator/minimap projections never carry an unrelated enemy's internals.
var count := 0
var failed := 0
var scene: AICombatRange
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(180.0)
	timer.timeout.connect(func() -> void: print("[FAIL] observation suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _frames(n: int = 3) -> void:
	for i in n: await physics_frame
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. four information classes and their authority ---
	_check(ObservationPolicy.INFO_CLASSES.size() == 4 and "world_truth" in ObservationPolicy.INFO_CLASSES,"four information classes are declared")
	_check(ObservationPolicy.precision_for("observer_visible") < ObservationPolicy.precision_for("shared_intel"),"an observed contact is more precise than reported intel")
	_check(ObservationPolicy.precision_for("shared_intel") < ObservationPolicy.precision_for("last_seen_memory"),"reported intel is more precise than a remembered contact")
	_check(ObservationPolicy.expiry_for("observer_visible") > 0.0 and ObservationPolicy.expiry_for("world_truth") == 0.0,"memory expires while world truth has no memory window")
	var policy := ObservationPolicy.new()
	policy.register_life("B",7)
	var truth_for_view := policy.record("player",{"entity_id":"B","life_id":7,"position":Vector3(10,0,0)},0.0,"world_truth")
	_check(not truth_for_view.ok and str(truth_for_view.reason) == "world_truth_is_authority_only","world truth cannot be recorded by a client view")
	var authority := ObservationPolicy.new()
	authority.register_life("B",7)
	_check(authority.record("authority",{"entity_id":"B","life_id":7,"position":Vector3(10,0,0)},0.0,"world_truth").ok,"the authority may hold world truth")
	# --- 2. media and channel rules are independent ---
	_check(ObservationPolicy.visual_blocked("smoke","optical"),"smoke blocks the optical channel")
	_check(not is_equal_approx(ObservationPolicy.attenuation("smoke","optical"),ObservationPolicy.attenuation("smoke","thermal")),"smoke does not attenuate every channel identically")
	_check(ObservationPolicy.attenuation("smoke","thermal") > 0.0 and ObservationPolicy.attenuation("smoke","thermal") < 1.0,"the thermal channel has its own smoke rule")
	_check(not ObservationPolicy.blocks_projectile("smoke") and ObservationPolicy.blocks_projectile("building"),"visual attenuation and physical blocking are separate facts")
	_check(not ObservationPolicy.visual_blocked("foliage","optical") and ObservationPolicy.blocks_projectile("foliage") == false,"foliage degrades sight without blocking shells")
	var occluded := policy.record("player",{"entity_id":"B","life_id":7,"position":Vector3(10,0,0)},0.0,"observer_visible","building","optical")
	_check(not occluded.ok and str(occluded.reason) == "occluded","an observation through a blocking medium cannot be recorded as visible")
	# --- 3. gameplay occlusion is independent of display quality ---
	var original_fx := AccessibilitySettings.fx_level
	var results := {}
	for level in [0,1,2]:
		AccessibilitySettings.fx_level = level
		results[level] = ObservationPolicy.attenuation("smoke","optical")
	AccessibilitySettings.fx_level = original_fx
	_check(results[0] == results[1] and results[1] == results[2] and results[2] == 1.0,"smoke occlusion is identical at every quality level")
	var source := FileAccess.get_file_as_string("res://scripts/battle/observation_policy.gd")
	_check(not source.contains("AccessibilitySettings") and not source.contains("fx_level"),"the observation policy contains no display-quality reference at all")
	# --- 4. a respawned enemy does not inherit the old marker ---
	var memory := ObservationPolicy.new()
	memory.register_life("B",7)
	memory.record("player",{"entity_id":"B","life_id":7,"position":Vector3(10,0,0)},0.0,"observer_visible")
	_check(memory.query(1.0).size() == 1,"a fresh observation is present in memory")
	var dropped := memory.register_life("B",8)
	_check(dropped == 1 and memory.query(1.0).is_empty(),"respawning the enemy drops the old marker")
	var stale := memory.record("player",{"entity_id":"B","life_id":7,"position":Vector3(10,0,0)},2.0,"observer_visible")
	_check(not stale.ok and str(stale.reason) == "stale_life","a record against the old life id is refused")
	# memory expiry
	var expiring := ObservationPolicy.new()
	expiring.register_life("C",1)
	expiring.record("player",{"entity_id":"C","life_id":1,"position":Vector3(0,0,0)},0.0,"observer_visible")
	_check(expiring.query(ObservationPolicy.MEMORY_DEFAULT_S+1.0).is_empty(),"a remembered contact expires after its window")
	# --- 5. audio cues carry no internals ---
	var cue := ObservationPolicy.audio_cue({"kind":"engine","position":Vector3(30,0,-30),"modules":{"engine":0.0},"ammo":{"ap":5}},Vector3.ZERO)
	_check(cue.has("bearing_deg") and cue.has("distance_band") and cue.has("direction_hint"),"audio gives a bearing, a distance band and a direction hint")
	_check(not cue.has("modules") and not cue.has("ammo") and not cue.has("position"),"audio never carries internals or an exact position")
	# --- 6. projections: replay / spectator / minimap never leak an unrelated enemy ---
	var with_internals := {"entity_id":"B","life_id":7,"position":Vector3(10,0,0),"source":"observer_visible",
		"precision_m":2.0,"age_s":1.0,"modules":{"engine":0.4},"crew":{"gunner":true}}
	for view in ["replay","spectator","killcam"]:
		var other := ObservationPolicy.project(view,"A",with_internals,"B")
		_check(not other.has("modules") and not other.has("crew"),"%s hides another entity's internals"%view)
		var own := ObservationPolicy.project(view,"B",with_internals,"B")
		_check(bool(own.get("internals_visible",false)) and own.has("modules"),"%s may show the subject's own internals"%view)
	var minimap := ObservationPolicy.project("minimap","A",with_internals,"B")
	_check(not minimap.has("modules") and minimap.has("age_s") and not minimap.has("position") == false,"the minimap projection is position plus age only")
	var player_view := ObservationPolicy.project("player","A",with_internals,"A")
	_check(not player_view.has("modules"),"the player view never receives another entity's internals")
	# --- 7. laboratory: an AI that loses sight stops receiving live precise state ---
	scene = AICombatRange.new()
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	_check(scene.combat_ready,"combat laboratory ready for the sight-loss check")
	var ai := scene.ai
	var visible_ever := false
	for i in 300:
		await physics_frame
		if bool(ai.observation.get("visible",false)): visible_ever = true
	var last_seen := float(ai.observation.get("last_visible_at",-1.0)) if bool(ai.observation.get("visible",false)) else -1.0
	_check(not visible_ever,"the AI behind cover never sees the target during 300 ticks")
	_check(ai.observation.is_empty() or not bool(ai.observation.get("visible",false)),"the AI is not handed live enemy state while blind")
	_check(last_seen < 0.0,"no live last-seen timestamp is fabricated while the target is unobserved")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("OBSERVATION_POLICY_CHECKS_PASS" if failed == 0 else "OBSERVATION_POLICY_CHECKS_FAIL")
	scene.free()
	quit(1 if failed else 0)
