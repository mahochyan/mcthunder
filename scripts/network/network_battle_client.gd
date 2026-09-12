class_name NetworkBattleClient
extends Node
signal snapshot_received(snapshot: Dictionary)
signal public_events_received(events: Array)
signal event_recovery_changed(info: Dictionary)
signal session_finished
signal disconnected
var peer := ENetMultiplayerPeer.new()
var entity_id := ""
var session_id := ""
var latest: Dictionary = {}
var own_status: Dictionary = {}
var status := "disconnected"
var sequence := 0
var last_sent_tick := -1
var connected_at := 0
var hello_sent := false
# Event checkpoint survives transport reconnect. It grants no vehicle ownership.
var event_session := ""
var event_cursor := 0
var event_head := 0
var active_projectiles: Dictionary = {}
var recent_events: Array[Dictionary] = []
var recovery_state := ""
var skipped_events := 0
var final_payload := ""
var _awaiting_baseline := true
var _last_baseline: Dictionary = {}
var _event_max_projectile := 0
var _last_event_tick := -1
var _last_replay_request_tick := -100

func connect_local(port: int) -> Error:
	close()
	var error := peer.create_client("127.0.0.1",port,2)
	if error==OK: status="connecting"; connected_at=Time.get_ticks_msec()
	return error
func close() -> void:
	peer.close(); entity_id=""; session_id=""; latest.clear(); own_status.clear()
	sequence=0; last_sent_tick=-1; hello_sent=false; final_payload=""
	_awaiting_baseline=true; _last_replay_request_tick=-100; status="disconnected"
func send(message: Dictionary) -> void:
	if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	peer.set_target_peer(1); peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
func _ready() -> void: process_physics_priority=-100
static func valid_own_status(value: Variant, row: Dictionary) -> bool:
	if not value is Dictionary or value.size()!=5: return false
	for key in ["cooldown","speed"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])): return false
	if float(value.cooldown)<0: return false
	if not VehicleCommandCodec.integer(value.get("ammo")) or int(value.ammo)<0: return false
	if not VehicleCommandCodec.integer(value.get("consumed_sequence")) or int(value.consumed_sequence)<-1: return false
	if not VehicleCommandCodec.integer(row.get("accepted_sequence")) or int(value.consumed_sequence)>int(row.accepted_sequence): return false
	return FireControlState.valid_snapshot(value.get("fire_control"))
func _physics_process(_delta: float) -> void:
	if status=="disconnected": return
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED or (status in ["connecting","synchronizing"] and Time.get_ticks_msec()-connected_at>5000):
		close(); disconnected.emit(); return
	peer.poll()
	if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	if not hello_sent:
		var resume: Variant={"session_id":event_session,"cursor":event_cursor} if NetworkEventJournal.valid_session(event_session) else null
		send({"type":"hello","version":VehicleFramePose.NETWORK_VERSION,"resume":resume}); hello_sent=true
	var count := 0
	while peer.get_available_packet_count()>0 and count<32:
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet(); count+=1
		if sender!=1 or packet.size()>65536: continue
		var message: Variant=JSON.parse_string(packet.get_string_from_utf8())
		if message is Dictionary: accept_message(message)
	if not _awaiting_baseline and event_head>event_cursor: request_events()
func request_events() -> void:
	if session_id.is_empty() or _awaiting_baseline or Engine.get_physics_frames()-_last_replay_request_tick<6: return
	_last_replay_request_tick=Engine.get_physics_frames()
	send({"type":"events_request","session_id":session_id,"after":event_cursor})
func _ack_events() -> void:
	send({"type":"events_ack","ack":{"session_id":session_id,"cursor":event_cursor}})
func _ack_baseline(snapshot_sequence: int, cursor: int) -> void:
	send({"type":"baseline_ack","session_id":session_id,"cursor":cursor,"snapshot_sequence":snapshot_sequence})
func _valid_snapshot(snapshot: Variant, stats: Variant) -> bool:
	if not NetworkPoseBuffer.valid_snapshot(snapshot) or snapshot.session_id!=session_id: return false
	if int(snapshot.sequence)<int(latest.get("sequence",-1)) or int(snapshot.tick)<int(latest.get("tick",-1)): return false
	if int(snapshot.event_sequence)<int(latest.get("event_sequence",0)): return false
	for row in snapshot.vehicles:
		if row.entity_id==entity_id: return valid_own_status(stats,row)
	return false
