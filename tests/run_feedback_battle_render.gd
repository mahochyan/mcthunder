extends SceneTree
## Eight real AI actors; observer follows a live actor. Wall-clock audio capture.
var count:=0
var failed:=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	count+=1
	if not ok: failed+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var folder:=""
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): folder=args[i+1]
	if folder.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	var scene:=(load(MapRegistry.scene_path("industrial_edge")) as PackedScene).instantiate() as VillageRange
	scene.selected_vehicle_id=VehicleCatalog.IDS[0]; scene.ai_only=true; scene.match_seed=26026
	root.add_child(scene); current_scene=scene
	for i in 15: await process_frame
	check(scene.team_ready and scene.combat_actors().size()==8,"real industrial map starts eight independently controlled AI vehicles")
	var feedback:=scene.projectiles.feedback
	var recorder:=AudioEffectRecord.new(); recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index(CombatAudioPool.BUS)
	AudioServer.add_bus_effect(bus,recorder); recorder.set_recording_active(true)
	var start:=Time.get_ticks_msec()
	var playing_peak:=0
	while Time.get_ticks_msec()-start<90000:
		var target:=scene.actor
		for actor in scene.combat_actors():
			if not actor.state.destroyed: target=actor; break
		var point:=target.tank.global_position
		scene.spectator.position=point+Vector3(7,4,10); scene.spectator.look_at(point+Vector3.UP); scene.spectator.current=true
		await process_frame
		var playing:=0
		for voice in feedback.audio.voices:
			if voice.player.playing: playing+=1
		playing_peak=maxi(playing_peak,playing)
	recorder.set_recording_active(false)
	var recording:=recorder.get_recording()
	check(recording!=null and recording.save_to_wav(folder+"/eight_vehicle_mix.wav")==OK,"90-second actual eight-vehicle audio bus recording saved")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	check(feedback.presented.get("shot",0)>=4,"live AI battle actually fires multiple shots during measured interval")
	check(playing_peak>=8 and feedback.audio.peak_voices<=32,"actual driver plays multiple vehicle sources within the 32-voice budget")
	check(feedback.audio.peak_db> -90 and feedback.audio.peak_db< -1,"actual Combat bus peak is non-silent with clipping headroom")
	var output:={"seed":26026,"seconds":90,"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),
		"peak_db":feedback.audio.peak_db,"peak_voices":feedback.audio.peak_voices,"actual_playing_peak":playing_peak,
		"events":feedback.presented,"accepted_voices":feedback.audio.accepted,"rejected_lower_priority":feedback.audio.rejected,
		"telemetry":TelemetrySnapshot.capture(scene),"scope":"real eight-AI audio capture, observer camera, not human listening acceptance"}
	var file:=FileAccess.open(folder+"/AUDIO_BUDGET.json",FileAccess.WRITE); file.store_string(JSON.stringify(output,"  ")); file.close()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/eight_vehicle_battle.png")==OK,"real final battle frame captured")
	scene.free(); await process_frame; await process_frame
	OS.delay_msec(100)
	print("[audio budget] ",JSON.stringify(output))
	print("=== 结果: %d 项检查, %d 失败 ==="%[count,failed])
	if failed==0: print("FEEDBACK_BATTLE_CHECKS_PASS")
	quit(0 if failed==0 else 1)
