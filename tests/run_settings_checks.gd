extends SceneTree
const APP_SCENE = preload("res://scenes/app.tscn")
var checks := 0
var failed := 0
var folder := "user://tests/settings029_%d" % Time.get_ticks_usec()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failed += 1
	print(("[PASS] " if ok else "[FAIL] ")+label)
func write(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(value); file.close()
func reopen(path: String) -> void:
	InputBindingService.initialized = false; InputBindingService.initialize(path)
func run() -> void:
	create_timer(120,true,false,true).timeout.connect(func() -> void: quit(2))
	var path := folder+"/input.json"
	reopen(path)
	AccessibilitySettings.audio_volume = 0.35
	var first_error := InputBindingService.apply_binding("fire",KEY_K)
	check(first_error.is_empty(),"T029-01 real settings transaction saves sound and key: "+first_error)
	if not first_error.is_empty():
		quit(1); return
	var first := FileAccess.get_file_as_string(path)
	AccessibilitySettings.audio_volume = 0.65
	check(InputBindingService.save().is_empty() and FileAccess.get_file_as_string(path+".bak")==first,"T029-03 backup contains last verified settings")
	reopen(path)
	check(is_equal_approx(AccessibilitySettings.audio_volume,0.65) and InputBindingService.bindings.fire==KEY_K,"T029-01 production reopen restores settings")
	var good := FileAccess.get_file_as_string(path)
	write(path,"{truncated")
	reopen(path)
	check(InputBindingService.bindings.fire==KEY_K and is_equal_approx(AccessibilitySettings.audio_volume,0.35) and not InputBindingService.problem.is_empty(),"T029-02 corrupt primary recovers backup with warning")
	check(InputBindingService.save().is_empty(),"T029-03 recovery can safely save again")
	var preserved := false
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("input.json.corrupt-") and FileAccess.get_file_as_string(folder.path_join(name))=="{truncated": preserved=true
	check(preserved,"T029-03 exact corrupt original is retained")
	var candidate: Dictionary = JSON.parse_string(good)
	var legacy := candidate.duplicate(true); legacy.schema=1; legacy.erase("display"); legacy.erase("language"); legacy.accessibility.erase("subtitles_enabled")
	write(folder+"/legacy.json",JSON.stringify(legacy)); reopen(folder+"/legacy.json")
	check(InputBindingService.problem.is_empty() and AccessibilitySettings.subtitles_enabled and InputBindingService.bindings.fire==KEY_K,"T029-02 schema 1 migration fills only new defaults")
	var malformed: Array = ["","{","[]",JSON.stringify({"schema":2})]
	for field in ["audio_volume","ui_scale","fx_level"]:
		var invalid := candidate.duplicate(true); invalid.accessibility[field]=999; malformed.append(JSON.stringify(invalid))
	for field in ["reduce_flashes","stable_camera"]:
		var invalid := candidate.duplicate(true); invalid.accessibility[field]="false"; malformed.append(JSON.stringify(invalid))
	var invalid := candidate.duplicate(true); invalid.bindings.fire="res://evil.gd"; malformed.append(JSON.stringify(invalid))
	invalid=candidate.duplicate(true); invalid.bindings.fire=KEY_W; malformed.append(JSON.stringify(invalid))
	invalid=candidate.duplicate(true); invalid.display.width=1280.5; malformed.append(JSON.stringify(invalid))
	invalid=candidate.duplicate(true); invalid.language="res://evil.gd"; malformed.append(JSON.stringify(invalid))
	invalid=candidate.duplicate(true); invalid.accessibility.script="res://evil.gd"; malformed.append(JSON.stringify(invalid))
	for index in malformed.size():
		var bad_path := folder+"/bad_%d.json" % index; write(bad_path,malformed[index]); reopen(bad_path)
		check(not InputBindingService.problem.is_empty() and InputBindingService.bindings.fire==-1,"T029-02 malformed fixture %d opens with defaults" % index)
	var future := candidate.duplicate(true); future.schema=99
	write(path,JSON.stringify(future)); reopen(path)
	check(not InputBindingService.writable and not InputBindingService.reset_settings().is_empty() and FileAccess.get_file_as_string(path)==JSON.stringify(future),"T029-02 future primary blocks reset and overwrite even with old good backup")
	write(path,good); write(path+".bak",JSON.stringify(future)); reopen(path)
	check(not InputBindingService.writable and not InputBindingService.save().is_empty(),"T029-02 future backup is protected too")
	write(path+".bak",good); reopen(path)
	DirAccess.make_dir_absolute(path+".tmp")
	# Keep this a storage failure: L is now the binocular binding.
	var candidate_is_valid := InputBindingService.valid_code(KEY_O,"fire") and InputBindingService.conflicts("fire",KEY_O).is_empty()
	check(candidate_is_valid and not InputBindingService.apply_binding("fire",KEY_O).is_empty() and InputBindingService.bindings.fire==KEY_K and FileAccess.get_file_as_string(path)==good,"T029-03 temp write failure retains disk and active binding")
	DirAccess.remove_absolute(path+".tmp")
	DirAccess.make_dir_absolute(path+".bak.tmp")
	check(not InputBindingService.save().is_empty() and FileAccess.get_file_as_string(path)==good,"T029-03 backup failure retains primary")
	DirAccess.remove_absolute(path+".bak.tmp")
	DirAccess.make_dir_absolute(path+".lock")
	check(not InputBindingService.save().is_empty() and FileAccess.get_file_as_string(path)==good,"T029-03 concurrent writer lock refuses replacement")
	DirAccess.remove_absolute(path+".lock")
	var blocked := folder+"/target_directory"; DirAccess.make_dir_absolute(blocked); reopen(blocked)
	check(not InputBindingService.save().is_empty() and DirAccess.dir_exists_absolute(blocked),"T029-03 actual rename failure keeps target intact")
	reopen(path)
	var profile := ProfileStore.new(folder+"/commander")
	var data := profile.snapshot(); data.tutorial={"chapter":2,"completed":[0,1]}
	check(profile.commit(data).ok,"T029-01 isolated progress saved to actual disk")
	check(InputBindingService.reset_settings().is_empty() and ProfileStore.new(folder+"/commander").snapshot().tutorial.chapter==2,"T029-04 settings reset leaves progress intact")
	check(InputBindingService.hint("fire")=="鼠标左键" and "鼠标左键" in InputBindingService.driving_hint(),"T029-04 restored bindings update live hints")
	var service := ProgressionService.new(profile)
	var config_data: Dictionary = profile.snapshot().garage; config_data.mode="normal"
	var config: MatchConfig = MatchConfig.build(config_data,profile.service,profile.snapshot().unlocked).config
	var registration := service.register_match(config)
	var before := profile.snapshot()
	var settings_before_reset := FileAccess.get_file_as_string(path)
	check(registration.ok and profile.reset_progress().ok,"T029-04 progress reset commits through production profile transaction")
	data=profile.snapshot()
	check(data.tutorial.completed.is_empty() and data.pending.is_empty() and data.profile_id==before.profile_id and data.next_match==before.next_match and data.revision>before.revision,"T029-05 reset preserves identity and monotonic match sequence")
	check(not service.apply_result_once(registration.token,{"outcome":"victory"}).ok,"T029-05 pre-reset pending match cannot reward cleared progress")
	check(FileAccess.get_file_as_string(path)==settings_before_reset,"T029-04 progress reset leaves settings file intact")
	# A future slot beside a valid old slot must never be overwritten by rollback or reset.
	var future_profile := data.duplicate(true); future_profile.schema_version=99
	var slot := folder+"/commander."+str((data.revision+1)%2)+".json"; write(slot,JSON.stringify(future_profile))
	var upgraded := ProfileStore.new(folder+"/commander")
	check(not upgraded.writable and not upgraded.reset_progress().ok,"T029-02 future profile beside old valid slot is read-only")
	check(not profile.commit(profile.snapshot()).ok and FileAccess.get_file_as_string(slot)==JSON.stringify(future_profile),"T029-03 active old instance also rejects new future slot")
	print("=== 结果: %d 项检查, %d 失败 ===" % [checks,failed])
	if failed==0: print("SETTINGS_CHECKS_PASS")
	quit(0 if failed==0 else 1)
