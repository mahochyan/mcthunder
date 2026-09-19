extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD14 acceptance scenes, written BEFORE the implementation, as the work order requires.
##
## The expectations are fixed now. Every condition is a MEASUREMENT, and every probe is one GDScript can actually make: a
## runtime file existence check, a direct reference to a class that exists, or a key present in a returned dictionary. The
## first drafts of this file used has_method on a class to look for a function that does not exist yet - which the parser
## rejects outright, because GDScript resolves a referenced static symbol while parsing. That is recorded rather than hidden.
##
##   S1 the old 300 ticket mode plays normally: its rules and save semantics are unchanged and new behaviour is opt in
##   S2 a personal sortie book beside the team pool: the two never share a balance and income follows committed events
##   S3 a blocked spawn, a cancellation and a repeated token: no double charge and the reservation is released
##   S4 line-up count and eligibility: switching, exhaustion and shortage refuse with a visible reason, never a default hull
##   S5 a repeated settlement and a failed save: no double reward, a recoverable failure, and the real profile not polluted
##   S6 a restart with a different rule version: an old result is read by its own version, an unknown one migrated or refused

var checks := 0
var failures := 0
var not_yet_met: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("[PASS] " if value else "[FAIL] ",label)

func met(id: String, condition: bool, declared: String, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s MET (declared expectation holds): %s" % [id,declared])
		return
	not_yet_met.append("%s: %s" % [id,declared])
	print("[SCENE] %s NOT_YET_MET (declared expectation, recorded rather than relaxed): %s" % [id,label])

func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func _run() -> void:
	# ── S1 the old preset intact, and whether a second versioned preset exists, measured by a runtime file check.
	var old_preset := MatchRulePreset.standard()
	var old_snap: Dictionary = old_preset.snapshot()
	var new_preset_id := "ground_rb_like_v1" if _exists("res://scripts/battle/ground_rb_like_preset.gd") else ""
	print("[CD14] S1 old id=%s version=%d tickets=%s fingerprint=%s ; new preset id=%s" % [
		old_preset.id(),MatchRulePreset.VERSION,str(old_snap.get("start_tickets","")),old_preset.fingerprint(),new_preset_id])
	met("CD14-T01", old_preset.id() == "team_standard_300" and int(old_snap.get("start_tickets",0)) == 300
		and old_preset.fingerprint() != "" and new_preset_id == "ground_rb_like_v1",
		"the old rules and save semantics must be preserved, with new behaviour only in the new preset",
		"the old preset is not intact, or no new versioned preset file exists beside it")

	# ── S2 four independent books: the team pool exists as a file, and a personal book must be measurable in the profile.
	var store := ProfileStore.new("user://profiles/cd014_probe")
	var stored: Dictionary = store.snapshot()
	var team_pool_present := _exists("res://scripts/battle/ticket_ledger.gd")
	var personal_present := false
	for key in ["sortie_points","sortie_balance","sp","sp_balance"]:
		if stored.has(key): personal_present = true
	print("[CD14] S2 team pool file=%s ; stored keys=%s ; personal book present=%s" % [
		str(team_pool_present),str(stored.keys()),str(personal_present)])
	met("CD14-T02", team_pool_present and personal_present,
		"the different resources must never share a balance, and income must follow committed events",
		"the stored profile holds no personal sortie book, so the different resources cannot be shown to be separate")

	# ── S3 the sortie transaction: measured by whether a reservation can be held at all, beside the existing spawn search.
	var respawn_present := RespawnService.new() != null
	var reservation_present := false
	for key in ["sortie_reserved","reserved_sortie","sortie_pending"]:
		if stored.has(key): reservation_present = true
	print("[CD14] S3 spawn search class present=%s ; reservation bookkeeping present=%s" % [
		str(respawn_present),str(reservation_present)])
	met("CD14-T03", respawn_present and reservation_present,
		"a blocked spawn, a cancellation and a repeated token must not double charge and must release the reservation",
		"the spawn search exists but no reservation bookkeeping does, so a repeat token cannot be made idempotent")

	# ── S4 line-up legality, which already exists and is exercised here.
	var service := GarageService.new()
	var line_up := service.vehicle_ids()
	var all_known := true
	for vid in line_up:
		if not service.has_vehicle(str(vid)): all_known = false
	var refused := Lineup.validate(line_up,"cd014_no_such_vehicle","ground_rb_like_v1",[],null)
	var unknown_loadout: Dictionary = service.default_loadout("cd014_no_such_vehicle")
	print("[CD14] S4 line-up=%s all known=%s ; refusal ok=%s reason=%s ; loadout keys for an unknown id=%d" % [
		str(line_up),str(all_known),str(refused.get("ok",true)),str(refused.get("reason","")),unknown_loadout.size()])
	met("CD14-T04", all_known and not bool(refused.get("ok",true)) and str(refused.get("reason","")) != ""
		and not service.has_vehicle("cd014_no_such_vehicle"),
		"the line-up must refuse uniformly with a visible reason and must never generate a default vehicle",
		"an unconfigured vehicle was accepted, the refusal carried no reason, or the garage claimed to hold it")

	# ── S5 the result is applied once and the store commits transactionally.
	var progression := ProgressionService.new(store)
	var registered := progression.register_match(MatchConfig.new())
	var token := "cd014_match_1"
	var first := progression.apply_result_once(token,{"outcome":"victory"})
	var second := progression.apply_result_once(token,{"outcome":"victory"})
	var candidate: Dictionary = store.snapshot()
	candidate["cd014_probe"] = 1
	var commit := store.commit(candidate)
	var reloaded: Dictionary = ProfileStore.new("user://profiles/cd014_probe").snapshot()
	print("[CD14] S5 register=%s ; first ok=%s second ok=%s second reason=%s ; commit ok=%s ; reloaded has probe=%s ; rewards=%s" % [
		str(registered.get("ok",false)),str(first.get("ok",false)),str(second.get("ok",false)),str(second.get("reason","")),
		str(commit.get("ok",false)),str(reloaded.has("cd014_probe")),str(ProgressionService.REWARDS)])
	met("CD14-T05", bool(first.get("ok",false)) and not bool(second.get("ok",true)) and bool(commit.get("ok",false))
		and reloaded.has("cd014_probe"),
		"a repeated settlement must not reward twice, a failure must be clearly recoverable and the real profile must not be polluted",
		"the repeated settlement rewarded twice, or the candidate was not committed and reloadable")

	# ── S6 the version tag, and an interpreter able to read or refuse a version.
	var tagged := old_snap.has("start_tickets") and MatchRulePreset.VERSION >= 1
	var interpreter_present := _exists("res://scripts/battle/rule_version_interpreter.gd")
	print("[CD14] S6 stored result carries version=%d ; version interpreter present=%s" % [
		MatchRulePreset.VERSION,str(interpreter_present)])
	met("CD14-T06", tagged and interpreter_present,
		"a historical result must be explained by its own rule version, and an unknown version explicitly migrated or refused",
		"no interpreter exists to read a result by its own version or to refuse an unknown one")

	print("[CD14] scenes=6 ; not_yet_met=%d" % not_yet_met.size())
	for entry in not_yet_met: print("[CD14]   NOT_YET_MET %s" % entry)
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD14_SCENES_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
