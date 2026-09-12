extends SceneTree
## Pure event admission/replay protocol. No ENet, world simulation or claim of
## completed reconnect integration; the production transport is tested separately.
const SESSION_A := "0123456789abcdef0123456789abcdef"
const SESSION_B := "fedcba9876543210fedcba9876543210"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func fresh() -> NetworkEventJournal:
	var journal := NetworkEventJournal.new()
	journal.reset(SESSION_A)
	return journal
func shot(projectile_id: int, shot_id: int = -1, entity: String = "A", life: int = 1, round_id: int = 1) -> Dictionary:
	return {"round_id":round_id,"projectile_id":projectile_id,"shooter_id":entity,"shooter_life_id":life,"shot_id":projectile_id if shot_id<0 else shot_id}
func launch() -> Dictionary:
	return {"shell_id":"test_ap","position":[0.0,2.0,0.0],"velocity":[0.0,0.0,-600.0],"gravity":[0.0,-9.81,0.0]}
func terminal() -> Dictionary: return {"reason":"impact_world","position":[0.0,0.0,-40.0]}
func fire(journal: NetworkEventJournal, id: int, tick: int, identity: Dictionary = {}) -> Dictionary:
	return journal.append("projectile_fired",tick,shot(id) if identity.is_empty() else identity,launch())
func finish(journal: NetworkEventJournal, id: int, tick: int, identity: Dictionary = {}) -> Dictionary:
	return journal.append("projectile_finished",tick,shot(id) if identity.is_empty() else identity,terminal())

func _initialize() -> void:
	var journal := NetworkEventJournal.new()
	check(not fire(journal,1,1).ok and not journal.read_after(0).ok,"uninitialized journal cannot silently create a stream")
	check(not journal.reset("session") and not journal.reset(SESSION_A.to_upper()) and journal.reset(SESSION_A),"session identifiers require the declared 16-byte lowercase hex token")
	var identity := shot(1)
	var payload := launch()
	var result := journal.append("projectile_fired",10,identity,payload)
	check(result.ok and result.event.sequence==1 and journal.active_count()==1,"first actual fire receives a sequence after semantic admission")
	check(NetworkEventJournal.valid_event(JSON.parse_string(JSON.stringify(result.event))),"event survives JSON numeric conversion under the exact schema")
	identity.shot_id=999; payload.position[0]=999; result.event.payload.velocity[2]=0
	var original: Dictionary=journal.read_after(0).batch.events[0]
	check(original.shot.shot_id==1 and original.payload.position[0]==0 and original.payload.velocity[2]==-600,"caller and returned dictionary mutation cannot rewrite journal facts")
	var active := journal.active_fired_events(); active[0].shot.shot_id=999
	check(journal.active_fired_events()[0].shot.shot_id==1,"active launch identities also expose copies")
	check(not journal.reset("bad") and not journal.reset(SESSION_A) and journal.head()==1,"invalid or same-session reset cannot reuse existing stream sequence numbers")
	check(not fire(journal,1,10).ok and journal.head()==1,"duplicate fire is rejected without consuming a journal sequence")
	check(not finish(journal,2,10).ok and journal.head()==1,"a finish without an admitted fire is rejected")
	check(not finish(journal,1,9).ok and journal.active_count()==1,"past physics ticks cannot reorder an accepted fire and finish")
	var changed := shot(1); changed.shooter_life_id=2
	check(not finish(journal,1,10,changed).ok and journal.active_count()==1,"finish cannot relabel a previous-life projectile as a new-life shot")
	changed=shot(1); changed.round_id=2
	check(not finish(journal,1,10,changed).ok,"finish cannot change the round identity")
	changed=shot(1); changed.shooter_id="B"
	check(not finish(journal,1,10,changed).ok,"finish cannot change the shooter identity")
	changed=shot(1); changed.shot_id=2
	check(not finish(journal,1,10,changed).ok,"finish cannot change the shot number")
	check(finish(journal,1,10).ok and journal.active_count()==0 and journal.head()==2,"same-tick fire then finish is valid and releases the active slot")
	check(not finish(journal,1,10).ok and journal.head()==2,"duplicate terminal callback cannot create another result")
	check(not fire(journal,2,11,shot(2,1)).ok and journal.head()==2,"new projectile id cannot reuse the same logical shooter shot")
	check(fire(journal,2,11).ok and fire(journal,3,12,shot(3,1,"A",2)).ok,"next shot and new-life first shot are admitted")
	check(finish(journal,2,13).ok,"an older-life projectile may legitimately finish after its shooter starts a new life")
	check(not fire(journal,4,14,shot(4,4,"A",1)).ok,"old shooter life cannot submit another fire after a newer life")
	check(fire(journal,4,14,shot(4,1,"A",2,2)).ok and not fire(journal,5,15,shot(5,9,"A",2,1)).ok,"new round has its own shot sequence while older-round fire is rejected")
	_schema_checks(original)
	_retention_checks()
	_capacity_checks()
	check(journal.reset(SESSION_B) and journal.head()==0 and journal.active_count()==0 and journal.retained_count()==0,"new server session explicitly clears event, active and shooter history")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_EVENT_JOURNAL_CHECKS_PASS" if failures==0 else "NETWORK_EVENT_JOURNAL_CHECKS_FAIL")
	quit(0 if failures==0 else 1)

