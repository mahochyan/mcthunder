extends SceneTree
# WT-037: room lifecycle, team balancing, load gating, host migration, continuous rounds
# without old-round pollution, small-scale matchmaking, and external services kept as
# explicitly unauthorised stand-ins.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] room suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _hello(version: int = 6, hash_value: String = "content-1", tier: int = 2) -> Dictionary:
	return {"version":version,"content_hash":hash_value,"tier":tier}
func _config() -> Dictionary:
	return {"mode":"normal","protocol_version":6,"content_hash":"content-1","region":"local","rules_id":MatchRulePreset.ID}
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. room creation and capacity ---
	var room := NetworkRoomService.new()
	_check(room.create_room("room-1",1,_config()).ok,"a room is created with a host")
	_check(room.state == "waiting" and room.capacity() == 8,"4v4 means eight seats (%d)"%room.capacity())
	_check(room.snapshot().rules_id == MatchRulePreset.ID,"the room carries the frozen rule preset id")
	var bad_mode := NetworkRoomService.new()
	_check(not bad_mode.create_room("room-x",1,{"mode":"ranked_global"}).ok,"an unknown mode is refused")
	_check(room.seat_count() == 0,"a fresh room has no seats")
	# --- 2. join feedback: capacity, version, content, authorization ---
	_check(room.join(1,_hello()).ok,"the host takes the first seat")
	_check(room.seat_count() == 1,"the seat is recorded once")
	var resumed := room.join(1,_hello())
	_check(resumed.ok and bool(resumed.resumed) and room.seat_count() == 1,"a duplicate join resumes the same seat instead of adding another")
	_check(str(room.join(50,_hello(5)).reason) == "version_mismatch","a protocol mismatch is reported clearly")
	_check(str(room.join(51,_hello(6,"content-9")).reason) == "content_mismatch","a content hash mismatch is reported clearly")
	var expired := _hello(); expired["authorization_expired"] = true
	_check(str(room.join(52,expired).reason) == "authorization_expired","an expired authorization has its own feedback")
	for peer in range(2,9): room.join(peer,_hello())
	_check(room.seat_count() == 8,"the room fills to capacity")
	_check(str(room.join(99,_hello()).reason) == "room_full","a ninth player is refused with room_full")
	_check(room.team_count(1) == 4 and room.team_count(2) == 4,"eight seats balance four against four")
	# --- 3. no control before every seat confirmed loading ---
	_check(not room.controls_allowed(1),"nobody may control a vehicle before the round starts")
	var first_load := room.mark_loaded(1)
	_check(first_load.ok and not bool(first_load.started) and room.state == "loading","one loaded seat moves the room to loading, not playing")
	_check(not room.controls_allowed(1),"a single loaded seat still cannot drive")
	for peer in range(2,10):
		if room.seats.has(peer): room.mark_loaded(peer)
	_check(room.state == "playing" and room.all_loaded(),"the room plays only once every seat is loaded")
	_check(room.controls_allowed(1) and room.controls_allowed(8),"loaded seats may now control their vehicles")
	_check(not room.controls_allowed(99),"a peer without a seat never controls anything")
	_check(str(room.mark_loaded(99).reason) == "unknown_peer","an unknown peer cannot mark loading")
	# --- 4. host migration and dedicated servers ---
	var leaving_host := room.leave(1)
	_check(leaving_host.ok and bool(leaving_host.host_changed) and int(leaving_host.host) == 2,"when the host leaves in a client room the lowest remaining peer inherits it")
	_check(room.seat_count() == 7,"the departed seat is gone")
	var dedicated := NetworkRoomService.new()
	dedicated.create_room("room-dedicated",1,{"mode":"dedicated","protocol_version":6,"content_hash":"content-1","region":"local"})
	dedicated.join(1,_hello())
	dedicated.join(2,_hello())
	var host_left := dedicated.leave(1)
	_check(host_left.ok and not bool(host_left.host_changed) and dedicated.state != "closed","a dedicated server keeps the room when a client leaves")
	var single := NetworkRoomService.new()
	single.create_room("room-single",5,_config())
	single.join(5,_hello())
	_check(not bool(single.leave(5).room_open),"a client room closes when its last seat leaves")
	_check(str(room.leave(777).reason) == "unknown_peer","leaving without a seat is refused")
	# --- 5. settle once, then a clean next round ---
	var receipts := NetworkResultReceipt.new()
	var digest := "round-digest-1"
	var settled := room.settle({"outcome":"victory"},receipts,digest)
	_check(settled.ok and room.state == "settled","settling a playing round freezes it")
	_check(room.receipts_issued == 1,"the round issues exactly one receipt")
	_check(str(settled.receipt.trust) == NetworkResultReceipt.TRUST_HOST,"a client-hosted room's receipt is labelled host_self_hosted")
	_check(not room.settle({"outcome":"victory"},receipts,digest).ok,"a settled round cannot be settled twice")
	room.accept_round_event({"round":1,"kind":"kill"})
	_check(room.snapshot().round_events == 1,"a current-round event is accepted")
	var next_round := room.begin_next_round()
	_check(next_round.ok and int(next_round.round) == 2 and room.snapshot().round_events == 0,"opening the next round clears every round-local event")
	_check(int(next_round.previous) == 1,"the previous round id is recorded for traceability")
	_check(str(room.accept_round_event({"round":1,"kind":"late_kill"}).reason) == "stale_round","a late event from the old round is refused")
	_check(room.accept_round_event({"round":2,"kind":"kill"}).ok,"an event from the current round is accepted")
	var unloaded := true
	for peer in room.seats:
		if bool(room.seats[peer].loaded): unloaded = false
	_check(unloaded and room.state == "ready_check","the next round starts unready for every continuing seat")
	_check(not room.controls_allowed(2),"nobody drives in the new round before loading it")
	var dedicated_receipts := NetworkResultReceipt.new()
	_check(not NetworkRoomService.new().settle({"outcome":"victory"},dedicated_receipts,"d").ok,"a round that is not playing cannot be settled")
	# --- 6. small-scale matchmaking ---
	var service := NetworkRoomService.new()
	var pool: Array = []
	for i in 8: pool.append({"peer":i,"mode":"normal","content_hash":"content-1","region":"local","tier":2})
	var grouped := service.matchmake(pool)
	_check(grouped.rooms.size() == 1 and str(grouped.fallback) == "single_room","eight compatible players form one room without a global service")
	_check(int(grouped.rooms[0].players.size()) == 8,"the room holds all eight players")
	var mixed: Array = []
	for i in 3: mixed.append({"peer":i,"mode":"normal","content_hash":"content-1","region":"local","tier":2})
	for i in 3: mixed.append({"peer":10+i,"mode":"normal","content_hash":"content-2","region":"local","tier":2})
	_check(service.matchmake(mixed).groups == 2,"different content hashes are grouped separately")
	var spread: Array = []
	for i in 4: spread.append({"peer":i,"mode":"normal","content_hash":"content-1","region":"local","tier":1})
	for i in 4: spread.append({"peer":20+i,"mode":"normal","content_hash":"content-1","region":"local","tier":5})
	var spread_result := service.matchmake(spread)
	_check(spread_result.unmatched.size() >= 4,"a tier spread beyond the design value is left unmatched")
	_check(NetworkRoomService.MATCHMAKING.max_tier_spread == 1,"the tier spread is a small design value, not a copied ranking system")
	# --- 7. external services stay unauthorised stand-ins ---
	var proposal := NetworkRoomService.external_service_proposal()
	_check(proposal.size() == 4,"discovery, relay, dedicated hosting and accounts are proposed separately")
	var all_unauthorised := true
	for row in proposal:
		if not bool(row.requires_authorization) or str(row.stand_in).is_empty(): all_unauthorised = false
	_check(all_unauthorised,"every external service is explicitly unauthorised and has a local stand-in")
	# --- 8. loopback and public evidence are registered apart ---
	_check(service.register_test_scope("loopback").ok and not service.snapshot().test_scope.is_empty(),"a loopback run is registered")
	_check(not bool(service.register_test_scope("loopback").public_tested),"a loopback run is not reported as a public test")
	_check(bool(service.register_test_scope("public").public_tested),"the public scope is labelled when explicitly registered")
	_check(str(service.register_test_scope("wan").reason) == "unknown_scope","an unknown scope is refused")
	var ui := service.ui_contract()
	_check(ui.must_show.size() >= 5,"the room UI contract lists what must be shown")
	_check(str(ui.must_block[0]).contains("drive"),"the UI contract forbids driving before loading completes")
	_check(str(ui.window_suite) == "NOT_RUN","the window room UI is honestly marked NOT_RUN")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("ROOM_SERVICE_CHECKS_PASS" if failed == 0 else "ROOM_SERVICE_CHECKS_FAIL")
	quit(1 if failed else 0)
