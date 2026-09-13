extends SceneTree
# WT-026: identity, bounded command validation and online result trust. Another player's
# entity is refused, malformed or out-of-range fields never reach the simulation, message
# and command rates are bounded, only logical resource ids are accepted, sensitive fields
# never reach a log, reconnect/expiry/errors are separate outcomes, and online rewards come
# from idempotent authority receipts in a domain a local save cannot mint.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] identity suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _envelope(sequence: int, tick: int, body: Dictionary, entity: String = "A") -> Dictionary:
	return {"version":3,"entity_id":entity,"life_id":7,"generation":1,"control_epoch":0,"sequence":sequence,"input_tick":tick,"command":body}
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. permission mapping ---
	var policy := NetworkIdentityPolicy.new()
	_check(policy.bind(1,"session-a","A",7,"player").ok,"a player binds to one entity for its session")
	_check(policy.bind(2,"session-b","B",7,"observer").ok,"an observer binds with its own role")
	_check(not policy.bind(3,"","C",7,"player").ok,"an empty session id is refused")
	_check(not policy.bind(4,"session-d","D",7,"admin").ok,"an unknown role is refused")
	_check(policy.authorizes(1,"command","A").ok,"the owner may command its own entity")
	var stolen := policy.authorizes(1,"command","B")
	_check(not stolen.ok and str(stolen.reason) == "not_owner","another player's entity is refused")
	_check(not policy.authorizes(2,"command","B").ok,"an observer role cannot command at all")
	_check(not policy.authorizes(9,"command","A").ok and str(policy.authorizes(9,"command","A").reason) == "handshake_required","an unbound peer must handshake first")
	# --- 2. bounded command validation and no state pollution ---
	var accepted := policy.validate_command(1,_envelope(0,100,{"throttle":1.0,"steer":-1.0,"fire_requested":true}),100)
	_check(accepted.ok,"a well-formed command inside every range is accepted")
	var before_sequence: int = int(policy.sessions[1].last_sequence)
	var forged := policy.validate_command(1,_envelope(1,100,{"throttle":0.5},"B"),100)
	_check(not forged.ok and str(forged.reason) == "not_owner","a forged entity id is refused")
	_check(int(policy.sessions[1].last_sequence) == before_sequence,"a refused command does not advance the sequence")
	var replay := policy.validate_command(1,_envelope(0,100,{"throttle":0.5}),100)
	_check(not replay.ok and str(replay.reason) == "stale_sequence","replaying an old sequence is refused")
	var gap := policy.validate_command(1,_envelope(before_sequence+NetworkIdentityPolicy.MAX_SEQUENCE_GAP+1,100,{"throttle":0.5}),100)
	_check(not gap.ok and str(gap.reason) == "sequence_gap_too_large","an implausible sequence jump is refused")
	_check(not policy.validate_command(1,_envelope(before_sequence+1,100-NetworkIdentityPolicy.MAX_INPUT_AGE_TICKS-1,{"throttle":0.5}),100).ok,"input older than the age window is refused")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,120,{"throttle":0.5}),100).reason) == "stale_input_tick","input from the future is refused")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"throttle":NAN}),100).reason) == "non_finite_field","NaN never reaches the simulation")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"throttle":INF}),100).reason) == "non_finite_field","Inf never reaches the simulation")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"throttle":5.0}),100).reason) == "field_out_of_range","an out-of-range throttle is refused")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"gun_pitch":9.0}),100).reason) == "field_out_of_range","an out-of-range gun pitch is refused")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"fire_requested":1}),100).reason) == "invalid_flag_type","a non-boolean flag is refused")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"aim_world_point":Vector3(NAN,0,0)}),100).reason) == "non_finite_field","a NaN aim point is refused")
	_check(str(policy.validate_command(1,_envelope(before_sequence+1,100,{"aim_world_point":Vector3(99999,0,0)}),100).reason) == "field_out_of_range","an aim point outside the world is refused")
	_check(str(policy.validate_command(1,{"entity_id":"A","command":{}},100).reason) == "malformed_envelope","an envelope without a sequence is refused")
	var poisoned: int = int(policy.sessions[1].last_sequence)
	_check(poisoned == before_sequence,"after every refusal the sequence is still the last accepted one")
	# --- 3. bounded message and command frequency ---
	_check(not policy.allow_message(1,"command",NetworkIdentityPolicy.MAX_MESSAGES_PER_TICK+1).ok,"a per-tick message flood is refused")
	var normal_rate := policy.allow_message(1,"command",1)
	_check(normal_rate.ok,"a normal message rate is allowed")
	var flood := NetworkIdentityPolicy.new()
	flood.bind(1,"s","A",7,"player")
	var refused_at := -1
	for i in 40:
		var verdict := flood.allow_message(1,"command",1,float(i)*0.01)
		if not verdict.ok and refused_at < 0: refused_at = i
	_check(refused_at > 0 and refused_at <= NetworkIdentityPolicy.MAX_COMMANDS_PER_SECOND+1,"the per-second command rate is bounded (first refusal at %d)"%refused_at)
	_check(not policy.allow_message(1,"kill_self",1).ok,"an unknown message kind is refused")
	# --- 4. logical resource ids only ---
	_check(policy.resource_id_allowed("vehicle:us_m4a3_75w_vvss_1944"),"a logical vehicle id is allowed")
	_check(policy.resource_id_allowed("shell:ap_m61"),"a logical shell id is allowed")
	for bad in ["res://scripts/network/server_main.gd","user://profiles/commander","../../secret","GDScript","https://example.invalid/x"]:
		_check(not policy.resource_id_allowed(bad),"a client cannot name %s"%bad)
	_check(str(policy.validate_resource_request("res://scripts/network/server_main.gd").reason) == "resource_id_not_allowed","an arbitrary path request is refused by name")
	# --- 5. sensitive fields never reach a log ---
	var safe := policy.log_safe({"entity_id":"A","session_id":"s","token":"abc","secret":"xyz","password":"p","authorization":"bearer"})
	_check(safe.has("entity_id") and not safe.has("token") and not safe.has("secret"),"sensitive session fields are stripped from log payloads")
	_check(not safe.has("password") and not safe.has("authorization"),"credentials never appear in a log payload")
	# --- 6. reconnect, expiry and error feedback are separate ---
	_check(policy.rebind_token(1,"new-token").reason == "reconnect_token_accepted","a reconnect token has its own outcome")
	_check(policy.rebind_token(99,"t").reason == "unknown_peer","an unknown peer's token is refused")
	_check(policy.rebind_token(1,"").reason == "invalid_reconnect_token","an empty token is its own refusal")
	var expired := policy.expire_authorization(1)
	_check(expired.ok and str(expired.feedback) == "authorization","expiry reports authorization feedback, not an error")
	_check(str(policy.authorizes(1,"command","A").reason) == "handshake_required","an expired session must handshake again")
	# --- 7. idempotent receipts in a trusted domain ---
	var receipts := NetworkResultReceipt.new()
	var authority := {"phase":"finished","digest":"d1g3st"}
	var unfinished := NetworkResultReceipt.new().issue("t0","s","d1g3st",{"outcome":"victory"},{"phase":"playing","digest":"d1g3st"})
	_check(not unfinished.ok and str(unfinished.reason) == "match_not_finished","only a finished match can issue a receipt")
	_check(str(receipts.issue("t1","s","wrong",{"outcome":"victory"},authority).reason) == "digest_mismatch","a receipt must match the frozen result digest")
	_check(str(receipts.issue("t2","s","d1g3st",{"outcome":"unknown"},authority).reason) == "unknown_outcome","an unknown outcome cannot be rewarded")
	var issued := receipts.issue("t3","s","d1g3st",{"outcome":"victory"},authority)
	_check(issued.ok and int(issued.receipt.points) == 60,"a valid finished result issues a 60-point receipt")
	_check(receipts.issue("t3","s","d1g3st",{"outcome":"victory"},authority).duplicate,"re-issuing the identical receipt is harmless")
	_check(str(receipts.issue("t3","s","d1g3st",{"outcome":"defeat"},authority).reason) == "receipt_conflict","a conflicting re-issue of the same token is refused")
	receipts.issue("t4","s","d1g3st",{"outcome":"draw"},authority)
	var mismatched := receipts.claim("t4","wrong")
	_check(not mismatched.ok and str(mismatched.reason) == "digest_mismatch","a claim with a mismatched digest is refused")
	var first := receipts.claim("t3","d1g3st")
	_check(first.ok and int(first.points) == 60 and receipts.online_points == 60,"the first claim pays once")
	var second := receipts.claim("t3","d1g3st")
	_check(second.duplicate and int(second.points) == 0 and receipts.online_points == 60,"a repeated claim adds no earnings")
	_check(str(receipts.claim("fabricated","d1g3st").reason) == "no_receipt","a claim without an issued receipt is refused")
	# --- 8. local save cannot mint a trusted result; network errors keep the save ---
	receipts.edit_offline_save(9999)
	_check(str(receipts.claim("fabricated-2","d1g3st").reason) == "no_receipt","editing the local save cannot create a receipt")
	_check(receipts.online_points == 60,"the trusted online points are unchanged by the local edit")
	var failed_claim := receipts.claim("t4","wrong")
	_check(not failed_claim.ok and receipts.domains().offline_research.points == 9999,"a failed online claim never deletes the offline save")
	_check(receipts.domains().offline_research.can_mint_receipt == false,"the offline domain is declared unable to mint receipts")
	var host := NetworkResultReceipt.new()
	host.issue("h1","s","d1g3st",{"outcome":"victory"},authority,NetworkResultReceipt.TRUST_HOST)
	_check(str(host.receipts["h1"].trust) == "host_self_hosted","a self-hosted host's receipt is labelled with its trust level")
	_check(not host.trusted_result_tokens().has("h1"),"a self-hosted receipt is not counted as an authority result")
	_check(NetworkIdentityPolicy.trust_label(true) == "host_self_hosted" and NetworkIdentityPolicy.trust_label(false) == "authority_server","host trust is labelled explicitly")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("NETWORK_IDENTITY_CHECKS_PASS" if failed == 0 else "NETWORK_IDENTITY_CHECKS_FAIL")
	quit(1 if failed else 0)
