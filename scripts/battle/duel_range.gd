class_name DuelRange
extends AICombatRange
signal restart_requested
signal return_requested(result: Dictionary)
var match_director: MatchDirector
var battle_status: Label
var result_panel: PanelContainer
var result_title: Label
var result_text: Label
var restart_button: Button
var return_button: Button
var duel_ready := false

func _ready() -> void:
	super._ready()
	if not combat_ready: return
	match_director = MatchDirector.new()
	add_child(match_director)
	match_director.round_started.connect(_start_fighting)
	match_director.match_finished.connect(_finish_battle)
	for vehicle in combat_actors():
		vehicle.vehicle_destroyed.connect(match_director.on_vehicle_destroyed)
		vehicle.set_physics_process(false)
		vehicle.clear_commands()
		vehicle.gunner.training_resupply = false
		var visuals := RecoveryVisuals.new()
		vehicle.add_child(visuals)
		visuals.setup(vehicle)
	projectiles.projectile_finished.connect(match_director.on_finished_projectile)
	projectiles.projectile_damage.connect(match_director.on_damage)
	replay.allowed_record = func(_record: Dictionary) -> bool: return match_director.phase == "finished"
	replay.auto_replay = false
	hud.replay_toggle_button.visible = false
	_status.get_parent().get_parent().visible = false
	_build_match_ui()
	duel_ready = match_director.begin(combat_actors(),get_round_id())
	controller.commands_enabled = false
	controller.reset_pending()
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_world() -> void:
	TerrainFixtures.box(self,Vector3(0,-0.5,-18),Vector3(72,1,88))
	TerrainFixtures.box(self,Vector3(0,1.8,-22),Vector3(9,3.6,9),Color("736953"))
	TerrainFixtures.box(self,Vector3(16,1.6,-2),Vector3(5,3.2,7),Color("82795e"))
	TerrainFixtures.box(self,Vector3(-18,1.6,-40),Vector3(5,3.2,7),Color("82795e"))
	for x in [-36,36]: TerrainFixtures.box(self,Vector3(x,2,-18),Vector3(1,4,88))
	for z in [-62,26]: TerrainFixtures.box(self,Vector3(0,2,z),Vector3(72,4,1))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("819b9e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c3c2ac")
	env.environment.ambient_light_energy = 0.75
	add_child(env)

func _build_match_ui() -> void:
	battle_status = CoreUI.label(hud,"准备交战",23)
	battle_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	battle_status.offset_left = -230
	battle_status.offset_right = 230
	battle_status.offset_top = 24
	battle_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel = PanelContainer.new()
	hud.add_child(result_panel)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -340
	result_panel.offset_right = 340
	result_panel.offset_top = -218
	result_panel.offset_bottom = 218
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	result_panel.add_child(box)
	result_title = CoreUI.label(box,"结算",32)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 250
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	result_text = CoreUI.label(scroll,"",18)
	result_text.custom_minimum_size.x = 620
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",16)
	box.add_child(buttons)
	restart_button = CoreUI.button(buttons,"再来一局",func() -> void: restart_requested.emit())
	return_button = CoreUI.button(buttons,"返回车库",leave_match)
	CoreUI.button(buttons,"查看最后一炮",func() -> void: replay.show_history(projectiles.shot_records.count()-1))
	CoreUI.apply(result_panel)
	result_panel.visible = false

func _start_fighting() -> void:
	controller.reset_pending()
	controller.require_fire_release()
	controller.commands_enabled = true
	ai.reset_pending()
	ai.set_patrol(Vector3(0,0,6),Vector3(0,0,-42))
	for vehicle in combat_actors():
		vehicle.clear_commands()
		vehicle.set_physics_process(true)
		vehicle.gunner.resume_grace = GameConfig.RESUME_GRACE

