extends SceneTree
## Real ENet and actual ProjectileManager admission/flight/termination. Only the
## transport fixture drops delivery/ACKs; no production loss or authority hooks.
const PORT := 19118
var checks := 0
var failures := 0
var fixture_shot := 0

class RecordingServer extends NetworkBattleServer:
	var phase_tick := -1
	var phase_vehicles: Array=[]
	var phase_head := 0
	var publication_ok := true
	var published: Dictionary={}
	class PhaseProbe extends Node:
		var server: RecordingServer
		func _physics_process(_delta: float) -> void:
			server.phase_tick=Engine.get_physics_frames()
			server.phase_vehicles=server.world.snapshot(0).vehicles
			server.phase_head=server.world.journal.head()
	func install_probe() -> void:
		var probe := PhaseProbe.new(); probe.server=self
		probe.process_physics_priority=SimulationPhases.SNAPSHOT-1; add_child(probe)
	func send_to(id: int, message: Dictionary) -> void:
		if message.get("type") in ["snapshot","baseline"]:
			var snapshot: Dictionary=message.snapshot
			if not published.has(int(snapshot.sequence)):
				published[int(snapshot.sequence)]=snapshot.duplicate(true)
				publication_ok=publication_ok and phase_tick==Engine.get_physics_frames() and int(snapshot.tick)==phase_tick and snapshot.vehicles==phase_vehicles and int(snapshot.event_sequence)==phase_head
		super.send_to(id,message)

