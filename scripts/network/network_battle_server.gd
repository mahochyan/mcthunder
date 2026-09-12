class_name NetworkBattleServer
extends Node
## Explicit loopback-only technical session, not an internet lobby/account server.
const VERSION := VehicleFramePose.NETWORK_VERSION
const MAX_PACKET_BYTES := 4096
var peer := ENetMultiplayerPeer.new()
var world: NetworkBattleWorld
var owners: Dictionary = {}
var event_peers: Dictionary = {}
var accepted := 0
var rejected: Dictionary = {}
var snapshot_sequence := 0
var final_snapshot: Dictionary = {}
var final_payload := ""
var final_acks: Dictionary = {}
var per_tick_packets: Dictionary = {}
var last_completed_tick := -1
var _finish_requested := false
var _final_status: Dictionary = {}

class Publisher extends Node:
	var server: NetworkBattleServer
	func _physics_process(_delta: float) -> void: server._publish()

func start(port: int) -> Error:
	process_physics_priority=-100
	peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(port,2,2)
	if error!=OK: return error
	peer.peer_disconnected.connect(disconnect_owner)
	world=NetworkBattleWorld.new(); add_child(world)
	var publisher := Publisher.new(); publisher.server=self
	publisher.process_physics_priority=SimulationPhases.SNAPSHOT; add_child(publisher)
	return OK if world.ready_ok else ERR_CANT_CREATE
func send_to(id: int, message: Dictionary) -> void:
	peer.set_target_peer(id); peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
func reject(id: int, reason: String) -> void:
	rejected[reason]=int(rejected.get(reason,0))+1
	send_to(id,{"type":"rejected","reason":reason})
func disconnect_owner(id: int) -> void:
	event_peers.erase(id); final_acks.erase(id)
	if not owners.has(id): return
	var controller: NetworkController=owners[id]
	controller.vehicle.clear_commands(); controller.vehicle.set_controller(null)
	controller.queue_free(); owners.erase(id)
func _snapshot() -> Dictionary:
	if not final_snapshot.is_empty(): return final_snapshot.duplicate(true)
	snapshot_sequence+=1
	return world.snapshot(snapshot_sequence)
func _queue_baseline(id: int, reason: String, after: int) -> void:
	event_peers[id].baseline_request={"reason":reason,"after":after}
func _awaiting_baseline(stream: Dictionary) -> bool:
	return not stream.baseline.is_empty() or not stream.baseline_request.is_empty()
func _send_baseline(id: int, snapshot: Dictionary) -> void:
	var request: Dictionary=event_peers[id].baseline_request
	var checkpoint := {"version":NetworkEventJournal.VERSION,"session_id":world.journal.session_id,
		"cursor":snapshot.event_sequence,"after":request.after,"reason":request.reason,"active_projectiles":world.active_projectiles()}
	var message := {"type":"baseline","snapshot":snapshot,"own_status":world.own_status(owners[id].vehicle),"checkpoint":checkpoint}
	event_peers[id].baseline=message.duplicate(true)
	event_peers[id].baseline_request.clear()
	event_peers[id].sent=maxi(event_peers[id].sent,int(checkpoint.cursor))
	event_peers[id].baseline_tick=Engine.get_physics_frames()
	send_to(id,message)
func _send_events(id: int, requested_after: int = -1) -> void:
	var stream: Dictionary=event_peers[id]
	if _awaiting_baseline(stream): return
	var cursor := int(stream.ack) if requested_after<0 else requested_after
	var result := world.journal.read_after(cursor)
	if not result.ok:
		if result.get("resync",false): _queue_baseline(id,"history_evicted",cursor)
		else: reject(id,result.reason)
		return
	if result.batch.events.is_empty(): return
	stream.sent=maxi(stream.sent,int(result.batch.events[-1].sequence))
	send_to(id,{"type":"events","batch":result.batch})
func _welcome(id: int, recovery: String) -> void:
	send_to(id,{"type":"welcome","version":VERSION,"entity_id":owners[id].vehicle.entity_id,"session_id":world.journal.session_id,"recovery":recovery})
func _hello(id: int, message: Dictionary) -> void:
	if not VehicleCommandCodec.integer(message.get("version")) or int(message.version)!=VERSION: reject(id,"unsupported_version"); return
	if message.size()!=3 or not message.has("resume"): reject(id,"invalid_hello"); return
	var resume: Variant=message.resume
	if resume!=null and (not resume is Dictionary or resume.size()!=2 or not NetworkEventJournal.valid_session(resume.get("session_id")) or not NetworkEventJournal.integer(resume.get("cursor"))): reject(id,"invalid_resume"); return
	if not owners.has(id) and (_finish_requested or not final_snapshot.is_empty()): reject(id,"session_finished"); return
	if owners.has(id):
		_welcome(id,"baseline" if _awaiting_baseline(event_peers[id]) else "resume")
		return
	var same_session: bool=resume is Dictionary and resume.session_id==world.journal.session_id
	if same_session and int(resume.cursor)>world.journal.head(): reject(id,"future_cursor"); return
	var claimed: Array=[]
	for controller in owners.values(): claimed.append(controller.vehicle)
	for actor in world.actors:
		if actor in claimed: continue
		var controller := NetworkController.new(); controller.vehicle=actor; add_child(controller)
		actor.set_controller(controller); owners[id]=controller; break
	if not owners.has(id): reject(id,"session_full"); return
	var cursor := int(resume.cursor) if same_session else 0
	event_peers[id]={"ack":cursor,"sent":cursor,"baseline":{},"baseline_request":{},"baseline_tick":-1,"needs_snapshot":true}
	var can_resume := same_session and cursor>=world.journal.oldest()-1
	_welcome(id,"resume" if can_resume else "baseline")
	if not can_resume:
		_queue_baseline(id,"history_evicted" if same_session else ("initial" if resume==null else "new_session"),cursor)
