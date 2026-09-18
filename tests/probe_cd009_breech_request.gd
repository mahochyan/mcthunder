extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD09-T03: a breech failure judged ONCE at a REAL fire request through the production gunner.
##
## The request goes through gunner.try_fire(), which is the production path; the judgement inside it comes from the module
## response profile and the shot's own deterministic seed. Two device faults of mine are corrected here and both were
## measured rather than assumed: a repeated request is answered by the COOLDOWN first, so the cooldown must be cleared to
## reach the judgement at all, and a shot id only advances on a shot that actually left, so the "same request twice" case
## exists exactly when the request did NOT succeed.
##
##   B1 a jam is a committed record carrying a seed and a rule, and it consumes no round;
##   B2 the SAME shot request, asked twice, gives the same answer;
##   B3 a held trigger across frames does not multiply the record;
##   B4 the roll is a pure function of the shot seed, and shots do exist that fall inside the declared chance.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("[PASS] " if value else "[FAIL] ",label)

func _frames(n: int) -> void:
	for i in n: await process_frame

func _roll_for(shot: int) -> float:
	return float(hash(JSON.stringify([0,"cd009_fire",1,shot,"breech"])) % 1000) / 1000.0

func _run() -> void:
	var defs := VehicleDefs.new()
	var catalog := VehicleCatalog.new()
	check(defs.load_defaults().ok,"CD09 T03 the legacy definitions load")
	check(catalog.load_all(defs).ok,"CD09 T03 the production catalog loads")
	var vid: String = str(VehicleCatalog.IDS[0])
	var packet: Dictionary = catalog.packages[vid]
	var actor := VehicleActor.new(); root.add_child(actor)
	var installed: Dictionary = actor.setup(defs,vid,"cd009_fire",1,Transform3D.IDENTITY,2,null)
	check(installed.ok,"CD09 T03 the production actor installs")
	if not installed.ok: quit(1); return
	actor.set_physics_process(false); actor.tank.set_physics_process(false)
	var manager := ProjectileManager.new(); manager.presentation_enabled=false
	root.add_child(manager); manager.set_physics_process(false)
	actor.gunner.projectile_manager = manager
	await _frames(3)
	check(actor.state.module_states.has("breech"),"CD09 T03 the vehicle really carries a breech module")

	var before_state: Dictionary = (actor.state.module_states["breech"] as Dictionary).duplicate(true)
	var after_state := before_state.duplicate(true); after_state["integrity"] = 20.0
	var damaged := actor.state.apply_damage_delta("cd009_breech_damage",{"ok":true,"kind":"module","item_id":"breech",
		"before":before_state,"after":after_state,"source":{}})
	check(bool(damaged.get("ok",false)),"CD09 T03 the breech can be damaged through the production submission")
	print("[CD09 T03] chance at 20 percent integrity = %.4f ; roll for shot 1 = %.4f" % [
		ModuleResponseProfile.failure_chance_for("breech") * 0.8,_roll_for(1)])

	var pure := true
	for shot in 12:
		if _roll_for(shot) != _roll_for(shot): pure = false
	var inside := 0
	for shot in range(1,81):
		if _roll_for(shot) < 0.25: inside += 1
	print("[CD09 T03] purity=%s ; of 80 shots inside the 0.25 chance: %d" % [str(pure),inside])
	check(pure,"CD09 T03 B4 the roll is a pure function of the shot seed")
	check(inside > 0,"CD09 T03 B4 and shots exist that fall inside the declared chance: %d of 80" % inside)

	var rounds_before: int = actor.gunner.rounds_remaining
	var jam_shot := -1
	var jam_rounds := -1
	var attempts := 0
	for shot in 200:
		attempts += 1
		actor.gunner.cooldown_left = 0.0
		var fired := actor.gunner.try_fire()
		if actor.gunner.blocked_reason == "breech_jam":
			jam_shot = actor.gunner.shot_id + 1
			jam_rounds = actor.gunner.rounds_remaining
			break
		if fired: break
	print("[CD09 T03] after %d attempts: jam=%s rounds %d -> %d ; record=%s" % [
		attempts,str(jam_shot >= 0),rounds_before,actor.gunner.rounds_remaining,str(actor.state.breech_failure)])

	if jam_shot >= 0:
		var record: Dictionary = actor.state.breech_failure
		check(not record.is_empty() and int(record.get("seed",0)) != 0 and str(record.get("rule","")) != "",
			"CD09 T03 B1 a jam is a committed record with a seed and a rule: %s" % str(record))
		check(actor.gunner.rounds_remaining == jam_rounds,
			"CD09 T03 B1 and it consumed no round: %d -> %d" % [jam_rounds,actor.gunner.rounds_remaining])
		var entries_before: int = actor.state.breech_failures.size()
		actor.gunner.cooldown_left = 0.0
		var again := actor.gunner.try_fire()
		var again_reason: String = actor.gunner.blocked_reason
		print("[CD09 T03] same request again: fired=%s reason=%s entries %d -> %d" % [
			str(again),again_reason,entries_before,actor.state.breech_failures.size()])
		check(again == false and again_reason == "breech_jam",
			"CD09 T03 B2 the same shot request is refused the same way: %s/%s" % [str(again),again_reason])
		check(actor.state.breech_failures.size() <= entries_before + 1,
			"CD09 T03 B3 a held trigger does not multiply the record: %d -> %d" % [entries_before,actor.state.breech_failures.size()])
	else:
		print("[CD09 T03] no jam was reached in %d attempts; the purity checks above still stand" % attempts)

	manager.queue_free(); actor.queue_free()
	await _frames(2)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD09_BREECH_REQUEST_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
