class_name BattleUI
extends Node
## Owns view/focus state only. All battle decisions remain in the scene/director/actors.
var battle: Node3D
var overlay: BattleHUD
var intel: BattleIntel
var focus := InputFocusRouter.new()
var settings_button: Button
var _configured_lives := {}
var _legacy_labels: Array[Control] = []

func setup(scene: Node3D) -> void:
	# Direct scene/test instantiation must have the same named actions as the
	# normal app entry; the service is guarded and safe to call repeatedly.
	InputBindingService.initialize()
	battle = scene
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	overlay = BattleHUD.new()
	for child in battle.hud.get_children():
		if child is Label: _legacy_labels.append(child)
	battle.hud.add_child(overlay)
	battle.hud.move_child(overlay,0)
	intel = BattleIntel.new()
	add_child(intel)
	intel.actor_provider = Callable(battle,"combat_actors")
	intel.observer_provider = Callable(self,"observer")
	intel.clock_provider = func() -> float: return elapsed()
	overlay.board_closed.connect(_close_board)
	overlay.settings_closed.connect(_close_settings)
	overlay.settings_changed.connect(apply_settings)
	overlay.replay_close_requested.connect(battle.replay.close)
	settings_button = CoreUI.button(battle.hud.resume_btn.get_parent(),"显示与辅助",_open_settings)
	settings_button.set_meta("hud_font_size",17)
	battle.replay.allowed_record = func(_record: Dictionary) -> bool: return phase() == "finished" and AccessibilitySettings.replay_enabled
	battle.replay.view.chinese = true
	for control in battle.hud.resume_btn.get_parent().get_children():
		if control is Label: control.text = "已暂停"
		if control is Button and control.text == "Vehicle Inspector": control.visible = false
	battle.hud.resume_btn.text = "继续"
	if battle is TeamRange:
		var map: Dictionary = battle.minimap_metadata()
		overlay.minimap.world_rect = map.bounds
		overlay.minimap.obstacles.assign(map.obstacles)
		overlay.minimap.roads = map.get("roads",{})
		overlay.map_title.text = str(map.get("title","战术地图"))+"  ↑ 北"
		for label in battle.waiting_panel.find_children("*","Label",true,false):
			if label.text.contains("Tab"):
				label.text = "准备完毕后选择再出击；堵塞时等待安全位置。\nQ / E 切换观察友军，Tab 查看战况。"
	else:
		overlay.minimap.world_rect = Rect2(-36,-62,72,88)
		overlay.minimap.obstacles.assign([Rect2(-4.5,-26.5,9,9),Rect2(13.5,-5.5,5,7),Rect2(-20.5,-43.5,5,7)])
		overlay.minimap.has_point = false
	_mark_fonts(battle.hud._pause_root)
	_mark_fonts(battle.result_panel)
	if battle is TeamRange: _mark_fonts(battle.waiting_panel)
	apply_settings()
	_refresh_focus()

func phase() -> String:
	return battle.director.state.phase if battle is TeamRange else battle.match_director.phase
func elapsed() -> float:
	return battle.director.state.elapsed if battle is TeamRange else battle.match_director.elapsed
func player() -> VehicleActor: return battle.actor
func observer() -> VehicleActor:
	var own := player()
	if own == null or not own.state.destroyed: return own
	if not battle is TeamRange: return null
	var friends: Array[VehicleActor] = []
	for id in battle.director.state.roster:
		var vehicle: VehicleActor = battle.director.state.actor_for(id)
		if vehicle != null and vehicle.state.team_id == own.state.team_id and not vehicle.state.destroyed: friends.append(vehicle)
	return friends[posmod(battle.spectator_index,friends.size())] if not friends.is_empty() else null
func _mark_fonts(node: Node) -> void:
	if node is Label or node is Button:
		if not node.has_meta("hud_font_size"): node.set_meta("hud_font_size",node.get_theme_font_size("font_size"))
	for child in node.get_children(): _mark_fonts(child)
func apply_settings() -> void:
	AccessibilitySettings.apply(overlay)
	AccessibilitySettings.apply(battle.hud._pause_root)
	AccessibilitySettings.apply(battle.result_panel)
	if battle is TeamRange: AccessibilitySettings.apply(battle.waiting_panel)
	overlay.minimap.high_contrast = AccessibilitySettings.high_contrast
	for vehicle in battle.combat_actors(): AccessibilitySettings.apply_vehicle(vehicle)
	if not AccessibilitySettings.replay_enabled: battle.replay.close()

func match_info() -> Dictionary:
	var info := {"phase":phase(),"remaining":maxf(0,600-elapsed()),"countdown":0.0,"team_mode":battle is TeamRange,"title":"1 对 1 歼灭","objective":"歼灭敌方车辆 · 寻找侧后射击角度","tickets_text":"△ 玩家   对   ◆ 敌车"}
	if battle is TeamRange:
		var state: TeamMatchState = battle.director.state
		info.title = "占领据点 A"
		info.countdown = state.countdown
		info.tickets_text = "△ 友方 %d   ◆ 敌方 %d"%[state.tickets[1],state.tickets[2]]
		info.capture_progress = state.capture_progress
		info.owner = state.capture_owner
		info.objective = {0:"中立 · 驶入地图中央圆圈",1:"友方占领 · 守住据点持续扣敌票",2:"敌方占领 · 进入圆圈夺回据点"}[state.capture_owner]
		info.objective += " · %.0f%%"%(absf(state.capture_progress)*100)
		if state.contested: info.objective += " · 双方争夺中"
	else:
		info.countdown = battle.match_director.countdown_left
	if phase() == "finished": info.objective = "对局已结束"
	return info
