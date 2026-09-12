extends SceneTree
## Three actual processes: authority plus two production clients. A late client
## starts at an explicit current baseline; only its subsequent tail is replayed.
var seen_events: Dictionary={}
var ordered := true
var initial_cursor := 0
var last_snapshot_sequence := -1
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
	var impacts := 0; var fired := 0; var finished := 0; var cursor := 0
	var journal_events: Array=[]
	var terminal_reasons := {}
	while cursor<server.world.journal.head():
		var result := server.world.journal.read_after(cursor)
		if not result.ok: break
		for event in result.batch.events:
			journal_events.append(event.duplicate(true))
			if event.kind=="projectile_fired": fired+=1
			else:
				finished+=1
				terminal_reasons[event.payload.reason]=int(terminal_reasons.get(event.payload.reason,0))+1
				if event.payload.reason=="impact_world": impacts+=1
			cursor=int(event.sequence)
	var passed: bool = server.final_acks.size()==2 and moved and shots>0 and impacts>0 and fired==shots and finished==shots and cursor==int(final.get("event_sequence",-1)) and server.world.journal_error.is_empty() and server.rejected.get("not_owner",0)>=2 and server.rejected.get("stale_sequence",0)>=2 and server.rejected.get("unsupported_message",0)>=2 and server.rejected.get("unsupported_version",0)>=2
	save_report(path,{"passed":passed,"accepted":server.accepted,"rejected":server.rejected,"acks":server.final_acks.size(),"final":final,"digest":server.final_payload.sha256_text(),"shots":shots,"fired":fired,"finished":finished,"world_impacts":impacts,"terminal_reasons":terminal_reasons,"journal_events":journal_events})
	print("NETWORK_SLICE_SERVER_PASS" if passed else "NETWORK_SLICE_SERVER_FAIL")
	server.free(); quit(0 if passed else 1)
func on_events(events: Array) -> void:
	for event in events:
		var key := int(event.sequence)
		ordered=ordered and not seen_events.has(key) and key==initial_cursor+seen_events.size()+1
		seen_events[key]=event.duplicate(true)
func on_snapshot(snapshot: Dictionary) -> void:
	ordered=ordered and int(snapshot.sequence)>last_snapshot_sequence
	last_snapshot_sequence=int(snapshot.sequence)
func run_client(port: int, path: String) -> void:
	var client := NetworkBattleClient.new(); root.add_child(client)
	client.public_events_received.connect(on_events)
	client.snapshot_received.connect(on_snapshot)
	client.event_recovery_changed.connect(func(info: Dictionary) -> void:
		if info.reason=="initial": initial_cursor=int(info.cursor))
	if client.connect_local(port)!=OK: print("[FAIL] client start"); quit(1); return
	var deadline := Time.get_ticks_msec()+23000
	var started := -1
	var malicious_stage := 0
	var last_attempt_tick := -1
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if client.status=="disconnected" or client.status=="finished": break
		if client.status!="connected" or client.latest.is_empty(): continue
		if started<0: started=Time.get_ticks_msec()
		if int(client.latest.tick)==last_attempt_tick: continue
		last_attempt_tick=int(client.latest.tick)
		# Spread hostile probes over distinct receive steps so the packet budget
		# cannot hide a validation branch behind an unrelated dropped packet.
		if malicious_stage==0:
			client.send({"type":"hello","version":true,"resume":null}); malicious_stage+=1; continue
		if malicious_stage==1:
			client.send({"type":"hello","version":1,"resume":null}); malicious_stage+=1; continue
		var command := VehicleCommand.new()
		command.throttle=0.5 if Time.get_ticks_msec()-started<1500 else 0.0
		# Horizontal optical intention lets actual gravity end flight on the
		# ground inside this eight-second fixture, before terminal cancellation.
		command.clear_aim=true; command.aim_intent.active=true; command.aim_intent.pitch=0.0
		command.fire_requested=Time.get_ticks_msec()-started>=750
		for row in client.latest.vehicles:
			if row.entity_id!=client.entity_id: continue
			var envelope := {"version":VehicleCommandCodec.VERSION,"entity_id":client.entity_id,"life_id":row.life_id,"generation":row.generation,"control_epoch":row.control_epoch,"sequence":client.sequence,"input_tick":client.latest.tick,"command":VehicleCommandCodec.encode_body(command)}
			if malicious_stage==2:
				var spoof: Dictionary=envelope.duplicate(true); spoof.entity_id="B" if client.entity_id=="A" else "A"
				client.send({"type":"command","envelope":spoof}); malicious_stage+=1
			elif malicious_stage==3:
				client.send({"type":"claim_hit","target":"enemy","ammo":9999}); malicious_stage+=1
			elif client.submit(command) and malicious_stage==4:
				client.send({"type":"command","envelope":envelope}); malicious_stage+=1
	var final := client.latest.duplicate(true) if not client.final_payload.is_empty() else {}
	var digest := client.final_payload.sha256_text()
	var completed_entity := client.entity_id
	var completed_commands := client.sequence
	var passed := ordered and client.status=="finished" and not final.is_empty() and client.event_cursor==int(final.get("event_sequence",-1)) and seen_events.size()==client.event_cursor-initial_cursor and not seen_events.is_empty() and client.active_projectiles.is_empty()
	# Let the production final ACK drain before closing the transport.
	var flush_until := Time.get_ticks_msec()+400
	while Time.get_ticks_msec()<flush_until and client.peer.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED: await process_frame
	save_report(path,{"passed":passed,"entity":completed_entity,"commands":completed_commands,"event_count":seen_events.size(),"initial_cursor":initial_cursor,"event_cursor":client.event_cursor,"snapshot_and_event_order_verified":ordered,"digest":digest,"final":final})
	client.free()
	print("NETWORK_SLICE_CLIENT_PASS" if passed else "NETWORK_SLICE_CLIENT_FAIL")
	quit(0 if passed else 1)