func _schema_checks(valid: Dictionary) -> void:
	var numbers_rejected := true
	for invalid in [true,false,-1,0.5,NAN,INF,9007199254740992]:
		var event := valid.duplicate(true); event.sequence=invalid
		numbers_rejected=numbers_rejected and not NetworkEventJournal.valid_event(event)
	check(numbers_rejected,"booleans, fractions, nonfinite and unsafe integers cannot become event sequences")
	var identity_rejected := true
	for key in ["round_id","projectile_id","shooter_life_id","shot_id"]:
		for invalid in [0,true,1.5,NAN]:
			var event := valid.duplicate(true); event.shot[key]=invalid
			identity_rejected=identity_rejected and not NetworkEventJournal.valid_event(event)
	check(identity_rejected,"every shot identity counter must be a positive safe integer")
	var event := valid.duplicate(true); event.version=true
	check(not NetworkEventJournal.valid_event(event),"boolean schema version cannot pass as version one")
	event=valid.duplicate(true); event.version=2
	check(not NetworkEventJournal.valid_event(event),"unsupported event schema is rejected")
	event=valid.duplicate(true); event.kind="claimed_hit"
	check(not NetworkEventJournal.valid_event(event),"only authority fire and finish kinds are admitted")
	event=valid.duplicate(true); event.ammo=999
	check(not NetworkEventJournal.valid_event(event),"extra top-level fields fail exact event admission")
	event=valid.duplicate(true); event.shot.control_epoch=1
	check(not NetworkEventJournal.valid_event(event),"unfrozen lifecycle fields cannot be smuggled into shot identity")
	event=valid.duplicate(true); event.payload.measured_range_m=800
	check(not NetworkEventJournal.valid_event(event),"private range data cannot enter public projectile payloads")
	var vectors_rejected := true
	for bad in [[0,0],[0,0,0,0],[true,0,0],[NAN,0,0],[1000001,0,0],Vector3.ZERO]:
		event=valid.duplicate(true); event.payload.position=bad
		vectors_rejected=vectors_rejected and not NetworkEventJournal.valid_event(event)
	check(vectors_rejected,"wire vectors require three finite numeric array components within world bounds")
	event=valid.duplicate(true); event.payload.velocity=[0,0,0]
	var no_speed := not NetworkEventJournal.valid_event(event)
	event.payload.velocity=[10000,10000,0]
	check(no_speed and not NetworkEventJournal.valid_event(event),"initial velocity is nonzero and bounded by total speed, not just per-axis limits")
	event=valid.duplicate(true); event.payload.gravity=[0,-1001,0]
	check(not NetworkEventJournal.valid_event(event),"unbounded acceleration cannot enter a launch record")
	event=valid.duplicate(true); event.shot.shooter_id="A\nB"
	var control_char := not NetworkEventJournal.valid_event(event)
	event.shot.shooter_id="A".repeat(65)
	check(control_char and not NetworkEventJournal.valid_event(event),"identity labels are bounded printable protocol identifiers")
	var terminal_event := {"version":1,"sequence":2,"tick":10,"kind":"projectile_finished","shot":shot(1),"payload":terminal()}
	check(NetworkEventJournal.valid_event(terminal_event),"finish has its own exact public reason and position schema")
	terminal_event.payload.reason=""
	check(not NetworkEventJournal.valid_event(terminal_event),"empty terminal reason cannot masquerade as a committed result")
	var journal := fresh(); fire(journal,1,1)
	var head := journal.head()
	check(not journal.append("projectile_finished",2,shot(1),{"reason":"impact_world","position":[0,NAN,0]}).ok and journal.head()==head and journal.active_count()==1,"invalid append leaves sequence and active identity untouched atomically")
	journal._head=NetworkEventJournal.MAX_SAFE_INTEGER
	check(not fire(journal,2,2).ok and journal.head()==NetworkEventJournal.MAX_SAFE_INTEGER,"sequence exhaustion stops admission before JSON precision is lost")