func roster() -> Array:
	var rows: Array = []
	if battle is TeamRange:
		for id in battle.director.state.roster:
			var row: Dictionary = battle.director.state.roster[id]
			rows.append({"id":id,"friendly":row.team == player().state.team_id,"deaths":row.deaths})
	else:
		for id in ["A","B"]: rows.append({"id":id,"friendly":id == "A","deaths":battle.match_director.totals[id].deaths})
	return rows
func _input(event: InputEvent) -> void:
	if battle == null or not event.is_pressed() or event.is_echo(): return
	if is_instance_valid(overlay.input_settings): return
	if (event.is_action_pressed("replay_toggle") or event.is_action_pressed("replay_previous") or event.is_action_pressed("replay_next") or event.is_action_pressed("replay_export")) and (phase() != "finished" or not AccessibilitySettings.replay_enabled):
		overlay.notice = "本局结束后可按 V 查看实弹回放" if AccessibilitySettings.replay_enabled else "实弹回放已在显示设置中关闭"
		get_viewport().set_input_as_handled()
		return
	overlay.notice = ""
	if event.is_action_pressed("scoreboard") and phase() == "playing" and not battle._paused and not battle.replay.view.visible:
		overlay.scoreboard.visible = not overlay.scoreboard.visible
		_refresh_focus()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("spectate_previous") or event.is_action_pressed("spectate_next")) and battle is TeamRange and player().state.destroyed and phase() == "playing" and not battle._paused and not overlay.scoreboard.visible:
		battle.spectator_index += 1 if event.is_action_pressed("spectate_next") else -1
		get_viewport().set_input_as_handled()
	elif InputBindingService.is_pause(event):
		if overlay.settings_root.visible: _close_settings()
		elif overlay.scoreboard.visible: _close_board()
		elif battle.replay.view.visible: battle.replay.close()
		else: return
		get_viewport().set_input_as_handled()
func _open_settings() -> void:
	if not battle._paused: return
	overlay.settings_root.visible = true
	_refresh_focus()
func _close_settings() -> void:
	overlay.settings_root.visible = false
	_refresh_focus()
func _close_board() -> void:
	overlay.scoreboard.visible = false
	_refresh_focus()
func _refresh_focus() -> void:
	if battle == null or overlay == null: return
	var next_mode := "playing"
	if phase() != "playing": next_mode = phase()
	if player().state.destroyed and phase() == "playing": next_mode = "respawn"
	if overlay.scoreboard.visible: next_mode = "scoreboard"
	if battle._paused: next_mode = "pause"
	if overlay.settings_root.visible: next_mode = "settings"
	if battle.replay.view.visible: next_mode = "replay"
	focus.route(next_mode,player(),battle.controller)
	overlay.aim_allowed = next_mode == "playing"
	overlay.main_margin.visible = next_mode not in ["replay","settings"]
	overlay.replay_controls.visible = next_mode == "replay"
	battle.hud.show_pause(battle._paused and next_mode != "settings")
	if battle is TeamRange: battle.waiting_panel.visible = next_mode == "respawn"
	if phase() == "finished": battle.result_panel.visible = next_mode != "replay"

func _process(_delta: float) -> void:
	if battle == null or overlay == null: return
	if phase() != "playing": overlay.scoreboard.visible = false
	if not battle._paused: overlay.settings_root.visible = false
	_refresh_focus()
	for label in _legacy_labels: label.visible = false
	var live_visuals := {}
	for vehicle in battle.combat_actors():
		if not _configured_lives.has(vehicle.life_id):
			_configured_lives[vehicle.life_id] = true
			AccessibilitySettings.apply_vehicle(vehicle)
		live_visuals[vehicle.life_id] = true
		var friendly: bool = vehicle.state.team_id == player().state.team_id
		vehicle.label3d.visible = vehicle != player() and (friendly or intel.visible_enemy(vehicle.entity_id,vehicle.life_id))
		vehicle.label3d.text = ("△ 友军 " if friendly else "◆ 敌军 ")+vehicle.entity_id
		if friendly and vehicle.state.destroyed: vehicle.label3d.text = "△ 友军残骸"
	_configured_lives = live_visuals
	var protection := 0.0
	if battle is TeamRange: protection = float(battle.director.state.roster.A.protection_left)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var model := HUDPresenter.present(player(),match_info(),protection)
	if player().gunner.inventory.typed:
		var gun := player().gunner
		model["next_shell"] = gun.shell_label(gun.inventory.selected_shell)
		model["carrying_shell"] = gun.shell_label(gun.inventory.transfer_shell) if gun.inventory.in_transfer>0 else ""
	if battle is TeamRange: model["supply_status"] = battle.ammunition_supply.status.get(str(player().life_id),"")
	overlay.present(model,intel.snapshot(player()),camera,roster())
