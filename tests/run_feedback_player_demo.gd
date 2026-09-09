extends "res://tests/run_historical_demo.gd"
## Normal garage and keyboard/mouse. Audio recorded from the real Combat bus.
func run(flow: AppFlow) -> void:
	app=flow
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--shot-dir" and i+1<args.size(): shot_dir=args[i+1]
	if shot_dir.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await frames(25)
	await click(find_button(app.garage,"4 对 4 占点")); await frames(240)
	var scene:=app.training as TeamRange
	check(scene!=null and scene.team_ready,"normal garage entry starts an eight-vehicle battle")
	if scene==null: get_tree().quit(1); return
	var feedback:=scene.projectiles.feedback
	var recorder:=AudioEffectRecord.new(); recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var bus:=AudioServer.get_bus_index(CombatAudioPool.BUS)
	AudioServer.add_bus_effect(bus,recorder); recorder.set_recording_active(true)
	var before:=scene.actor.tank.global_position
	key(KEY_W,true); await frames(180); key(KEY_W,false); await frames(30)
	check(scene.actor.tank.global_position.distance_to(before)>1,"normal W input drives the vehicle and continuous feedback")
	var shot_before:=scene.actor.gunner.shots_fired
	mouse(MOUSE_BUTTON_LEFT,true); await frames(3); mouse(MOUSE_BUTTON_LEFT,false); await frames(70)
	check(scene.actor.gunner.shots_fired==shot_before+1 and feedback.presented.get("shot",0)>=1,"normal mouse click commits a real shot and matching sound")
	await capture("01_real_shot")
	await frames(420)
	var playing:=0
	for voice in feedback.audio.voices:
		if voice.player.playing: playing+=1
	check(playing>0 and feedback.audio.peak_db> -90,"actual audio driver is playing and Combat bus meter is non-silent")
	await tap(KEY_ESCAPE); await frames(12)
	check(feedback.audio.active_count()==0,"normal pause stops active sound sources")
	await click(scene.battle_ui.settings_button); await frames(10)
	await capture("02_sound_settings")
	var panel:=scene.battle_ui.overlay
	check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(panel.settings_panel.get_global_rect()),"settings panel fits the real viewport")
	var volume:=panel.find_child("CombatVolume",true,false) as HSlider
	await click(volume); await tap(KEY_HOME); await frames(5)
	check(AccessibilitySettings.audio_volume==0,"normal slider keyboard input selects mute")
	var effects:=panel.find_child("EffectQuality",true,false) as OptionButton
	await click(effects); await tap(KEY_HOME); await tap(KEY_DOWN); await tap(KEY_ENTER); await frames(10)
	check(AccessibilitySettings.fx_level==0,"normal settings popup disables visual effects")
	await capture("03_muted_effects_off")
	await tap(KEY_ESCAPE); await click(scene.hud.resume_btn); await frames(20)
	check(feedback.audio.active_count()==0,"resuming while muted leaves all audio silent")
	await tap(KEY_ESCAPE); await click(scene.battle_ui.settings_button)
	await click(effects)
	for i in 3: await tap(KEY_DOWN)
	await tap(KEY_ENTER); await frames(10)
	await click(volume)
	var slider_point:=volume.get_global_rect().position+Vector2(volume.size.x-12,volume.size.y*0.5)
	mouse(MOUSE_BUTTON_LEFT,true,slider_point); await frames(3); mouse(MOUSE_BUTTON_LEFT,false,slider_point); await frames(5)
	print("[slider restore] value=",volume.value," rect=",volume.get_global_rect()," focus=",get_viewport().gui_get_focus_owner())
	await tap(KEY_ESCAPE); await click(scene.hud.resume_btn); await frames(30)
	print("[restore audio] volume=",AccessibilitySettings.audio_volume," slider=",volume.value," paused=",scene._paused," tree=",get_tree().paused," voices=",feedback.audio.active_count()," actors=",feedback.actors.size()," phase=",scene.director.state.phase," effects=",AccessibilitySettings.fx_level)
	check(feedback.audio.active_count()>0,"normal settings restore current continuous sounds")
	recorder.set_recording_active(false)
	var recording:=recorder.get_recording()
	check(recording!=null and recording.data.size()>4000 and recording.save_to_wav(shot_dir+"/actual_combat.wav")==OK,"actual mixed Combat bus waveform saved")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var report:={"source":"actual driver and Combat bus recording","peak_db":feedback.audio.peak_db,
		"peak_voices":feedback.audio.peak_voices,"events":feedback.presented,"actors":scene.combat_actors().size()}
	var file:=FileAccess.open(shot_dir+"/AUDIO_REPORT.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	await tap(KEY_ESCAPE); await click(scene.hud._training_btn); await frames(20)
	check(app.training==null and app.garage!=null,"normal return to garage releases battle sound sources")
	await capture("04_quiet_garage")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failed])
	if failed==0: print("FEEDBACK_PLAYER_CHECKS_PASS")
	get_tree().quit(0 if failed==0 else 1)
