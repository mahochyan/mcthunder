class_name ReplayController
extends Node
## Presentation coordinator; permission callback is mandatory for showing any record.
signal overlay_changed(open: bool)
var manager: ProjectileManager
var view: ReplayView
var allowed_record := Callable()
var auto_replay := true
var history_index := -1
var hud: HUD
var last_export: Dictionary = {}

func setup(projectiles: ProjectileManager, target_hud: HUD, permission: Callable) -> void:
	manager = projectiles
	hud = target_hud
	allowed_record = permission
	view = ReplayView.new()
	hud.add_child(view)
	view.visibility_changed.connect(func() -> void: overlay_changed.emit(view.visible))
	manager.shot_record_ready.connect(_on_record)
	manager.shot_records_cleared.connect(clear)
	hud.replay_toggle_requested.connect(toggle_auto)

func _on_record(record: Dictionary) -> void:
	history_index = manager.shot_records.count()-1
	if auto_replay and allowed_record.is_valid() and allowed_record.call(record) and (not record.contacts.is_empty() or not record.damage.is_empty()):
		view.present(record,true)

func toggle_auto() -> void:
	auto_replay = not auto_replay
	hud.replay_toggle_button.text = "Auto Replay: " + ("ON" if auto_replay else "OFF")
	if view.chinese: hud.replay_toggle_button.text = "自动回放："+("开" if auto_replay else "关")
	if not auto_replay: view.close_view()

func show_history(index: int) -> bool:
	var record := manager.shot_records.get_record(index)
	if record.is_empty():
		view.show_error("no_record_available")
		return false
	if not allowed_record.is_valid() or not allowed_record.call(record):
		view.show_error("record_not_available_in_this_mode")
		return false
	history_index = index
	return view.present(record,false).get("ok",false)

func clear() -> void:
	history_index = -1
	if is_instance_valid(view): view.clear_display()

func close() -> void:
	if is_instance_valid(view): view.close_view()

func export_current() -> Dictionary:
	var record := manager.shot_records.get_record(history_index)
	if record.is_empty() or not allowed_record.is_valid() or not allowed_record.call(record):
		return {"ok":false,"reason":"no_authorized_record"}
	var encoded := ShotRecordCodec.encode(record)
	if not encoded.ok: return encoded
	var identity: Dictionary = record.identity
	var path := "user://shot_records/round_%d_life_%d_shot_%d_projectile_%d_%d.json" % [identity.round_id,identity.shooter_life_id,identity.shot_id,identity.projectile_id,int(Time.get_unix_time_from_system()*1000)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shot_records"))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return {"ok":false,"reason":"export_open_failed"}
	file.store_string(encoded.json)
	file.close()
	return {"ok":true,"path":path}

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_V:
			if view.visible: close()
			else: show_history(manager.shot_records.count()-1)
		KEY_COMMA:
			show_history(maxi(0,history_index-1))
		KEY_PERIOD:
			show_history(mini(manager.shot_records.count()-1,history_index+1))
		KEY_N:
			if view.visible: view.select_event(view.selected_event+1)
		KEY_J:
			var exported := export_current()
			last_export = exported.duplicate(true)
			if exported.ok: print("[replay] exported "+ProjectSettings.globalize_path(exported.path))
			if view.visible:
				view._title.text = "REPLAY EXPORTED" if exported.ok else str(exported.get("reason","export_failed")).to_upper()
		_:
			return
	get_viewport().set_input_as_handled()
