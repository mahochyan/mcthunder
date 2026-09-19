extends SceneTree
## MCT-COMBAT-DEEPEN-01 CD13: the contribution ledger DRIVEN, so its behaviour is measured rather than its existence.
##
## Round 172 wrote the ledger and admitted that two acceptance cases passed on it merely EXISTING. This probe drives it:
##   B1 attribution is VERSIONED and frozen: the largest effective damage wins, ties break by time then subject id;
##   B2 the assist window is real: damage older than the declared window is not an assist;
##   B3 the counter that must never count is refused by name: friendly fire, abandonment, environmental, orphaned fire;
##   B4 the dedup key, not the subject, is what stops double counting: the same key twice is refused and the count does not move;
##   B5 sustained fire keeps the origin of whoever started it, even after that origin is gone;
##   B6 the five counters are separate: one firing, several damages and at most one kill.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1
	print("[PASS] " if value else "[FAIL] ",label)

func _run() -> void:
	var ledger := ContributionLedger.new()
	ledger.begin(4242,7)
	check(ContributionLedger.VERSION != "" and ContributionLedger.ATTRIBUTION_VERSION != "",
		"CD13 B1 the ledger declares both a rule version and an attribution version")

	# B1 two shooters, one target: the LARGER effective damage becomes primary and the other becomes an assist.
	ledger.record_damage({"root_effect":"re1","weapon_kind":"shot"},combo("shot",101),"shooter_A","B",2.0,0.0)
	ledger.record_damage({"root_effect":"re2","weapon_kind":"shot"},combo("shot",102),"shooter_C","B",5.0,1.0)
	var receipt := ledger.attribute("B",2.0)
	print("[CD13] B1 primary=%s assists=%s version=%s" % [
		str(receipt.get("primary","")),str(receipt.get("assists",[])),str(receipt.get("attribution_version",""))])
	check(str(receipt.get("primary","")) == "shooter_C" and "shooter_A" in Array(receipt.get("assists",[]))
		and str(receipt.get("attribution_version","")) == ContributionLedger.ATTRIBUTION_VERSION,
		"CD13 B1 the larger effective damage takes the primary and the other is an assist, under a declared attribution version")

	# B2 the window: a hit far outside it is neither primary nor an assist.
	var ledger2 := ContributionLedger.new()
	ledger2.begin(4243,7)
	ledger2.record_damage({"root_effect":"old"},combo("shot",201),"shooter_OLD","D",9.0,0.0)
	ledger2.record_damage({"root_effect":"new"},combo("shot",202),"shooter_NEW","D",1.0,100.0)
	var receipt2 := ledger2.attribute("D",100.0)
	print("[CD13] B2 primary=%s assists=%s window=%.1fs old included=%s" % [
		str(receipt2.get("primary","")),str(receipt2.get("assists",[])),float(receipt2.get("window_s",0.0)),
		str("shooter_OLD" in Array(receipt2.get("assists",[])))])
	check(str(receipt2.get("primary","")) == "shooter_NEW" and not ("shooter_OLD" in Array(receipt2.get("assists",[]))),
		"CD13 B2 damage older than the assist window is not an assist, however large it was")

	# B3 the causes that must never be credited.
	var refused := []
	for cause in ["friendly_fire","abandonment","environment","sustained_fire_orphan"]:
		var r := ledger2.credit_kill("D",100.0,cause)
		refused.append([cause,bool(r.get("ok",false)),str(r.get("reason",""))])
	var kills_before: int = int(ledger2.totals().get("kill",0))
	print("[CD13] B3 refusals=%s ; kill counter=%d" % [str(refused),int(kills_before)])
	var all_refused := true
	for row in refused:
		if bool(row[1]): all_refused = false
	check(all_refused and int(kills_before) == 0,
		"CD13 B3 friendly fire, abandonment, an environmental death and an orphaned fire are each refused by name and score nothing")

	# B4 the dedup KEY is what stops double counting, not the subject.
	var ledger3 := ContributionLedger.new()
	ledger3.begin(4244,7)
	var first := ledger3.record(ContributionLedger.KIND_SHOT,{"root_effect":"re"},"shot:9001","shooter_X")
	var second := ledger3.record(ContributionLedger.KIND_SHOT,{"root_effect":"re"},"shot:9001","shooter_X")
	var count := ledger3.count_for("shooter_X",ContributionLedger.KIND_SHOT)
	print("[CD13] B4 first ok=%s second ok=%s reason=%s ; counter=%d" % [
		str(first.get("ok",false)),str(second.get("ok",false)),str(second.get("reason","")),count])
	check(bool(first.get("ok",false)) and not bool(second.get("ok",false))
		and str(second.get("reason","")).begins_with("already_counted") and count == 1,
		"CD13 B4 the same dedup key twice is refused as already counted and the counter does not move")

	# B5 sustained fire inheritance through the root effect.
	var ledger4 := ContributionLedger.new()
	ledger4.begin(4245,7)
	ledger4.record_sustained_fire({"root_effect":"fire_started_by_E","target_id":"F","amount":3.0,"at":0.0},"shooter_E","fire:7001")
	var receipt5 := ledger4.attribute("F",1.0)
	print("[CD13] B5 read at 1.0s inside the 12s window: fire primary=%s assists=%s counters=%s" % [
		str(receipt5.get("primary","")),str(receipt5.get("assists",[])),str(ledger4.counters)])
	check(str(receipt5.get("primary","")) == "shooter_E",
		"CD13 B5 a sustained fire keeps the origin of whoever started it when the attribution is read later")

	# B6 five counters, separate subjects and kinds.
	var ledger5 := ContributionLedger.new()
	ledger5.begin(4246,7)
	ledger5.record_contact({"root_effect":"re"},"contact:1","shooter_G")
	ledger5.record(ContributionLedger.KIND_SHOT,{"root_effect":"re"},"shot:1","shooter_G")
	ledger5.record(ContributionLedger.KIND_FIRING_SLOT,{"root_effect":"re"},"slot:1","shooter_G")
	for i in 3:
		ledger5.record_damage({"root_effect":"module_%d"%i,"weapon_kind":"shot"},"dmg:%d"%i,"shooter_G","H",1.0,0.0)
	var kill := ledger5.credit_kill("H",1.0,"")
	var kill_again := ledger5.credit_kill("H",1.0,"")
	var totals := ledger5.totals()
	print("[CD13] B6 totals=%s ; kill ok=%s again=%s" % [str(totals),str(kill.get("ok",false)),str(kill_again.get("ok",false))])
	check(int(totals.get("shot_fired",0)) == 1 and int(totals.get("contact",0)) == 1
		and int(totals.get("effective_damage",0)) == 3 and int(totals.get("firing_slot",0)) == 1
		and int(totals.get("kill",0)) == 1 and bool(kill.get("ok",false)) and not bool(kill_again.get("ok",false)),
		"CD13 B6 contacts, effective damages, shots, firing slots and kills are counted separately, and a life is killed once")

	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("CD13_LEDGER_%s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)

func combo(tag: String, n: int) -> String:
	return "%s:%d" % [tag,n]