class LossClient extends NetworkBattleClient:
	var drop_events := false
	var drop_final_ack := false
	var drop_event_ack := false
	var effects: Array=[]
	var recovery: Array=[]
	var received: Array=[]
	var final_signals := 0
	var withheld_final_acks := 0
	var recovery_atomic := true
	var snapshot_signals := 0
	func _ready() -> void:
		super._ready()
		public_events_received.connect(func(events: Array) -> void: effects.append_array(events.duplicate(true)))
		event_recovery_changed.connect(observe_recovery)
		snapshot_received.connect(func(_snapshot: Dictionary) -> void: snapshot_signals+=1)
		session_finished.connect(func() -> void: final_signals+=1)
	func observe_recovery(info: Dictionary) -> void:
		recovery.append(info.duplicate(true))
		if info.reason not in ["initial","new_session","history_evicted"]: return
		var owner: Dictionary={}
		for row in latest.get("vehicles",[]):
			if row.entity_id==entity_id: owner=row
		recovery_atomic=recovery_atomic and latest.get("session_id")==session_id and latest.get("event_sequence")==info.cursor and event_cursor==info.cursor and active_projectiles.size()==info.active and not owner.is_empty() and valid_own_status(own_status,owner)
	func accept_message(message: Dictionary) -> bool:
		received.append(message.duplicate(true))
		if message.get("type")=="events" and drop_events: return false
		return super.accept_message(message)
	func inject(message: Dictionary) -> bool:
		return super.accept_message(message)
	func send(message: Dictionary) -> void:
		if message.get("type")=="events_ack" and drop_event_ack: return
		if message.get("type")=="final_ack" and drop_final_ack:
			withheld_final_acks+=1; return
		super.send(message)
	func transmit(message: Dictionary) -> void: super.send(message)
	func last_packet(kind: String) -> Dictionary:
		for i in range(received.size()-1,-1,-1):
			if received[i].get("type")==kind: return received[i].duplicate(true)
		return {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame
func until(predicate: Callable, maximum: int=180) -> bool:
	for i in maximum:
		if predicate.call(): await process_frame; return true
		await physics_frame
	await process_frame
	return bool(predicate.call())
func own_row(client: NetworkBattleClient) -> Dictionary:
	for row in client.latest.get("vehicles",[]):
		if row.entity_id==client.entity_id: return row
	return {}
func spawn_fixture(world: NetworkBattleWorld, terminate: bool=false) -> int:
	# Slow, zero-gravity TEST_ONLY projectile at 50m above the empty field. It
	# lives long enough to join while flying; the overflow case cancels it once.
	fixture_shot+=1
	var result := world.projectiles.try_spawn({"round_id":1,"shooter_id":"TEST_EVENT","shooter_life_id":1,"shooter_team_id":0,"shot_id":fixture_shot,
		"shell_id":"TEST_EVENT_AP","position_world":Vector3(0,50,-100),"velocity_world":Vector3(20,0,0),"gravity_world":Vector3.ZERO,
		"max_age_s":60.0,"max_distance_m":5000.0,"armor_policy":"legacy_contact_only","test_only":true})
	if not result.ok: return 0
	# This fixture admits outside the normal vehicle phase. Flush the committed
	# launch before intentional same-tick cancellation; production vehicles use99.
	world.flush_launches()
	if terminate: world.projectiles.finish_once(int(result.projectile_id),"cancelled_fixture",{})
	return int(result.projectile_id)
func checkpoint(client: NetworkBattleClient) -> Dictionary:
	return {"cursor":client.event_cursor,"active":client.active_projectiles.duplicate(true),"latest":client.latest.duplicate(true),"status":client.own_status.duplicate(true),"recent":client.recent_events.duplicate(true)}
func run() -> void:
	var space := SubViewport.new(); space.own_world_3d=true; root.add_child(space)
	var server := RecordingServer.new(); space.add_child(server)
	check(server.start(PORT)==OK and server.world.ready_ok,"authority and actual local ENet session start")
	if not server.world.ready_ok: space.free(); quit(1); return
	server.install_probe()
	var a := LossClient.new(); root.add_child(a); a.connect_local(PORT)
	check(await until(func() -> bool: return a.status=="connected"),"initial client atomically accepts versioned baseline")
	if a.latest.is_empty(): a.free(); space.free(); quit(1); return
	await ticks(6) # Let baseline ACK clear before the first command.
	check(a.event_cursor==0 and a.active_projectiles.is_empty() and a.recovery[-1].reason=="initial","initial baseline invents neither past effects nor flying projectiles")
	check(a.recovery_atomic,"initial recovery callback already sees matching pose, private owner status and event cursor")
	# Use the actual received packet to isolate callback reentrancy. This extra
	# observer opens no socket and does not claim a third authority seat.
	var callback_client := LossClient.new(); root.add_child(callback_client); callback_client.set_physics_process(false)
	callback_client.inject({"type":"welcome","version":VehicleFramePose.NETWORK_VERSION,"session_id":a.session_id,"entity_id":a.entity_id,"recovery":"baseline"})
	callback_client.event_recovery_changed.connect(func(_info: Dictionary) -> void: callback_client.close())
	var accepted_baseline := callback_client.inject(a.last_packet("baseline"))
	check(accepted_baseline and callback_client.recovery_atomic and callback_client.status=="disconnected" and callback_client.latest.is_empty() and callback_client.snapshot_signals==0,"closing from recovery callback cannot dispatch stale pose after disconnect")
	callback_client.free()
	var command := VehicleCommand.new()
	command.clear_aim=true; command.aim_intent.active=true; command.aim_intent.pitch=0.0
	command.throttle=0.6; command.fire_requested=true
	check(a.submit(command),"real player command crosses production encoder and transport")
	check(await until(func() -> bool: return server.world.journal.head()>=2),"real Gunner launch and natural projectile finish enter the journal")
	command=VehicleCommand.new()
	await until(func() -> bool: return a.submit(command))
	await until(func() -> bool: return a.event_cursor==server.world.journal.head())
	check(a.effects.size()==2 and a.effects[0].kind=="projectile_fired" and a.effects[1].kind=="projectile_finished" and a.effects[0].shot==a.effects[1].shot,"one authoritative shot produces one ordered immutable fire/finish pair")
	var fire_tick := int(a.effects[0].tick) if not a.effects.is_empty() else -1
	var shot_published := false
	for frame in server.published.values():
		if frame.tick>=fire_tick and frame.event_sequence>=1:
			for row in frame.vehicles:
				if row.entity_id==a.entity_id and row.shots==1 and absf(row.position[2]-12)>0.01: shot_published=true
	check(server.publication_ok and shot_published and server.published.size()>1,"baseline and ordinary publication run after phase399 with same-step pose, shots and event head")
	check(not a.latest.has("events") and not a.latest.vehicles[0].has("fire_control"),"public timeline and poses do not embed private fire-control facts")
	var flying := spawn_fixture(server.world)
	check(flying>0,"late-join projectile admitted by actual manager")
	await ticks(20)
	var b := LossClient.new(); root.add_child(b); b.connect_local(PORT)
	check(await until(func() -> bool: return b.status=="connected"),"second real peer joins while projectile is in flight")
	var baseline := b.last_packet("baseline")
	var live_values: Array=baseline.get("checkpoint",{}).get("active_projectiles",[])
	var live: Dictionary=live_values[0] if not live_values.is_empty() else {}
	check(b.active_projectiles.has(flying) and float(live.get("age_s",0))>0 and float(live.get("position",[0,0,0])[0])>0,"late baseline carries current flying position and age rather than old launch origin")
	check(b.effects.is_empty() and b.event_cursor==int(baseline.get("checkpoint",{}).get("cursor",-1)),"late joining skips historical transient effects at its explicit cursor")
	server.world.projectiles.finish_once(flying,"cancelled_fixture",{})
	await until(func() -> bool: return a.event_cursor==server.world.journal.head() and b.event_cursor==server.world.journal.head())
	check(b.effects.size()==1 and b.effects[0].kind=="projectile_finished" and b.active_projectiles.is_empty(),"baseline identity permits exactly one subsequent finish without replaying its old fire")
	var duplicate := b.last_packet("events")
	var before := checkpoint(b); var effect_count := b.effects.size()
	check(b.inject(duplicate) and checkpoint(b)==before and b.effects.size()==effect_count,"duplicate reliable batch neither replays effects nor moves any cursor")
	var wrong := duplicate.duplicate(true); wrong.batch.session_id="ffffffffffffffffffffffffffffffff"
	check(not b.inject(wrong) and checkpoint(b)==before,"foreign session cannot contaminate state or acknowledgements")
	# Drop a complete delivery tail, then inject a later valid batch first.
	a.drop_events=true
	var missing_after := a.event_cursor
	check(spawn_fixture(server.world,true)>0 and spawn_fixture(server.world,true)>0,"two same-tick manager cancellation pairs create a real missing tail")
	await ticks(12)
	check(a.event_cursor==missing_after and a.event_head>missing_after,"snapshot head never advances an unapplied event cursor")
	var gap := server.world.journal.read_after(missing_after+2)
	before=checkpoint(a)
	check(not a.inject({"type":"events","batch":gap.batch}) and checkpoint(a)==before,"out-of-order batch cannot leap over a missing fire/finish pair")
	var continuous: Dictionary=server.world.journal.read_after(missing_after).batch
	var invalid := continuous.duplicate(true); invalid.events[-1].payload.position[0]=NAN
	check(not a.inject({"type":"events","batch":invalid}) and checkpoint(a)==before,"malformed suffix rejects the whole batch without partially spawning earlier fire")
	invalid=continuous.duplicate(true); invalid.events[-1].shot.shooter_life_id+=1
	check(not a.inject({"type":"events","batch":invalid}) and checkpoint(a)==before,"finish identity disagreement cannot consume its sequence")
	invalid=continuous.duplicate(true)
	for event in invalid.events: event.tick=0
	check(not a.inject({"type":"events","batch":invalid}) and checkpoint(a)==before,"event tick regression is rejected across batch boundaries")
	a.drop_events=false
	check(await until(func() -> bool: return a.event_cursor==server.world.journal.head()),"continuous replay resumes from acknowledged prefix after lost delivery")
	check(a.active_projectiles.is_empty(),"recovery applies both launches and finishes without orphan projectiles")
	await ticks(6)
	var peer_id := a.peer.get_unique_id()
	var ack_before := int(server.event_peers[peer_id].ack)
	a.send({"type":"events_ack","ack":{"session_id":a.session_id,"cursor":server.world.journal.head()+1}})
	await ticks(6)
	check(int(server.event_peers[peer_id].ack)==ack_before and server.rejected.get("unsent_ack",0)>0,"server refuses acknowledgement of an unsent future event")
	var old_epoch := int(own_row(a).control_epoch)
	var retained_cursor := a.event_cursor; var retained_session := a.event_session
	effect_count=a.effects.size()
	a.close()
	check(await until(func() -> bool: return server.owners.size()==1),"real disconnect releases vehicle controller")
	spawn_fixture(server.world,true)
	a.connect_local(PORT)
	check(await until(func() -> bool: return a.status=="connected" and a.event_cursor==server.world.journal.head()),"same-session reconnect recovers a retained event tail")
	check(a.event_session==retained_session and a.event_cursor==retained_cursor+2 and a.effects.size()==effect_count+2 and int(own_row(a).control_epoch)>old_epoch,"event checkpoint survives reconnect independently of new control epoch")
	await ticks(6)
	# B sees a real tail while its ACK is lost. The later server baseline starts
	# at the older ACK; these already-seen records must not be counted as skipped.
	var b_id := b.peer.get_unique_id()
	var b_server_cursor := int(server.event_peers[b_id].ack)
	var b_skipped_before := b.skipped_events
	b.drop_event_ack=true
	spawn_fixture(server.world,true); spawn_fixture(server.world,true)
	check(await until(func() -> bool: return a.event_cursor==server.world.journal.head() and b.event_cursor==server.world.journal.head()),"client applies real tail while outgoing event ACK is deliberately lost")
	var b_applied_cursor := b.event_cursor
	check(b_applied_cursor==b_server_cursor+4 and int(server.event_peers[b_id].ack)==b_server_cursor,"authority ACK remains behind four already-applied client records")
	# A connected observer also has to resync when all256 slots are replaced.
	retained_cursor=a.event_cursor
	a.close(); await until(func() -> bool: return server.owners.size()==1)
	var admitted := 0
	for i in 130:
		if spawn_fixture(server.world,true)>0: admitted+=1
	flying=spawn_fixture(server.world)
	await ticks(20)
	check(admitted==130 and server.world.journal.retained_count()==256 and server.world.journal.oldest()>retained_cursor+1 and server.world.journal_error.is_empty(),"real bounded journal evicts old history without breaking fire/finish admission")
	var b_baseline := b.last_packet("baseline")
	check(b_baseline.get("checkpoint",{}).get("after")==b_server_cursor and b.event_cursor==server.world.journal.head() and b.skipped_events==b_skipped_before+b.event_cursor-b_applied_cursor,"overlapping resync counts only locally unseen events, not the four records with lost ACK")
	b.drop_event_ack=false
	effect_count=a.effects.size()
	a.connect_local(PORT)
	check(await until(func() -> bool: return a.status=="connected" and a.event_cursor==server.world.journal.head()),"reconnect beyond retention window receives current baseline")
	baseline=a.last_packet("baseline")
	check(a.recovery[-1].reason=="history_evicted" and a.skipped_events==a.event_cursor-retained_cursor and a.effects.size()==effect_count and a.recent_events.is_empty(),"resync explicitly counts skipped history and emits no invented recovered effects")
	check(a.active_projectiles.has(flying) and float(a.active_projectiles[flying].position[0])>0 and a.active_projectiles.size()==1,"overflow resync restores only currently active flight")
	check(a.recovery_atomic and b.recovery_atomic,"both overflow recovery callbacks observe the complete new public and owner checkpoint")
	before=checkpoint(a)
	for fault in ["unknown_field","boolean_cursor","nonfinite_active","duplicate_active","private_status"]:
		invalid=baseline.duplicate(true)
		match fault:
			"unknown_field": invalid.checkpoint.client_damage=100
			"boolean_cursor": invalid.checkpoint.cursor=true
			"nonfinite_active": invalid.checkpoint.active_projectiles[0].age_s=NAN
			"duplicate_active": invalid.checkpoint.active_projectiles.append(invalid.checkpoint.active_projectiles[0].duplicate(true))
			"private_status": invalid.own_status.consumed_sequence=999999
		check(not a.inject(invalid) and checkpoint(a)==before,"invalid checkpoint cannot partially reset event or owner state: "+fault)
	var recovery_count := a.recovery.size()
	check(a.inject(baseline) and checkpoint(a)==before and a.recovery.size()==recovery_count,"repeated baseline ACK does not reset current presentation twice")
	await ticks(6)
	check(server.publication_ok,"resync baselines also capture completed phase400 public and private state")
	# The final public state may arrive while its cancellation event is withheld.
	a.drop_events=true; a.drop_final_ack=true
	peer_id=a.peer.get_unique_id()
	server.finish()
	check(await until(func() -> bool: return not a.final_payload.is_empty()),"final state is delivered with explicit terminal event head")
	check(a.status=="finishing" and a.event_cursor<int(server.final_snapshot.event_sequence) and a.active_projectiles.has(flying) and not server.final_acks.has(peer_id),"final digest alone cannot acknowledge an unapplied terminal event")
	a.transmit({"type":"final_ack","session_id":a.session_id,"cursor":server.final_snapshot.event_sequence,"digest":server.final_payload.sha256_text()})
	await ticks(6)
	check(not server.final_acks.has(peer_id) and server.rejected.get("invalid_final_ack",0)>0,"server rejects final ACK before that peer acknowledges the event prefix")
	a.drop_events=false
	check(await until(func() -> bool: return a.status=="finished"),"terminal gap is replayed before client declares session finished")
	check(a.active_projectiles.is_empty() and a.event_cursor==int(server.final_snapshot.event_sequence) and a.withheld_final_acks>0 and not server.final_acks.has(peer_id),"client final ACK contains fully applied cursor but dropped ACK remains unconfirmed on server")
	var frozen := server.final_payload; var frozen_tick := int(server.final_snapshot.tick)
	var frozen_positions: Array=[]
	for actor in server.world.actors: frozen_positions.append(actor.tank.global_position)
	await ticks(35)
	var still := true
	for i in server.world.actors.size(): still=still and server.world.actors[i].tank.global_position==frozen_positions[i]
	check(still and server.final_payload==frozen and server.last_completed_tick==frozen_tick and a.final_signals==1,"terminal retries retain completed tick and frozen movement without duplicate completion signal")
	a.drop_final_ack=false
	check(await until(func() -> bool: return server.final_acks.size()==2,100),"reliable final retry obtains both exact digest and final cursor acknowledgements")
	check(not a.submit(VehicleCommand.new()) and server.world.projectiles.active_count()==0,"finished client submits no input and authority retains no live flight")
	var final_digest := server.final_payload.sha256_text()
	a.close(); await until(func() -> bool: return server.owners.size()==1)
	old_epoch=server.world.actors[0].control_epoch
	var late := LossClient.new(); root.add_child(late); late.connect_local(PORT)
	check(await until(func() -> bool: return late.status=="finished"),"new transport after final receives explicit session-finished rejection")
	check(late.entity_id.is_empty() and server.world.actors[0].control_epoch==old_epoch and server.final_payload.sha256_text()==final_digest,"late final join cannot change ownership or immutable final snapshot")
	late.free(); b.free(); space.free(); await process_frame
	# Reuse the retaining client against a newly constructed authority session.
	var next_space := SubViewport.new(); next_space.own_world_3d=true; root.add_child(next_space)
	var next_server := RecordingServer.new(); next_space.add_child(next_server)
	check(next_server.start(PORT)==OK,"new authority session starts after old transport closes")
	next_server.install_probe()
	a.connect_local(PORT)
	check(await until(func() -> bool: return a.status=="connected"),"retaining client accepts an explicit new-session baseline")
	check(a.event_session!=retained_session and a.event_cursor==0 and a.active_projectiles.is_empty() and a.recent_events.is_empty() and a.recovery[-1].reason=="new_session","server restart resets old event identity and flight state without resuming old history")
	check(a.recovery_atomic,"new-session recovery callback cannot observe previous-session owner data")
	a.free(); next_space.free(); await process_frame
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_EVENT_RECOVERY_CHECKS_PASS" if failures==0 else "NETWORK_EVENT_RECOVERY_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
