class_name NetworkBattleClient
extends Node
signal snapshot_received(snapshot: Dictionary)
signal disconnected
var peer := ENetMultiplayerPeer.new()
var entity_id := ""
var latest: Dictionary = {}
var own_status: Dictionary = {}
var status := "disconnected"
var sequence := 0
var last_sent_tick := -1
var connected_at := 0
var hello_sent := false
func connect_local(port: int) -> Error:
	close()
	var error := peer.create_client("127.0.0.1",port,2)
	if error==OK: status="connecting"; connected_at=Time.get_ticks_msec()
	return error
func close() -> void:
	peer.close(); entity_id=""; latest.clear(); own_status.clear(); sequence=0; last_sent_tick=-1; hello_sent=false
	status="disconnected"
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
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED or (status=="connecting" and Time.get_ticks_msec()-connected_at>5000):
		close(); disconnected.emit(); return
	peer.poll()
	if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	if not hello_sent: send({"type":"hello","version":VehicleFramePose.NETWORK_VERSION}); hello_sent=true
	while peer.get_available_packet_count()>0:
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet()
		if sender!=1 or packet.size()>65536: continue
		var message: Variant=JSON.parse_string(packet.get_string_from_utf8())
		if not message is Dictionary: continue
		accept_message(message)
func accept_message(message: Dictionary) -> bool:
	# Shared by real packet reception and malformed-packet regression fixtures.
	if message.get("type")=="welcome":
		if not VehicleCommandCodec.integer(message.get("version")) or message.version!=VehicleFramePose.NETWORK_VERSION: return false
		if not message.get("entity_id") is String or message.entity_id.is_empty() or message.entity_id.length()>128: return false
		entity_id=message.entity_id; status="connected"
		return true
	var snapshot: Variant=null
	if message.get("type")=="snapshot": snapshot=message.get("snapshot")
	if message.get("type")=="final" and message.get("payload") is String:
		snapshot=JSON.parse_string(message.payload)
	if not NetworkPoseBuffer.valid_snapshot(snapshot): return false
	if int(snapshot.sequence)<int(latest.get("sequence",-1)) or int(snapshot.tick)<int(latest.get("tick",-1)): return false
	var owner: Dictionary={}
	for row in snapshot.vehicles:
		if row.entity_id==entity_id: owner=row; break
	if owner.is_empty() or not valid_own_status(message.get("own_status"),owner): return false
	# Public pose and private fire control advance atomically. A bad measurement
	# must not enter the HUD or leave it paired with a newer vehicle generation.
	if message.get("type")=="final":
		send({"type":"final_ack","digest":message.payload.sha256_text()}); status="finished"
	if int(snapshot.sequence)>int(latest.get("sequence",-1)):
		own_status=message.own_status.duplicate(true)
		latest=snapshot.duplicate(true)
		snapshot_received.emit(latest.duplicate(true))
	return true
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