func _commit_snapshot(snapshot: Dictionary, stats: Dictionary, baseline: bool = false, announce: bool = true) -> void:
	if baseline or int(snapshot.sequence)>int(latest.get("sequence",-1)):
		own_status=stats.duplicate(true); latest=snapshot.duplicate(true)
		event_head=maxi(event_head,int(snapshot.event_sequence))
		if announce: snapshot_received.emit(latest.duplicate(true))
func _welcome(message: Dictionary) -> bool:
	if message.size()!=5 or not VehicleCommandCodec.integer(message.get("version")) or message.version!=VehicleFramePose.NETWORK_VERSION: return false
	if not NetworkEventJournal.identifier(message.get("entity_id")) or not NetworkEventJournal.valid_session(message.get("session_id")) or message.get("recovery") not in ["baseline","resume"]: return false
	if not session_id.is_empty(): return session_id==message.session_id and entity_id==message.entity_id
	if message.recovery=="resume" and event_session!=message.session_id: return false
	session_id=message.session_id; entity_id=message.entity_id
	if event_session!=session_id:
		event_session=session_id; event_cursor=0; event_head=0; active_projectiles.clear(); recent_events.clear()
		_event_max_projectile=0; _last_event_tick=-1; _last_baseline.clear(); skipped_events=0
	_awaiting_baseline=message.recovery=="baseline"
	recovery_state="synchronizing" if _awaiting_baseline else "resume"
	status="synchronizing"
	return true
func _baseline(message: Dictionary) -> bool:
	if message.size()!=4 or session_id.is_empty(): return false
	var snapshot: Variant=message.get("snapshot")
	var checkpoint: Variant=message.get("checkpoint")
	if not NetworkPoseBuffer.valid_snapshot(snapshot) or snapshot.session_id!=session_id or not NetworkEventJournal.valid_checkpoint(checkpoint,snapshot): return false
	var owner_valid := false
	for row in snapshot.vehicles:
		if row.entity_id==entity_id: owner_valid=valid_own_status(message.get("own_status"),row)
	if not owner_valid: return false
	var identity := {"session_id":session_id,"snapshot_sequence":int(snapshot.sequence),"cursor":int(checkpoint.cursor)}
	if identity==_last_baseline:
		_ack_baseline(identity.snapshot_sequence,identity.cursor); return true
	if not _valid_snapshot(snapshot,message.get("own_status")) or int(checkpoint.cursor)<event_cursor: return false
	if checkpoint.reason=="history_evicted" and int(checkpoint.after)>event_cursor: return false
	# The server's after is its last ACK; packets may already have been applied
	# locally while their ACK was lost. Count only this client's unseen suffix.
	var skipped_delta := int(checkpoint.cursor)-event_cursor
	var active := {}
	var maximum := 0
	for projectile in checkpoint.active_projectiles:
		var id := int(projectile.shot.projectile_id)
		active[id]=projectile.duplicate(true); maximum=maxi(maximum,id)
	# Current public state, private status, active identities and cursor commit
	# together. Historical transient effects are deliberately not replayed.
	active_projectiles=active; _event_max_projectile=maximum
	_last_event_tick=int(snapshot.tick); event_cursor=int(checkpoint.cursor)
	event_head=maxi(event_head,event_cursor); _last_baseline=identity
	if checkpoint.reason=="history_evicted": skipped_events+=skipped_delta
	recent_events.clear(); _awaiting_baseline=false; recovery_state=checkpoint.reason
	if final_payload.is_empty(): status="connected"
	# Every observer sees one coherent checkpoint, including private owner data.
	# Recovery clears presentation buffers before the corresponding pose signal.
	_commit_snapshot(snapshot,message.own_status,true,false)
	event_recovery_changed.emit({"reason":recovery_state,"cursor":event_cursor,"skipped":skipped_events,"active":active_projectiles.size()})
	if session_id!=identity.session_id or int(latest.get("sequence",-1))!=identity.snapshot_sequence: return true
	snapshot_received.emit(latest.duplicate(true))
	# A callback may close/reconnect. Do not dispatch the previous session's ACK.
	if session_id!=identity.session_id or int(latest.get("sequence",-1))!=identity.snapshot_sequence: return true
	_ack_baseline(identity.snapshot_sequence,identity.cursor)
	_try_finish()
	return true
