extends SceneTree
func _initialize() -> void: call_deferred("run")
func save_report(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"  ")); file.close()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=3: print("[FAIL] role port output required"); quit(1); return
	if args[0]=="server": await run_server(int(args[1]),args[2])
	else: await run_client(int(args[1]),args[2])
func run_server(port: int, path: String) -> void:
	var server := NetworkBattleServer.new(); root.add_child(server)
	if server.start(port)!=OK: print("[FAIL] server start"); quit(1); return
	save_report(path+".ready",{"port":port})
	var deadline := Time.get_ticks_msec()+25000
	var started := -1
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if server.owners.size()==2 and started<0: started=Time.get_ticks_msec()
		if started>=0 and Time.get_ticks_msec()-started>=8000: server.finish()
		if server.final_acks.size()==2: break
	var final := server.final_snapshot
	var shots := 0
	var moved := true
	for row in final.get("vehicles",[]):
		shots+=int(row.shots)
		moved=moved and absf(float(row.position[2])-12)>0.25 and row.shots>0 and row.shots<=5
	var impacts := 0
	for event in final.get("events",[]):
		if event.reason=="impact_world": impacts+=1
	var passed: bool = server.final_acks.size()==2 and moved and shots>0 and impacts>0 and final.get("events",[]).size()==shots and server.rejected.get("not_owner",0)>=2 and server.rejected.get("stale_sequence",0)>=2 and server.rejected.get("unsupported_message",0)>=2 and server.rejected.get("unsupported_version",0)>=2
	save_report(path,{"passed":passed,"accepted":server.accepted,"rejected":server.rejected,"acks":server.final_acks.size(),"final":final,"digest":server.final_payload.sha256_text(),"shots":shots,"world_impacts":impacts})
	print("NETWORK_SLICE_SERVER_PASS" if passed else "NETWORK_SLICE_SERVER_FAIL")
	server.free(); quit(0 if passed else 1)
func run_client(port: int, path: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1",port,2)!=OK: print("[FAIL] client start"); quit(1); return
	var deadline := Time.get_ticks_msec()+23000
	var hello := false
	var entity := ""
	var latest: Dictionary={}
	var sequence := 0
	var last_sent := -1
	var started := -1
	var malicious_sent := false
	var seen_events: Dictionary={}
	var ordered := true
	var last_snapshot_sequence := -1
	var final: Dictionary={}
	var final_payload := ""
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED: break
		peer.poll()
		if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: continue
		peer.set_target_peer(1); peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
		if not hello:
			peer.put_packet(JSON.stringify({"type":"hello","version":true}).to_utf8_buffer())
			peer.put_packet(JSON.stringify({"type":"hello","version":1}).to_utf8_buffer())
			peer.put_packet(JSON.stringify({"type":"hello","version":VehicleFramePose.NETWORK_VERSION}).to_utf8_buffer()); hello=true
		while peer.get_available_packet_count()>0:
			var sender := peer.get_packet_peer()
			var message: Variant=JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if sender!=1 or not message is Dictionary: continue
			if message.get("type")=="welcome": entity=message.entity_id
			if message.get("type")=="final":
				final_payload=message.payload
				final=JSON.parse_string(final_payload)
				message.snapshot=final
			if message.get("type") in ["snapshot","final"]:
				latest=message.snapshot
				ordered=ordered and int(latest.sequence)>last_snapshot_sequence
				last_snapshot_sequence=int(latest.sequence)
				for event in latest.events:
					var key := str(event.sequence)
					if seen_events.has(key): ordered=ordered and seen_events[key]==event
					seen_events[key]=event
		if not final.is_empty(): break
		if entity.is_empty() or latest.is_empty() or latest.tick==last_sent: continue
		if started<0: started=Time.get_ticks_msec()
		last_sent=int(latest.tick)
		for row in latest.vehicles:
			if row.entity_id!=entity: continue
			var command := VehicleCommand.new()
			command.throttle=0.5 if Time.get_ticks_msec()-started<1000 else 0.0
			command.has_aim_point=true; command.aim_world_point=Vector3(row.position[0],5,-70)
			command.fire_requested=true
			var body := {"throttle":command.throttle,"steer":command.steer,"select_shell":-1,"aim_world_point":[command.aim_world_point.x,command.aim_world_point.y,command.aim_world_point.z]}
			for flag in VehicleCommandCodec.FLAGS: body[flag]=command.get(flag)
			var envelope := {"version":VehicleCommandCodec.VERSION,"entity_id":entity,"life_id":row.life_id,"generation":row.generation,"control_epoch":row.control_epoch,"sequence":sequence,"input_tick":latest.tick,"command":body}
			if not malicious_sent:
				var spoof: Dictionary=envelope.duplicate(true); spoof.entity_id="B" if entity=="A" else "A"
				peer.put_packet(JSON.stringify({"type":"command","envelope":spoof}).to_utf8_buffer())
				peer.put_packet(JSON.stringify({"type":"claim_hit","target":"enemy","ammo":9999}).to_utf8_buffer())
			peer.put_packet(JSON.stringify({"type":"command","envelope":envelope}).to_utf8_buffer())
			if not malicious_sent:
				peer.put_packet(JSON.stringify({"type":"command","envelope":envelope}).to_utf8_buffer()); malicious_sent=true
			sequence+=1
	var digest := final_payload.sha256_text()
	if not final.is_empty():
		peer.put_packet(JSON.stringify({"type":"final_ack","digest":digest}).to_utf8_buffer())
		var flush_until := Time.get_ticks_msec()+400
		while Time.get_ticks_msec()<flush_until and peer.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED:
			peer.poll(); await process_frame
	var passed := ordered and not final.is_empty() and seen_events.size()==int(final.get("event_sequence",0)) and not seen_events.is_empty()
	save_report(path,{"passed":passed,"entity":entity,"commands":sequence,"event_count":seen_events.size(),"snapshot_and_event_order_verified":ordered,"digest":digest,"final":final})
	peer.close()
	print("NETWORK_SLICE_CLIENT_PASS" if passed else "NETWORK_SLICE_CLIENT_FAIL")
	quit(0 if passed else 1)