func receive(id: int, packet: PackedByteArray) -> void:
	per_tick_packets[id]=int(per_tick_packets.get(id,0))+1
	if per_tick_packets[id]>4: return
	if packet.size()>MAX_PACKET_BYTES: reject(id,"packet_too_large"); return
	var message: Variant=JSON.parse_string(packet.get_string_from_utf8())
	if not message is Dictionary: reject(id,"invalid_message"); return
	if message.get("type")=="hello": _hello(id,message); return
	if not owners.has(id): reject(id,"handshake_required"); return
	var stream: Dictionary=event_peers[id]
	match message.get("type",""):
		"command":
			if _finish_requested or not final_snapshot.is_empty(): reject(id,"session_finished"); return
			if not world.journal_error.is_empty(): reject(id,"journal_unavailable"); return
			if _awaiting_baseline(stream): reject(id,"baseline_required"); return
			var envelope: Variant=message.get("envelope")
			if message.size()!=2 or not envelope is Dictionary or envelope.get("entity_id")!=owners[id].vehicle.entity_id: reject(id,"not_owner"); return
			var result: Dictionary=owners[id].receive(envelope)
			if result.ok: accepted+=1
			else: reject(id,result.reason)
		"baseline_ack":
			if message.size()!=4 or message.get("session_id")!=world.journal.session_id or not NetworkEventJournal.integer(message.get("cursor")) or not NetworkEventJournal.integer(message.get("snapshot_sequence")): reject(id,"invalid_baseline_ack"); return
			if stream.baseline.is_empty(): return
			if message.cursor!=stream.baseline.checkpoint.cursor or message.snapshot_sequence!=stream.baseline.snapshot.sequence: reject(id,"invalid_baseline_ack"); return
			stream.ack=int(message.cursor); stream.baseline.clear(); _send_events(id)
		"events_ack":
			if message.size()!=2 or _awaiting_baseline(stream): reject(id,"invalid_event_ack"); return
			var result := NetworkEventJournal.acknowledge(message.get("ack"),world.journal.session_id,stream.ack,stream.sent)
			if not result.ok: reject(id,result.reason); return
			var advanced: bool=result.cursor>stream.ack
			stream.ack=result.cursor
			if advanced: _send_events(id)
		"events_request":
			if message.size()!=3 or message.get("session_id")!=world.journal.session_id or not NetworkEventJournal.integer(message.get("after")) or message.after>stream.sent: reject(id,"invalid_event_request"); return
			if not stream.baseline.is_empty(): send_to(id,stream.baseline)
			else: _send_events(id,int(message.after))
		"final_ack":
			if message.size()!=4 or final_snapshot.is_empty() or _awaiting_baseline(stream) or message.get("session_id")!=world.journal.session_id or not NetworkEventJournal.integer(message.get("cursor")) or message.cursor!=final_snapshot.event_sequence or message.cursor!=stream.ack or message.get("digest")!=final_payload.sha256_text(): reject(id,"invalid_final_ack"); return
			final_acks[id]=true
		_: reject(id,"unsupported_message")
func _send_final(id: int) -> void:
	send_to(id,{"type":"final","payload":final_payload,"own_status":_final_status[owners[id].vehicle.entity_id]})
func finish() -> void:
	if _finish_requested or not final_snapshot.is_empty(): return
	_finish_requested=true
	for id in owners:
		owners[id].reset_pending(); owners[id].vehicle.clear_commands()
func _freeze_finish() -> void:
	# Run after vehicles/projectiles/match, never label a pre-step pose with the
	# receive callback's next physics tick. Retries retain this completed state.
	world.flush_launches()
	for actor in world.actors: actor.set_physics_process(false)
	world.projectiles.close_round()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	snapshot_sequence+=1; final_snapshot=world.snapshot(snapshot_sequence)
	final_payload=JSON.stringify(final_snapshot,"",true,true)
	for actor in world.actors: _final_status[actor.entity_id]=world.own_status(actor).duplicate(true)
func _physics_process(_delta: float) -> void:
	if world==null: return
	per_tick_packets.clear(); peer.poll()
	var count := 0
	while peer.get_available_packet_count()>0 and count<32:
		var id := peer.get_packet_peer()
		receive(id,peer.get_packet()); count+=1
func _publish() -> void:
	if world==null: return
	var tick := Engine.get_physics_frames()
	if final_snapshot.is_empty(): last_completed_tick=tick
	var just_finished := _finish_requested and final_snapshot.is_empty()
	if just_finished: _freeze_finish()
	var snapshot: Dictionary={}
	for id in owners:
		var stream: Dictionary=event_peers[id]
		if not stream.baseline_request.is_empty():
			if snapshot.is_empty(): snapshot=_snapshot()
			_send_baseline(id,snapshot); stream.needs_snapshot=false
			continue
		if not stream.baseline.is_empty():
			if tick-stream.baseline_tick>=15:
				stream.baseline_tick=tick; send_to(id,stream.baseline)
			continue
		if tick%3!=0 and not stream.needs_snapshot and not just_finished: continue
		_send_events(id)
		if _awaiting_baseline(stream): continue
		if final_snapshot.is_empty():
			if snapshot.is_empty(): snapshot=_snapshot()
			send_to(id,{"type":"snapshot","snapshot":snapshot,"own_status":world.own_status(owners[id].vehicle)})
			stream.needs_snapshot=false
		elif not final_acks.has(id) and (just_finished or tick%30==0): _send_final(id)
func _exit_tree() -> void: peer.close()