func _events(message: Dictionary) -> bool:
	if message.size()!=2 or session_id.is_empty() or _awaiting_baseline: return false
	var result := NetworkEventJournal.consume_batch(message.get("batch"),session_id,event_cursor)
	if not result.ok:
		if result.get("reason")=="gap": request_events()
		return false
	if not final_payload.is_empty() and int(result.head)>int(latest.event_sequence): return false
	var active: Dictionary=active_projectiles.duplicate(true)
	var maximum := _event_max_projectile
	var previous_tick := _last_event_tick
	for event in result.events:
		if int(event.tick)<previous_tick: return false
		previous_tick=int(event.tick)
		var id := int(event.shot.projectile_id)
		if event.kind=="projectile_fired":
			if id<=maximum or active.has(id) or active.size()>=NetworkEventJournal.MAX_ACTIVE: return false
			maximum=id
			active[id]={"shot":event.shot.duplicate(true),"shell_id":event.payload.shell_id,"position":event.payload.position.duplicate(),
				"velocity":event.payload.velocity.duplicate(),"gravity":event.payload.gravity.duplicate(),"age_s":0.0}
		else:
			if not active.has(id) or NetworkEventJournal._shot_copy(active[id].shot)!=NetworkEventJournal._shot_copy(event.shot): return false
			active.erase(id)
	active_projectiles=active; _event_max_projectile=maximum; _last_event_tick=previous_tick
	event_cursor=result.cursor; event_head=maxi(event_head,int(result.head))
	for event in result.events:
		recent_events.append(event.duplicate(true))
		if recent_events.size()>NetworkEventJournal.CAPACITY: recent_events.pop_front()
	_ack_events()
	if not result.events.is_empty(): public_events_received.emit(result.events.duplicate(true))
	if event_cursor==event_head and recovery_state=="resume":
		recovery_state="recovered"; event_recovery_changed.emit({"reason":recovery_state,"cursor":event_cursor,"skipped":skipped_events,"active":active_projectiles.size()})
	_try_finish()
	return true
func _try_finish() -> void:
	if final_payload.is_empty() or _awaiting_baseline or event_cursor!=int(latest.get("event_sequence",-1)) or not active_projectiles.is_empty(): return
	_ack_events()
	send({"type":"final_ack","session_id":session_id,"cursor":event_cursor,"digest":final_payload.sha256_text()})
	if status!="finished":
		status="finished"; session_finished.emit()
func accept_message(message: Dictionary) -> bool:
	match message.get("type"):
		"welcome": return _welcome(message)
		"baseline": return _baseline(message)
		"events": return _events(message)
		"snapshot","final":
			if message.size()!=3 or _awaiting_baseline or session_id.is_empty(): return false
			if message.type=="snapshot" and not final_payload.is_empty(): return false
			var snapshot: Variant=message.get("snapshot")
			if message.type=="final":
				if not message.get("payload") is String or (not final_payload.is_empty() and message.payload!=final_payload): return false
				snapshot=JSON.parse_string(message.payload)
			if not _valid_snapshot(snapshot,message.get("own_status")): return false
			if message.type=="final":
				final_payload=message.payload
				if status!="finished": status="finishing"
			elif status=="synchronizing": status="connected"
			_commit_snapshot(snapshot,message.own_status)
			_try_finish()
			return true
		"rejected":
			if message.size()!=2 or not message.get("reason") is String: return false
			if message.reason=="session_finished" and status in ["connecting","synchronizing"]: status="finished"
			return true
	return false
func submit(command: VehicleCommand) -> bool:
	if status!="connected" or latest.is_empty() or int(latest.tick)==last_sent_tick: return false
	for row in latest.vehicles:
		if row.entity_id!=entity_id: continue
		var body := VehicleCommandCodec.encode_body(command)
		var envelope := {"version":VehicleCommandCodec.VERSION,"entity_id":entity_id,"life_id":row.life_id,"generation":row.generation,"control_epoch":row.control_epoch,"sequence":sequence,"input_tick":latest.tick,"command":body}
		send({"type":"command","envelope":envelope}); sequence+=1; last_sent_tick=int(latest.tick)
		return true
	return false
func _exit_tree() -> void: peer.close()
