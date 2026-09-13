extends SceneTree
# WT-025: the four clocks stay separate, compensation and replay windows stay bounded, one
# owner settles a projectile, a rejected prediction is corrected without crediting a kill,
# and fault injection is deterministic and recorded.
var count := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
	var timer := create_timer(120.0)
	timer.timeout.connect(func() -> void: print("[FAIL] fault suite watchdog timeout"); quit(1))
func _check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	root.size = Vector2i(1280,720)
	# --- 1. the four clocks and their declared bounds ---
	_check(NetworkTimeModel.INTERPOLATION_DELAY_TICKS == NetworkPoseBuffer.DELAY_TICKS,"the interpolation delay matches the production pose buffer (%d)"%NetworkTimeModel.INTERPOLATION_DELAY_TICKS)
	_check(NetworkTimeModel.SNAPSHOT_CAPACITY == NetworkPoseBuffer.CAPACITY,"the snapshot history matches the production buffer (%d)"%NetworkTimeModel.SNAPSHOT_CAPACITY)
	_check(NetworkTimeModel.MAX_EXTRAPOLATION_TICKS == 0 and not NetworkTimeModel.extrapolation_supported(),"extrapolation is declared unsupported: a missing packet freezes instead of inventing motion")
	_check(NetworkTimeModel.settlement_owner() == "server","exactly one owner settles a projectile (the server)")
	_check(NetworkTimeModel.compensation_window_ticks() <= NetworkTimeModel.INTERPOLATION_DELAY_TICKS,"the finite-speed compensation window is bounded and never rewinds the whole match")
	var model := NetworkTimeModel.new()
	_check(model.input_tick == 0 and model.server_tick == 0 and model.snapshot_tick == 0 and model.display_tick == 0.0,"the four clocks start separate and at zero")
	var display := model.advance_display(1.0,100)
	var target := float(100-NetworkTimeModel.INTERPOLATION_DELAY_TICKS)
	_check(display > 0.0 and display <= target,"the display catches up gradually and never runs ahead of the interpolation target (%.1f <= %.1f)"%[display,target])
	var settled := display
	for i in 20: settled = model.advance_display(1.0,100)
	_check(settled == target,"after enough frames the display settles exactly on the interpolation target (%.1f)"%settled)
	var forward := model.advance_display(1.0,100)
	_check(forward >= display and forward <= target,"the display never moves backwards while the authority advances")
	var stale := model.advance_display(1.0,90)
	_check(stale >= forward and model.snapshot_tick == 100,"an older snapshot cannot pull the display backwards")
	# --- 2. input acknowledgement and a bounded replay window ---
	var first := model.record_input(10)
	var second := model.record_input(11)
	var third := model.record_input(12)
	_check(int(second.sequence) > int(first.sequence),"each input gets a new sequence")
	_check(model.replay_inputs().size() == 3,"unacknowledged inputs are replayed")
	var ack := model.acknowledge(int(second.sequence),100)
	_check(int(ack.acked.size()) == 2 and int(ack.pending) == 1,"acknowledging a sequence clears every input up to it")
	_check(model.replay_inputs().size() == 1 and model.replay_inputs()[0].sequence == int(third.sequence),"only the still-unacknowledged input is replayed")
	var duplicate := model.acknowledge(int(second.sequence),99)
	_check(int(duplicate.acked.size()) == 0 and model.accepted_sequence == int(second.sequence),"a duplicate or stale acknowledgement changes nothing")
	_check(model.server_tick == 100,"a stale authority tick cannot lower the server clock")
	var far := NetworkTimeModel.new()
	for i in 20: far.record_input(i)
	var far_replay := far.replay_inputs()
	var bounded := 0
	for row in far_replay:
		if far.input_tick-int(row.tick) <= NetworkTimeModel.REPLAY_WINDOW_TICKS: bounded += 1
	_check(bounded == far_replay.size(),"replay never reaches outside the bounded window (%d inputs)"%far_replay.size())
	_check(far_replay.size() == NetworkTimeModel.REPLAY_WINDOW_TICKS+1,"the replay window is a tick distance, not a fixed count (%d inputs inside %d ticks)"%[far_replay.size(),NetworkTimeModel.REPLAY_WINDOW_TICKS])
	# --- 3. a rejected prediction is corrected and never credited as a kill ---
	var predicting := NetworkTimeModel.new()
	predicting.record_input(50)
	var played := predicting.predicted_feedback("hit",{"target":"B"})
	_check(not bool(played.corrected),"the client plays its prediction immediately")
	var corrected := predicting.reject_feedback("hit","not_owner")
	_check(bool(corrected.corrected) and str(corrected.reason) == "not_owner","the authority's refusal corrects the played prediction")
	_check(predicting.kills_credited == 0,"a corrected prediction credits no kill")
	_check(int(corrected.kills_credited) == 0,"the correction event records zero credited kills")
	var unknown := predicting.reject_feedback("kill","no_such_prediction")
	_check(not bool(unknown.corrected),"refusing an unpredicted event is recorded honestly, not silently accepted")
	_check(predicting.corrections.size() == 2,"every correction is recorded for the regression log")
	# --- 4. deterministic fault injection with a correction log ---
	var config := {"seed":7,"delay_ticks":2,"jitter_ticks":3,"reorder_window":2,"loss_percent":25.0}
	var injector_a := NetworkFaultInjector.new(); injector_a.configure(config)
	var injector_b := NetworkFaultInjector.new(); injector_b.configure(config)
	var plan_a := injector_a.plan(24)
	var plan_b := injector_b.plan(24)
	var identical := plan_a.size() == plan_b.size()
	for i in plan_a.size():
		if int(plan_a[i].deliver_at) != int(plan_b[i].deliver_at) or bool(plan_a[i].dropped) != bool(plan_b[i].dropped): identical = false
	_check(identical,"the same seed and conditions produce the same fault schedule")
	var stream: Array = []
	for i in 24: stream.append({"index":i})
	var delivered := injector_a.apply(stream)
	_check(delivered.size() < stream.size(),"loss actually removes packets from the stream (%d of %d)"%[delivered.size(),stream.size()])
	var loss_events := 0
	for row in injector_a.corrections:
		if str(row.kind) == "loss": loss_events += 1
	_check(loss_events == stream.size()-delivered.size(),"every dropped packet is recorded as a loss correction")
	var all_lost := NetworkFaultInjector.new()
	all_lost.configure({"seed":3,"loss_percent":100.0})
	_check(all_lost.apply(stream).is_empty() and all_lost.corrections.size() == stream.size(),"total loss delivers nothing and records every drop")
	var delayed := NetworkFaultInjector.new()
	delayed.configure({"seed":5,"delay_ticks":4})
	var delayed_stream := delayed.apply(stream)
	var delay_respected := true
	for row in delayed_stream:
		if int(row.deliver_at) < int(row.index)+4: delay_respected = false
	_check(delay_respected,"delay is applied to every delivered packet")
	var reordered := NetworkFaultInjector.new()
	reordered.configure({"seed":11,"delay_ticks":1,"jitter_ticks":4,"reorder_window":4})
	var reordered_stream := reordered.apply(stream)
	var out_of_order := false
	for i in range(1,reordered_stream.size()):
		if int(reordered_stream[i].index) < int(reordered_stream[i-1].index): out_of_order = true
	_check(out_of_order,"reordering genuinely changes the delivery order")
	_check(NetworkFaultInjector.conditions_label(config).contains("loss=25.0%"),"the injected conditions are labelled for the evidence log")
	_check(injector_a.summary().seed == 7 and int(injector_a.summary().faults_applied) > 0,"the injector summary records the seed and the fault count")
	# --- 5. production validity gates stay strict under faulted input ---
	_check(not NetworkPoseBuffer.valid_snapshot({}),"the production snapshot gate rejects an empty payload")
	_check(not NetworkPoseBuffer.valid_snapshot({"version":VehicleFramePose.NETWORK_VERSION}),"it rejects a snapshot missing its session and clocks")
	var snapshot := model.snapshot()
	for field in ["input_tick","server_tick","snapshot_tick","display_tick","interpolation_delay","max_extrapolation","compensation_window","settlement_owner"]:
		_check(snapshot.has(field),"the time model exposes %s for the network time document"%field)
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	print("NETWORK_FAULT_CHECKS_PASS" if failed == 0 else "NETWORK_FAULT_CHECKS_FAIL")
	quit(1 if failed else 0)
