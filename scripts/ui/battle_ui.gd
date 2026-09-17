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
	settings_button = CoreUI.button(battle.hud.resume_btn.get_parent(),LocalizationService.text("ui_7a35569d9e07"),_open_settings)
	settings_button.set_meta("hud_font_size",17)
	battle.replay.allowed_record = func(_record: Dictionary) -> bool: return phase() == "finished" and AccessibilitySettings.replay_enabled
	battle.replay.view.chinese = true
	for control in battle.hud.resume_btn.get_parent().get_children():
		if control is Label: control.text = LocalizationService.text("ui_eb0c326b60ae")
		if control is Button and control.text == LocalizationService.text("ui_48fbf5cf003e"): control.visible = false
	battle.hud.resume_btn.text = LocalizationService.text("ui_7c9691192f1b")
	if battle is TeamRange:
		var map: Dictionary = battle.minimap_metadata()
		overlay.minimap.world_rect = map.bounds
		overlay.minimap.obstacles.assign(map.obstacles)
		overlay.minimap.roads = map.get("roads",{})
		overlay.map_title.text = str(map.get("title",LocalizationService.text("ui_da5cefee90ca")))+LocalizationService.text("ui_d16c23797bcd")
		for label in battle.waiting_panel.find_children("*","Label",true,false):
			if label.text.contains("Tab"):
				label.text = LocalizationService.text("ui_914d40ad034c")
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

## WT-UI-008 (S05): the player's latest shot reduced to a read-only summary for the HUD. Only the recorded contact
## and damage counts and the recorded terminal result are read; damage is never re-resolved and no rule is touched.
func latest_hit_summary() -> Dictionary:
	if battle == null or player() == null: return {}
	var projectiles: Variant = battle.get("projectiles")
	if projectiles == null or projectiles.shot_records == null or projectiles.shot_records.count() == 0: return {}
	var shooter := player().entity_id
	for i in range(projectiles.shot_records.count()-1,-1,-1):
		var record: Dictionary = projectiles.shot_records.get_record(i)
		if str(record.get("identity",{}).get("shooter_id","")) != shooter: continue
		return {"hit_result":str((record.get("terminal",{}) as Dictionary).get("result","")),
			"hit_contacts":(record.get("contacts",[]) as Array).size(),
			"hit_damage":(record.get("damage",[]) as Array).size(),
			"hit_shot_id":int(record.get("identity",{}).get("round_id",0))}
	return {}

func _notification(what: int) -> void:
	# The pointer must stay usable while the window is in the background. Releasing on focus loss is a UX rule, and
	# returning focus simply lets the router capture again because the match is still running.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: focus.window_focus(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: focus.window_focus(true)

func match_info() -> Dictionary:
	var info := {"phase":phase(),"remaining":maxf(0,600-elapsed()),"countdown":0.0,"team_mode":battle is TeamRange,"title":LocalizationService.text("ui_a22a88d8dfc5"),"objective":LocalizationService.text("ui_286a67c287e7"),"tickets_text":LocalizationService.text("ui_5403acaeb2a0")}
	if battle is TeamRange:
		var state: TeamMatchState = battle.director.state
		info.title = LocalizationService.text("ui_242f2e9387de")
		info.countdown = state.countdown
		info.tickets_text = LocalizationService.text("ui_5a9fa19a1212")%[state.tickets[1],state.tickets[2]]
		info.capture_progress = state.capture_progress
		info.owner = state.capture_owner
		info.objective = {0:LocalizationService.text("ui_bf58a1adae2f"),1:LocalizationService.text("ui_dcccd3d21109"),2:LocalizationService.text("ui_90071e9b4da2")}[state.capture_owner]
		info.objective += " · %.0f%%"%(absf(state.capture_progress)*100)
		if state.contested: info.objective += LocalizationService.text("ui_71bc0ab7f129")
		if state.objectives != null:
			info.objectives = state.objectives.snapshot()
			if info.objectives.size() > 1:
				var ids := PackedStringArray()
				for row in info.objectives: ids.append(str(row.id))
				info.title = "据点争夺 · "+" / ".join(ids)
				info.objective = "控制据点，消耗敌方票数"
	else:
		info.countdown = battle.match_director.countdown_left
	if phase() == "finished": info.objective = LocalizationService.text("ui_3c03903fbcd6")
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
		overlay.notice = LocalizationService.text("ui_f11ab0250edc") if AccessibilitySettings.replay_enabled else LocalizationService.text("ui_57ab613cd32c")
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
		vehicle.label3d.text = (LocalizationService.text("ui_67f12d880732") if friendly else LocalizationService.text("ui_ab74b5d20421"))+vehicle.entity_id
		if friendly and vehicle.state.destroyed: vehicle.label3d.text = LocalizationService.text("ui_27b725194fbb")
	_configured_lives = live_visuals
	var protection := 0.0
	if battle is TeamRange: protection = float(battle.director.state.roster.A.protection_left)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var model := HUDPresenter.present(player(),match_info(),protection,latest_hit_summary())
	if player().gunner.inventory.typed:
		var gun := player().gunner
		model["next_shell"] = gun.shell_label(gun.inventory.selected_shell)
		model["shell_option_count"] = gun.shell_options.size()
		model["carrying_shell"] = gun.shell_label(gun.inventory.transfer_shell) if gun.inventory.in_transfer>0 else ""
	if battle is TeamRange: model["supply_status"] = battle.ammunition_supply.status.get(str(player().life_id),"")
	overlay.present(model,intel.snapshot(player()),camera,roster())
