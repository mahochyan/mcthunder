class_name NetworkBattleServer
extends Node
## Explicit loopback-only technical session, not an internet lobby or account server.
const VERSION := VehicleFramePose.NETWORK_VERSION
const MAX_PACKET_BYTES := 4096
var peer := ENetMultiplayerPeer.new()
var world: NetworkBattleWorld
var owners: Dictionary = {}
var accepted := 0
var rejected: Dictionary = {}
var snapshot_sequence := 0
var final_snapshot: Dictionary = {}
var final_payload := ""
var final_acks: Dictionary = {}
var per_tick_packets: Dictionary = {}
func start(port: int) -> Error:
	process_physics_priority=-100
	peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(port,2,2)
	if error!=OK: return error
	peer.peer_disconnected.connect(disconnect_owner)
	world=NetworkBattleWorld.new(); add_child(world)
	return OK if world.ready_ok else ERR_CANT_CREATE
func send_to(id: int, message: Dictionary) -> void:
	peer.set_target_peer(id)
	peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
func reject(id: int, reason: String) -> void:
	rejected[reason]=int(rejected.get(reason,0))+1
	send_to(id,{"type":"rejected","reason":reason})
func disconnect_owner(id: int) -> void:
	if not owners.has(id): return
	var controller: NetworkController=owners[id]
	controller.vehicle.clear_commands()
	controller.vehicle.set_controller(null)
	controller.queue_free(); owners.erase(id)
func receive(id: int, packet: PackedByteArray) -> void:
	per_tick_packets[id]=int(per_tick_packets.get(id,0))+1
	if per_tick_packets[id]>4: return # Bounded work and replies per peer per server tick.
	if packet.size()>MAX_PACKET_BYTES: reject(id,"packet_too_large"); return
	var message: Variant=JSON.parse_string(packet.get_string_from_utf8())
	if not message is Dictionary: reject(id,"invalid_message"); return
	match message.get("type",""):
		"hello":
			if not VehicleCommandCodec.integer(message.get("version")) or int(message.version)!=VERSION: reject(id,"unsupported_version"); return
			if not owners.has(id):
				var claimed: Array=[]
				for controller in owners.values(): claimed.append(controller.vehicle)
				for actor in world.actors:
					if actor in claimed: continue
					var controller := NetworkController.new(); controller.vehicle=actor; add_child(controller)
					actor.set_controller(controller); owners[id]=controller; break
			if owners.has(id): send_to(id,{"type":"welcome","version":VERSION,"entity_id":owners[id].vehicle.entity_id})
		"command":
			if not final_snapshot.is_empty(): reject(id,"session_finished"); return
			if not owners.has(id): reject(id,"handshake_required"); return
			var envelope: Variant=message.get("envelope")
			if not envelope is Dictionary or envelope.get("entity_id")!=owners[id].vehicle.entity_id: reject(id,"not_owner"); return
			var result: Dictionary=owners[id].receive(envelope)
			if result.ok: accepted+=1
			else: reject(id,result.reason)
		"final_ack":
			if owners.has(id) and not final_snapshot.is_empty() and message.get("digest")==final_payload.sha256_text(): final_acks[id]=true
		_: reject(id,"unsupported_message")
func finish() -> void:
	if not final_snapshot.is_empty(): return
	for id in owners:
		owners[id].reset_pending(); owners[id].vehicle.clear_commands()
	for actor in world.actors: actor.set_physics_process(false)
	world.projectiles.close_round()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	snapshot_sequence+=1
	final_snapshot=world.snapshot(snapshot_sequence)
	# Acknowledge the exact wire representation, not reserialized JSON variants:
	# JSON decoding changes int/float types and may round floating point text.
	final_payload=JSON.stringify(final_snapshot,"",true,true)
	for id in owners:
		send_to(id,{"type":"final","payload":final_payload,"own_status":world.own_status(owners[id].vehicle)})
func _physics_process(_delta: float) -> void:
	if world==null: return
	per_tick_packets.clear()
	peer.poll()
	var count := 0
	while peer.get_available_packet_count()>0 and count<32:
		var id := peer.get_packet_peer()
		receive(id,peer.get_packet()); count+=1
	if final_snapshot.is_empty() and Engine.get_physics_frames()%3==0:
		snapshot_sequence+=1
		var snapshot := world.snapshot(snapshot_sequence)
		for id in owners:
			var actor: VehicleActor=owners[id].vehicle
			send_to(id,{"type":"snapshot","snapshot":snapshot,"own_status":world.own_status(actor)})
func _exit_tree() -> void: peer.close()