func _retention_checks() -> void:
	var journal := fresh()
	var admitted := true
	for i in range(1,151):
		admitted=admitted and fire(journal,i,i).ok and finish(journal,i,i).ok
	check(admitted and journal.head()==300 and journal.oldest()==45 and journal.retained_count()==256,"300 valid facts retain exactly the declared 256-event window")
	var gap := journal.read_after(0)
	check(not gap.ok and gap.resync and gap.reason=="history_evicted" and gap.requested_after==0 and gap.oldest==45 and gap.head==300 and not gap.has("batch"),"evicted history produces explicit resync metadata with no invented replacement events")
	var result := journal.read_after(44)
	check(result.ok and result.batch.events.size()==16 and result.batch.events[0].sequence==45 and result.batch.events[-1].sequence==60,"retained boundary resumes with one bounded continuous batch")
	check(not journal.read_after(301).ok and not journal.read_after(-1).ok and not journal.read_after(true).ok and not journal.read_after(0.5).ok and not journal.read_after(44,17).ok,"future, malformed cursors and oversized batch requests are rejected")
	check(NetworkEventJournal.valid_batch(JSON.parse_string(JSON.stringify(result.batch))),"bounded event batch survives actual JSON wire conversion")
	var batch: Dictionary=result.batch.duplicate(true)
	var consumed := NetworkEventJournal.consume_batch(batch,SESSION_A,44)
	check(consumed.ok and consumed.cursor==60 and consumed.head==300 and consumed.events.size()==16,"client advances only through delivered records rather than jumping to journal head")
	var duplicate := NetworkEventJournal.consume_batch(batch,SESSION_A,60)
	check(duplicate.ok and duplicate.cursor==60 and duplicate.events.is_empty(),"reliable retransmission delivers no duplicate effects")
	var overlap := NetworkEventJournal.consume_batch(batch,SESSION_A,50)
	check(overlap.ok and overlap.cursor==60 and overlap.events.size()==10 and overlap.events[0].sequence==51,"partially acknowledged batch applies only its contiguous unseen suffix")
	check(not NetworkEventJournal.consume_batch(batch,SESSION_A,43).ok and NetworkEventJournal.consume_batch(batch,SESSION_A,43).reason=="gap","out-of-order delivery cannot skip a missing event")
	check(not NetworkEventJournal.consume_batch(batch,SESSION_B,44).ok,"delayed packets from another server session cannot advance the cursor")
	batch.events[-1].payload.position[0]=NAN
	check(not NetworkEventJournal.consume_batch(batch,SESSION_A,44).ok,"malformed final entry rejects the complete batch before any client cursor commit")
	batch=result.batch.duplicate(true); batch.events[1].sequence=45
	check(not NetworkEventJournal.valid_batch(batch),"duplicate sequence within a batch fails continuity checks")
	batch=result.batch.duplicate(true); batch.events[1].shot.shooter_life_id=999
	check(not NetworkEventJournal.valid_batch(batch),"in-batch fire and finish must carry exactly the same frozen shot identity")
	batch=result.batch.duplicate(true); batch.events[0].kind="projectile_finished"; batch.events[0].payload=terminal()
	check(not NetworkEventJournal.valid_batch(batch),"same projectile cannot finish twice under different event sequence numbers")
	batch=result.batch.duplicate(true); batch.events.clear()
	check(not NetworkEventJournal.valid_batch(batch),"empty batch cannot claim to cover a nonempty missing interval")
	batch=result.batch.duplicate(true); batch.hidden_damage={}
	check(not NetworkEventJournal.valid_batch(batch),"unknown batch fields fail strict transport admission")
	var end := journal.read_after(300)
	check(end.ok and end.batch.events.is_empty() and NetworkEventJournal.valid_batch(end.batch),"cursor at current head receives a valid empty batch")
	var cursor := 44
	var total := 0
	var replay_ok := true
	while cursor<journal.head():
		var page := journal.read_after(cursor)
		var step := NetworkEventJournal.consume_batch(page.batch,SESSION_A,cursor)
		if not step.ok: replay_ok=false; break
		cursor=step.cursor; total+=step.events.size()
	check(replay_ok and total==256 and cursor==300,"all retained events replay exactly once through successive bounded pages")
	check(not fire(journal,1,151).ok and not fire(journal,151,151,shot(151,1)).ok,"evicting old records does not permit reused projectile or shooter-shot identities")
	check(NetworkEventJournal.acknowledge({"session_id":SESSION_A,"cursor":60},SESSION_A,44,60).ok and NetworkEventJournal.acknowledge({"session_id":SESSION_A,"cursor":60},SESSION_A,60,60).ok,"fresh and duplicate acknowledgments are valid within the actual sent range")
	check(not NetworkEventJournal.acknowledge({"session_id":SESSION_A,"cursor":300},SESSION_A,44,60).ok,"knowing journal head cannot acknowledge events the server has never sent to that peer")
	check(not NetworkEventJournal.acknowledge({"session_id":SESSION_A,"cursor":43},SESSION_A,44,60).ok and not NetworkEventJournal.acknowledge({"session_id":SESSION_B,"cursor":60},SESSION_A,44,60).ok,"acknowledgments cannot regress or cross server sessions")
	check(not NetworkEventJournal.acknowledge({"session_id":SESSION_A,"cursor":true},SESSION_A,0,60).ok and not NetworkEventJournal.acknowledge({"session_id":SESSION_A,"cursor":60,"ammo":999},SESSION_A,0,60).ok,"ACK schema does not accept booleans or additional authority claims")

func _capacity_checks() -> void:
	var journal := fresh()
	var admitted := true
	for i in range(1,65): admitted=admitted and fire(journal,i,i).ok
	check(admitted and journal.active_count()==64 and not fire(journal,65,65).ok,"active identity storage cannot exceed the current projectile manager capacity")
	check(finish(journal,1,66).ok and fire(journal,65,67).ok and journal.active_count()==64,"one committed finish frees exactly one active admission slot")
	journal=fresh()
	for i in range(1,65):
		var identity := shot(i,1,"entity_%d"%i)
		fire(journal,i,i,identity); finish(journal,i,i,identity)
	check(journal._shooters.size()==64 and not fire(journal,65,65,shot(65,1,"overflow_entity")).ok,"deduplication watermarks remain bounded even across many distinct shooter identities")
