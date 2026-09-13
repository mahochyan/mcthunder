extends SceneTree
# WT-022-R1: the frozen match-rule preset, the three-point capture semantics, the ticket
# ledger's duplicate protection, the outcome order, and the reward receipt contract.
# Pure state logic plus the real progression service on an isolated profile path.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	# watchdog: a runtime error inside _run would otherwise leave the tree running forever
	var timer := create_timer(180.0)
	timer.timeout.connect(func() -> void: print("[FAIL] rule suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _state_with(t1: int, t2: int, elapsed: float) -> TeamMatchState:
	var state := TeamMatchState.new()
	state.phase = "playing"
	state.tickets = {1:t1,2:t2}
	state.elapsed = elapsed
	return state
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. frozen preset and drift guard against the live implementation values ---
	var preset := MatchRulePreset.standard()
	_check(preset.start_tickets == TeamMatchState.START_TICKETS,"preset start tickets match the implementation (%d)"%preset.start_tickets)
	_check(preset.death_cost == TeamMatchState.DEATH_COST,"preset death cost matches the implementation (%d)"%preset.death_cost)
	_check(is_equal_approx(preset.time_limit_s,TeamMatchState.TIME_LIMIT),"preset time limit matches the implementation")
	_check(is_equal_approx(preset.respawn_delay_s,TeamMatchState.RESPAWN_DELAY),"preset respawn delay matches the implementation")
	_check(is_equal_approx(preset.protection_s,TeamMatchState.PROTECTION_SECONDS),"preset spawn protection matches the implementation")
	_check(is_equal_approx(preset.capture_radius_m,TeamMatchState.CAPTURE_RADIUS),"preset capture radius matches the implementation")
	_check(is_equal_approx(preset.capture_seconds,TeamMatchState.CAPTURE_SECONDS),"preset capture seconds match the implementation")
	_check(preset.event_schema_version == TeamMatchState.EVENT_SCHEMA_VERSION,"preset event schema matches the implementation")
	_check(preset.event_history_limit == TeamMatchState.EVENT_HISTORY_LIMIT,"preset event history limit matches the implementation")
	_check(preset.max_points == BattleObjectives.MAX_POINTS,"preset zone cap matches the objectives implementation")
	_check(preset.rewards == ProgressionService.REWARDS,"preset rewards match the live progression table")
	_check(preset.id() == "team_standard_300" and preset.VERSION == 1 and preset.label() == "team_standard_300@v1","the preset carries a stable id and version")
	_check(preset.fingerprint().length() == 64 and preset.fingerprint() == MatchRulePreset.standard().fingerprint(),"the frozen rule fingerprint is stable")
	_check(preset.result_order[0] == "tickets_exhausted" and "draw" in preset.result_order,"the outcome order is explicit")
	_check(bool(preset.respawn_rules.frozen_loadout) and bool(preset.respawn_rules.new_life_id),"respawn rules require a frozen loadout and a new life id")
	_check(bool(preset.capture_rules.excludes_destroyed) and bool(preset.capture_rules.excludes_protected),"capture rules exclude destroyed and protected vehicles")
	# --- 2. three-point capture semantics ---
	var point := CapturePointState.new()
	for i in 13: CapturePoint.step(point,[1],1.0)
	_check(point.capture_owner == 1,"a lone team captures the zone after the capture window (%d)"%point.capture_owner)
	var progress_before := point.capture_progress
	var contest := CapturePoint.step(point,[1,2],1.0)
	_check(point.contested,"two teams in the zone mark it contested")
	_check(is_equal_approx(point.capture_progress,progress_before),"a contested zone makes no capture progress")
	_check(float(contest.get(1,0.0)) > 0.0,"a contested owned zone keeps draining for its current owner")
	for i in 30: CapturePoint.step(point,[2],1.0)
	_check(point.capture_owner == 2,"the other team can neutralise and recapture the zone")
	var empty := {}
	for i in 13: empty = CapturePoint.step(CapturePointState.new(),[],1.0)
	_check(float(empty.get(1,0.0)) == 0.0 and float(empty.get(2,0.0)) == 0.0,"an empty zone drains nothing")
	# zone membership: outside the radius or far above is not an occupant
	var objectives := BattleObjectives.new()
	_check(objectives.configure([{"id":"A","center":Vector3(0,9,0),"radius":45.0}]),"three-point definitions configure")
	var match_state := _state_with(300,300,0.0)
	var inside_owned := 0.0
	for i in 13:
		var row := objectives.step(match_state,[{"id":"A","team":1,"position":Vector3(0,9,20)}],1.0)
		inside_owned += float(row.owned.get(1,0.0))
	var outside_obj := BattleObjectives.new()
	outside_obj.configure([{"id":"A","center":Vector3(0,9,0),"radius":45.0}])
	var outside_state := _state_with(300,300,0.0)
	var outside := outside_obj.step(outside_state,[{"id":"A","team":1,"position":Vector3(0,9,400)}],1.0)
	var high_obj := BattleObjectives.new()
	high_obj.configure([{"id":"A","center":Vector3(0,9,0),"radius":45.0}])
	var high_state := _state_with(300,300,0.0)
	var high := high_obj.step(high_state,[{"id":"A","team":1,"position":Vector3(0,60,20)}],1.0)
	_check(inside_owned > 0.0,"an entity inside the zone accumulates owned time once the zone is captured (%.2f s)"%inside_owned)
	_check(float(outside.owned.get(1,0.0)) == 0.0 and not outside_state.contested,"an entity outside the zone neither captures nor contests it")
	_check(float(high.owned.get(1,0.0)) == 0.0,"an entity far above the zone contributes nothing")
	# --- 3. duplicate death protection ---
	var state := TeamMatchState.new()
	state.phase = "playing"
	state.tickets = {1:300,2:300}
	state.roster = {"A":{"team":1,"deaths":0,"respawn_at":0.0,"protection_left":0.0,"waiting_reason":"","respawn_requested":false,"player":true}}
	state.pending_deaths = {"A:1:7":{"entity_id":"A","life_id":1}}
	TicketLedger.apply_events(state,{})
	TicketLedger.apply_events(state,{})
	_check(int(state.tickets[1]) == 300-TeamMatchState.DEATH_COST,"a death costs tickets exactly once (%d)"%int(state.tickets[1]))
	_check(int(state.roster.A.deaths) == 1,"the roster counts one death, not two")
	_check(state.pending_deaths.is_empty(),"the pending death queue is drained")
	# --- 4. outcome order, including a same-tick double exhaustion ---
	_check(TicketLedger.result_after_tick(_state_with(0,0,0.0)) == "draw","both tickets empty in the same tick is a draw")
	_check(TicketLedger.result_after_tick(_state_with(0,300,0.0)) == "defeat","a player-side exhaustion is a defeat")
	_check(TicketLedger.result_after_tick(_state_with(300,0,0.0)) == "victory","an enemy exhaustion is a victory")
	_check(TicketLedger.result_after_tick(_state_with(150,150,TeamMatchState.TIME_LIMIT)) == "draw","the time limit with equal tickets is a draw")
	_check(TicketLedger.result_after_tick(_state_with(200,100,TeamMatchState.TIME_LIMIT)) == "victory","the time limit compares tickets (player ahead)")
	_check(TicketLedger.result_after_tick(_state_with(100,200,TeamMatchState.TIME_LIMIT)) == "defeat","the time limit compares tickets (player behind)")
	_check(TicketLedger.result_after_tick(_state_with(300,300,0.0)) == "","a running match yields no result")
	var frozen := _state_with(0,0,0.0)
	_check(TicketLedger.result_after_tick(frozen) == "draw","the first evaluated outcome is final for that tick")
	# --- 5. reward receipts on an isolated profile ---
	var store := ProfileStore.new("user://profiles/test_match_rules")
	var service := ProgressionService.new(store)
	_check(service.apply_result_once("",{"outcome":"victory"}).get("points",-1) == 0,"an empty token earns nothing")
	var unknown := service.apply_result_once("not-a-registered-token",{"outcome":"victory"})
	_check(not unknown.ok,"a result without a live registered match is refused")
	_check(store.problem.is_empty(),"the isolated profile store reports no problem")
	# --- 6. a fresh match starts clean and carries the frozen rules ---
	var fresh := TeamMatchState.new()
	_check(int(fresh.tickets[1]) == TeamMatchState.START_TICKETS and int(fresh.tickets[2]) == TeamMatchState.START_TICKETS,"a new match starts with full tickets")
	_check(fresh.roster.is_empty() and fresh.pending_deaths.is_empty() and fresh.drain_bank[1] == 0.0,"a new match starts with no roster, deaths or drain bank")
	_check(fresh.rules.label() == preset.label() and fresh.rule_fingerprint() == preset.fingerprint(),"a match carries the frozen rule label and fingerprint")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MATCH_RULES_CHECKS_PASS" if failed == 0 else "MATCH_RULES_CHECKS_FAIL")
	quit(1 if failed else 0)
