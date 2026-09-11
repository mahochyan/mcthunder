extends SceneTree
class EventSnapshotProbe extends Node:
	var battle: TeamRange
	var expected_sequence := 0
	var captured: Dictionary = {}
	func _ready() -> void: process_physics_priority=SimulationPhases.SNAPSHOT+1
	func _physics_process(_delta: float) -> void:
		if not captured.is_empty(): return
		var snapshot := battle.simulation_snapshot.read()
		if snapshot.get("event_sequence",-1)==expected_sequence: captured=snapshot
var count := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func frames(n: int = 3) -> void:
	for i in n: await physics_frame
	await process_frame
func run() -> void:
	var scene := TeamRange.new()
	root.add_child(scene); current_scene = scene
	await frames(190)
	for actor in scene.combat_actors(): actor.set_controller(null)
	var state := scene.director.state
	var ordered := state.events.size()==9
	for i in state.events.size():
		var event := state.events[i]
		ordered = ordered and event.schema_version==1 and event.match_id==state.match_id and event.sequence==i+1 and event.physics_tick<=Engine.get_physics_frames()
	check(ordered and state.events.back().kind=="match_started","eight actual spawns and countdown commit versioned ordered match events")
	check(scene.simulation_snapshot.read().event_sequence==state.event_sequence,"post-director snapshot identifies last committed event")
	var probe := EventSnapshotProbe.new()
	probe.battle=scene; probe.expected_sequence=state.event_sequence+1
	scene.add_child(probe)
	var victim := state.actor_for("B")
	if victim.state.destroy_once("event_fixture",{"round_id":state.match_id}):
		victim._commit_death(); victim._publish_death()
	await frames(1)
	var death: Dictionary = state.events.back().duplicate(true)
	print("[death snapshot] event=",death," first_snapshot_tick=",probe.captured.get("physics_tick",-1))
	check(death.kind=="death" and death.entity_id=="B" and death.life_id==victim.life_id and death.physics_tick==probe.captured.get("physics_tick",-1),"real destruction reaches ledger and same-step event snapshot")
	var after_death := state.event_sequence
	scene.director.on_vehicle_destroyed(victim.state.death_record)
	await frames(1)
	check(state.event_sequence==after_death and state.tickets[2]==TeamMatchState.START_TICKETS-TeamMatchState.DEATH_COST,"duplicate destruction produces neither another event nor another ticket debit")
	state.elapsed=TeamMatchState.TIME_LIMIT-0.001 # Explicit end boundary, not a full natural match.
	await frames(1)
	var result := state.result.duplicate(true)
	check(result.events.back().kind=="match_finished" and result.events.back().sequence==result.event_sequence and result.events.back().tickets==result.tickets,"terminal event is included in actual settlement with final ticket totals")
	check(scene.simulation_snapshot.read().event_sequence==result.event_sequence,"final snapshot and result share the same event boundary")
	var final_sequence := state.event_sequence
	check(not scene.director.finish_once("defeat","duplicate") and state.event_sequence==final_sequence,"repeated finish cannot append or change terminal event")
	result.events.back().tickets[1]=-99
	check(state.events.back().tickets[1]>=0 and state.result.events.back().tickets[1]>=0,"settlement consumer copies cannot alter committed events")
	var old_match := state.match_id
	scene.director.begin()
	check(scene.director.state.match_id!=old_match and scene.director.state.event_sequence==0 and scene.director.state.events.is_empty(),"new match has a distinct identity and fresh sequence")
	scene.free(); await process_frame
	# Bounded history fixture exercises production commit function independently of combat.
	var history := TeamMatchState.new(); history.initialize()
	var payload := {"match_id":-1,"sequence":-1,"schema_version":-1,"physics_tick":-1,"kind":"spoof","time":-1,"nested":{"value":1}}
	history.record("fixture",payload)
	payload.nested.value=2
	check(history.events[0].nested.value==1 and history.events[0].match_id==history.match_id and history.events[0].sequence==1 and history.events[0].schema_version==1 and history.events[0].physics_tick==Engine.get_physics_frames() and history.events[0].kind=="fixture" and history.events[0].time==history.elapsed,"caller payload is copied and cannot override authoritative event identity")
	for i in 140: history.record("fixture",{})
	check(history.events.size()==128 and history.events.front().sequence==14 and history.events.back().sequence==141 and history.event_sequence==141,"bounded history eviction never reuses a sequence number")
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("MATCH_EVENT_CHECKS_PASS" if failed==0 else "MATCH_EVENT_CHECKS_FAIL")
	quit(0 if failed==0 else 1)
