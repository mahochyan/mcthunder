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
func _physics_process(_delta: float) -> void:
	if status=="disconnected": return
	if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED or (status=="connecting" and Time.get_ticks_msec()-connected_at>5000):
		close(); disconnected.emit(); return
	peer.poll()
	if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	if not hello_sent: send({"type":"hello","version":1}); hello_sent=true
	while peer.get_available_packet_count()>0:
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet()
		if sender!=1 or packet.size()>65536: continue
		var message: Variant=JSON.parse_string(packet.get_string_from_utf8())
		if not message is Dictionary: continue
		if message.get("type")=="welcome" and message.get("version")==1:
			entity_id=str(message.get("entity_id","")); status="connected"
		var snapshot: Variant=null
		if message.get("type")=="snapshot":
			snapshot=message.get("snapshot")
			if message.get("own_status") is Dictionary: own_status=message.own_status
		if message.get("type")=="final" and message.get("payload") is String:
			snapshot=JSON.parse_string(message.payload)
			send({"type":"final_ack","digest":message.payload.sha256_text()}); status="finished"
		if snapshot is Dictionary and snapshot.get("version")==1 and snapshot.get("vehicles") is Array and int(snapshot.get("sequence",-1))>int(latest.get("sequence",-1)):
			latest=snapshot
			snapshot_received.emit(latest.duplicate(true))
func submit(command: VehicleCommand) -> bool:
	if status!="connected" or latest.is_empty() or int(latest.tick)==last_sent_tick: return false
	for row in latest.vehicles:
		if row.entity_id!=entity_id: continue
		var body := {"throttle":command.throttle,"steer":command.steer,"select_shell":command.select_shell,"aim_world_point":[command.aim_world_point.x,command.aim_world_point.y,command.aim_world_point.z]}
		for flag in VehicleCommandCodec.FLAGS: body[flag]=command.get(flag)
		var envelope := {"version":1,"entity_id":entity_id,"life_id":row.life_id,"generation":row.generation,"control_epoch":row.control_epoch,"sequence":sequence,"input_tick":latest.tick,"command":body}
		send({"type":"command","envelope":envelope}); sequence+=1; last_sent_tick=int(latest.tick)
		return true
	return false
func _exit_tree() -> void: peer.close()