func _finish_battle(result: Dictionary) -> void:
	projectiles.close_round()
	for vehicle in combat_actors():
		vehicle.clear_commands()
		vehicle.pause_block(true)
		vehicle.set_physics_process(false)
		vehicle.tank.forward_speed = 0
		vehicle.tank.velocity = Vector3.ZERO
		vehicle.turret.set_process(false)
	controller.commands_enabled = false
	controller.reset_pending()
	ai.reset_pending()
	replay.close()
	result_title.text = {"victory":"胜利","defeat":"战败","draw":"平局","abandoned":"已返回"}.get(result.outcome,"对局结束")
	var lines: Array[String] = ["1 对 1 歼灭 · %.1f 秒"%result.seconds,"双方采用相同的车型、弹药与模块规则。",""]
	for id in ["A","B"]:
		var stats: Dictionary = result.totals[id]
		lines.append("%s：发射 %d · 接触 %d · 未穿 %d\n有效模块损伤 %d · 乘员损伤 %d"%["玩家" if id == "A" else "电脑",stats.shots,stats.contacts,stats.stopped,stats.module_damage,stats.crew_damage])
		if result.deaths.has(id):
			lines.append("出局原因："+_cause(result.deaths[id].cause))
		lines.append("")
	if result.reason == "time_limit": lines.append("时间耗尽，双方仍存活，本局平局。")
	if result.reason == "simultaneous_destruction": lines.append("双方在同一物理步出局，本局平局。")
	lines.append("可查看本局实弹回放，或立即开始下一局。")
	result_text.text = "\n".join(lines)
	result_panel.visible = true
	hud.show_pause(false)
	get_tree().paused = false
	_paused = false
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _cause(value: String) -> String:
	return {"crew_out":"可用乘员不足","fire_crew_out":"火灾造成乘员失能","ammo_detonation":"弹药殉爆"}.get(value,CoreUI.word(value))

func leave_match() -> void:
	if match_director == null: return
	if match_director.phase != "finished": match_director.abandon()
	return_requested.emit(match_director.result.duplicate(true))

func _apply_projectile_damage(event: Dictionary, available_mm: float) -> Dictionary:
	if match_director == null or match_director.phase != "playing": return {"ok":false,"reason":"match_not_playing"}
	return super._apply_projectile_damage(event,available_mm)

func _reset_range() -> void: pass

func _unhandled_input(event: InputEvent) -> void:
	if not duel_ready: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R,KEY_X,KEY_TAB,KEY_1,KEY_2,KEY_3]:
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and match_director.phase == "finished":
			leave_match()
			return
	# Bypass laboratory shortcuts, preserving real pause and recovery inputs.
	if event.is_action_pressed("pause"):
		if _paused: _resume()
		else: _pause()

func _pause() -> void:
	if match_director != null and match_director.phase == "finished": return
	super._pause()
	if is_instance_valid(target_actor): target_actor.pause_block(true)
func _resume() -> void:
	super._resume()
	if is_instance_valid(target_actor):
		target_actor.pause_block(false)
		target_actor.gunner.resume_grace = GameConfig.RESUME_GRACE

func _process(delta: float) -> void:
	super._process(delta)
	if not duel_ready: return
	_status.get_parent().get_parent().visible = false
	hud.control_label.text = "1 对 1 歼灭"
	hud.hint_label.text = "W/S A/D 驾驶  鼠标瞄准  左键开火\nT 维修  F 灭火  C 替补\n绕过掩体寻找侧面 · Esc 菜单"
	hud.ammo_label.text = "弹药：%d"%source_actor.gunner.rounds_remaining
	hud.projectiles_label.text = "在飞弹丸：%d"%projectiles.active_count()
	var own := source_actor.state
	if not own.fires.is_empty(): hud.gunline_label.text = "起火！F 灭火 · 剩余灭火器 %d"%own.extinguisher_charges
	elif not source_actor.capabilities().drive: hud.gunline_label.text = "动力失能 · T 停车维修 / C 乘员替补"
	elif not source_actor.capabilities().fire: hud.gunline_label.text = "无法开火 · T 修炮闩 / C 替补炮手"
	else: hud.gunline_label.text = "可用乘员 %d / 5 · 寻找装甲较薄的侧面"%own.alive_crew_count()
	if not own.recovery_action.is_empty(): hud.gunline_label.text += " · %s %.1f秒"%[CoreUI.word(own.recovery_action),own.action_progress]
	if match_director.phase == "countdown": battle_status.text = "%d 秒后交战"%ceili(match_director.countdown_left)
	elif match_director.phase == "playing": battle_status.text = "歼灭敌方坦克 · %02d:%02d"%[int(match_director.elapsed)/60,int(match_director.elapsed)%60]
	else: battle_status.text = "对局已结束"
