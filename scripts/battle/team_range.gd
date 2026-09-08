class_name TeamRange
extends BallisticsRange
signal restart_requested
signal return_requested(result: Dictionary)
var director: TeamMatchDirector
var nav := DriveNavigator.new()
var wrecks: WreckRegistry
var team_ready := false
var top_label: Label
var action_label: Label
var capture_ring: MeshInstance3D
var capture_material: StandardMaterial3D
var waiting_panel: PanelContainer
var waiting_label: Label
var respawn_button: Button
var vehicle_choice: OptionButton
var result_panel: PanelContainer
var result_text: Label
var restart_button: Button
var return_button: Button
var spectator: Camera3D
var spectator_index := 0
var shield_visuals: Dictionary = {}
var battle_ui: BattleUI
var match_seed := 1600
var ai_only := false # Explicit scenario-runner configuration; normal garage play is false.

func _ready() -> void:
	super._ready()
	if not _initialized: return
	director = TeamMatchDirector.new()
	add_child(director)
	director.begin()
	if ai_only: director.state.roster.A.player = false
	nav.configure(navigation_graph())
	director.respawns.spawn_provider = Callable(self,"spawn_slot")
	director.round_started.connect(_start_playing)
	director.vehicle_lost.connect(_on_lost)
	director.match_finished.connect(_finish_match)
	wrecks = WreckRegistry.new()
	add_child(wrecks)
	wrecks.protected_provider = func(vehicle: VehicleActor) -> bool: return vehicle == actor
	actor.tank.global_transform = spawn_candidates(1)[0]
	_configure_vehicle(actor,"A")
	director.state.register_spawn("A",actor)
	for id in director.state.roster:
		if id == "A": continue
		var vehicle := spawn_slot(id)
		if vehicle == null:
			push_error("016 initial spawn blocked: "+id)
			return
		director.state.register_spawn(id,vehicle)
	projectiles.contact_policy = Callable(self,"contact_policy")
	projectiles.damage_handler = Callable(self,"_apply_projectile_damage")
	replay.allowed_record = func(_record: Dictionary) -> bool: return director.state.phase == "finished"
	replay.auto_replay = false
	replay.view.chinese = true
	hud.replay_toggle_button.visible = false
	CoreUI.apply(hud)
	hud.font_cjk = true
	hud.S = hud._strings(true)
	_build_ui()
	_build_capture_ring()
	spectator = Camera3D.new()
	spectator.position = Vector3(-30,28,55)
	add_child(spectator)
	spectator.look_at(Vector3.ZERO)
	if ai_only:
		spectator.position = Vector3(-115,60,125)
		spectator.look_at(Vector3.ZERO)
		spectator.current = true
	controller.commands_enabled = false
	controller.reset_pending()
	team_ready = true
	battle_ui = BattleUI.new()
	add_child(battle_ui)
	battle_ui.setup(self)

func _build_world() -> void: TeamArena.build(self)
func navigation_graph() -> Dictionary: return TeamArena.graph()
func spawn_candidates(team: int) -> Array[Transform3D]: return TeamArena.candidates(team)
func objective_goal(team: int, index: int) -> Vector3: return TeamArena.goal(team,index)
func minimap_metadata() -> Dictionary:
	return {"bounds":Rect2(-50,-70,100,140),"obstacles":[Rect2(-10,-36,20,4),Rect2(-10,32,20,4),Rect2(-16,12,8,6),Rect2(8,-18,8,6)],"title":"灰盒靶场"}
func get_round_id() -> int: return director.state.match_id if director != null else 0
func combat_actors() -> Array:
	var out: Array = []
	for child in get_children():
		if child is VehicleActor and not child.is_queued_for_deletion(): out.append(child)
	return out
func query_snapshots() -> Array:
	var out: Array = []
	for vehicle in combat_actors():
		if vehicle.damage_layout_override != null: out.append(QuerySnapshotBuilder.build_from_vehicle(vehicle.tank,vehicle.damage_layout_override))
	return out
func projectile_exclude_rids(shooter_id: String, shooter_life_id: int) -> Array[RID]:
	var vehicle := find_actor(shooter_id,shooter_life_id)
	var excluded: Array[RID] = []
	if vehicle != null: excluded.append(vehicle.tank.get_rid())
	return excluded
func find_actor(id: String, life: int) -> VehicleActor:
	for vehicle in combat_actors():
		if vehicle.entity_id == id and vehicle.life_id == life: return vehicle
	return null

func spawn_slot(id: String) -> VehicleActor:
	if director == null or director.state.phase not in ["countdown","playing"]: return null
	var row: Dictionary = director.state.roster[id]
	var occupied: Array[Vector3] = []
	for existing in combat_actors(): occupied.append(existing.tank.global_position)
	var candidates := spawn_candidates(row.team)
	var checked := SpawnSelector.evaluate(get_world_3d().direct_space_state,candidates,Vector3(2.85,1.68,5.45),occupied)
	if not checked.ok: return null
	var vehicle := VehicleActor.new()
	vehicle.name = "Vehicle_"+id+"_"+str(row.spawns+1)
	add_child(vehicle)
	var setup := vehicle.setup(defs,"player_tank",id,row.team,checked.transform,2 if id == "A" else 4,null)
	if not setup.ok: vehicle.free(); return null
	_configure_vehicle(vehicle,id)
	if id == "A":
		actor = vehicle
		if not ai_only:
			vehicle.set_controller(controller)
			controller.reset_pending()
			controller.require_fire_release()
			controller.commands_enabled = true
			if is_instance_valid(spectator): spectator.current = false
			vehicle.cam_rig.cam.current = true
			if is_instance_valid(waiting_panel): waiting_panel.visible = false
			if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return vehicle

func _configure_vehicle(vehicle: VehicleActor, id: String) -> void:
	M4EngineeringProfile.apply(vehicle)
	vehicle.state.recovery_enabled = true
	vehicle.gunner.projectile_manager = projectiles
	vehicle.gunner.snapshot_provider = Callable(self,"query_snapshots")
	vehicle.gunner.round_provider = Callable(self,"get_round_id")
	vehicle.gunner.shell = vehicle.gunner.shell.duplicate(true)
	vehicle.gunner.shell.id = "team_ap120"
	vehicle.gunner.shell.armor_policy = "resolve"
	vehicle.gunner.shell.penetration_curve = PackedVector2Array([Vector2(0,120),Vector2(200,120)])
	vehicle.gunner.training_resupply = false
	vehicle.command_observer = Callable(director,"observe_command")
	vehicle.vehicle_destroyed.connect(director.on_vehicle_destroyed)
	vehicle.label3d.font = CoreUI.FONT
	vehicle.label3d.text = "玩家" if id == "A" else ("友军 "+id if vehicle.state.team_id == 1 else "敌军 "+id)
	vehicle.label3d.modulate = Color("8ecde6") if vehicle.state.team_id == 1 else Color("e7ae8b")
	var visuals := RecoveryVisuals.new()
	vehicle.add_child(visuals)
	visuals.setup(vehicle)
	var shield := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.8
	ring.outer_radius = 1.9
	ring.rings = 24
	ring.ring_segments = 4
	shield.mesh = ring
	shield.position.y = 0.08
	shield.scale.z = 1.65
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("96e6ee")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield.material_override = material
	vehicle.tank.add_child(shield)
	shield_visuals[vehicle.life_id] = {"actor":weakref(vehicle),"mesh":shield}
	if id != "A" or ai_only:
		var ai := AITankController.new()
		vehicle.add_child(ai)
		var index := 0 if id.length() == 1 else int(id.substr(1))-1
		ai.configure(vehicle,nav,Callable(self,"combat_actors"),"normal",match_seed+vehicle.state.team_id*100+index*17+int(director.state.roster[id].spawns)*101)
		ai.advance_while_engaged = true
		ai.set_patrol(objective_goal(vehicle.state.team_id,index),spawn_candidates(vehicle.state.team_id)[index].origin*Vector3(1,0,1))
		vehicle.set_controller(ai)
		vehicle.cam_rig.set_process(false)
		vehicle.cam_rig.set_physics_process(false)
		vehicle.gunner.aim_preview_enabled = false
		vehicle.turret.set_aim_point(Vector3(0,2,0))
		vehicle.turret.snap_to_aim()
	vehicle.set_physics_process(director.state.phase == "playing")

func contact_policy(shooter: Dictionary, contact: Dictionary) -> Dictionary:
	if director == null or director.state.phase != "playing" or shooter.get("round_id",-1) != get_round_id(): return {"allow":false,"reason":"match_not_playing"}
	var target := find_actor(str(contact.get("entity_id","")),int(contact.get("life_id",0)))
	if target == null: return {"allow":false,"reason":"stale_target"}
	if target.state.team_id == shooter.get("shooter_team_id",-1): return {"allow":false,"reason":"friendly_block"}
	if target.state.destroyed: return {"allow":false,"reason":"wreck_block"}
	if director.state.is_protected(target.entity_id,target.life_id): return {"allow":false,"reason":"spawn_protected"}
	return {"allow":true}

func _apply_projectile_damage(event: Dictionary, available_mm: float) -> Dictionary:
	if director == null or director.state.phase != "playing" or int(event.get("round_id",-1)) != get_round_id(): return {"ok":false,"reason":"match_not_playing"}
	var vehicle := find_actor(str(event.get("entity_id","")),int(event.get("life_id",0)))
	if vehicle == null or vehicle.state.destroyed or director.state.is_protected(vehicle.entity_id,vehicle.life_id): return {"ok":false,"reason":"target_unavailable"}
	var shooter := director.state.actor_for(str(event.get("shooter_id","")))
	if shooter != null and shooter.state.team_id == vehicle.state.team_id: return {"ok":false,"reason":"friendly_block"}
	return vehicle.apply_projectile_damage(event,available_mm)

func _start_playing() -> void:
	controller.reset_pending()
	controller.require_fire_release()
	controller.commands_enabled = true
	for vehicle in combat_actors(): vehicle.set_physics_process(true)

func _on_lost(id: String) -> void:
	var vehicle := director.state.actor_for(id)
	if vehicle == null: return
	vehicle.set_controller(null)
	vehicle.set_physics_process(false)
	vehicle.gunner.aim_preview_enabled = false
	vehicle.cam_rig.set_process(false)
	vehicle.cam_rig.set_physics_process(false)
	vehicle.turret.set_process(false)
	vehicle.tank.forward_speed = 0
	vehicle.tank.velocity = Vector3.ZERO
	# A previous player hull becomes ordinary visible cover in the next life's gunsight.
	for geometry in vehicle.tank.find_children("*","GeometryInstance3D",true,false): geometry.layers = 4
	wrecks.register(vehicle)
	if id == "A" and not ai_only:
		controller.commands_enabled = false
		controller.reset_pending()
		spectator.current = true
		waiting_panel.visible = true
		if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func request_respawn() -> void:
	if director.state.phase != "playing": return
	var row: Dictionary = director.state.roster.A
	if row.respawn_at >= 0 and director.state.elapsed >= row.respawn_at: row.respawn_requested = true

func abandon_vehicle() -> void:
	if not team_ready or director.state.phase != "playing" or actor.state.destroyed: return
	if actor.state.destroy_once("abandoned_vehicle",{"round_id":get_round_id()}):
		actor._commit_death()
		actor._publish_death()
	if _paused: _resume()

func _finish_match(result: Dictionary) -> void:
	projectiles.close_round()
	wrecks.set_physics_process(false)
	for vehicle in combat_actors():
		vehicle.pause_block(true)
		vehicle.clear_commands()
		vehicle.set_physics_process(false)
		vehicle.turret.set_process(false)
		vehicle.tank.forward_speed = 0
		vehicle.tank.velocity = Vector3.ZERO
	controller.commands_enabled = false
	controller.reset_pending()
	waiting_panel.visible = false
	result_panel.visible = true
	var explanation: String = {"victory":"敌方票数耗尽。","defeat":"友方票数耗尽。","draw":"双方票数同时耗尽。","abandoned":"已离开本局。"}.get(result.outcome,"")
	if result.reason == "time_limit": explanation = "时间耗尽，按剩余票数结算。"
	result_text.text = "%s\n\n4 对 4 占点 · %.1f 秒\n友方 %d 票 / 敌方 %d 票\n玩家发射 %d 发\n\n%s"%[{"victory":"胜利","defeat":"战败","draw":"平局","abandoned":"已返回"}.get(result.outcome,"结束"),result.seconds,result.tickets[1],result.tickets[2],result.shots,explanation]
	hud.show_pause(false)
	get_tree().paused = false
	_paused = false
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func leave_match() -> void:
	if director.state.phase != "finished": director.finish_once("abandoned","player_returned")
	return_requested.emit(director.state.result.duplicate(true))

func _build_capture_ring() -> void:
	capture_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = TeamMatchState.CAPTURE_RADIUS-0.1
	torus.outer_radius = TeamMatchState.CAPTURE_RADIUS+0.1
	torus.rings = 64
	torus.ring_segments = 4
	capture_ring.mesh = torus
	capture_ring.position.y = 0.08
	capture_material = StandardMaterial3D.new()
	capture_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	capture_ring.material_override = capture_material
	add_child(capture_ring)
	CoreVehicleVisual.box(self,Vector3(0,2,0),Vector3(0.12,4,0.12),Color("d2d4b7"))
	var flag := Label3D.new()
	flag.text = "A · 据点"
	flag.font = CoreUI.FONT
	flag.font_size = 60
	flag.position = Vector3(0,4.4,0)
	add_child(flag)

func _panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x/2
	panel.offset_right = size.x/2
	panel.offset_top = -size.y/2
	panel.offset_bottom = size.y/2
	panel.visible = false
	return panel

func _build_ui() -> void:
	top_label = CoreUI.label(hud,"",22)
	top_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_label.offset_left = -270
	top_label.offset_right = 270
	top_label.offset_top = 20
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label = CoreUI.label(hud,"",17)
	action_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_label.offset_left = -250
	action_label.offset_right = 250
	action_label.offset_top = -75
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_panel = _panel(Vector2(500,310))
	var waiting := VBoxContainer.new()
	waiting.add_theme_constant_override("separation",14)
	waiting_panel.add_child(waiting)
	waiting_label = CoreUI.label(waiting,"阵亡等待",25)
	vehicle_choice = OptionButton.new()
	vehicle_choice.add_item("M4A3 工程样车 · AP120 · 30发")
	waiting.add_child(vehicle_choice)
	CoreUI.label(waiting,"8秒准备后选择再出击；堵塞时等待安全出生点。\nTab 可切换观察友军，不会接管友军车辆。",16)
	respawn_button = CoreUI.button(waiting,"再出击",request_respawn)
	CoreUI.button(waiting,"返回车库",leave_match)
	result_panel = _panel(Vector2(580,350))
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation",16)
	result_panel.add_child(result_box)
	result_text = CoreUI.label(result_box,"",22)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.custom_minimum_size.x = 540
	result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",16)
	result_box.add_child(buttons)
	restart_button = CoreUI.button(buttons,"再来一局",func() -> void: restart_requested.emit())
	return_button = CoreUI.button(buttons,"返回车库",leave_match)
	var abandon := CoreUI.button(hud._training_btn.get_parent(),"放弃当前车（扣30票）",abandon_vehicle)
	abandon.tooltip_text = "按一次阵亡处理，8秒后可再出击。"
	hud.resume_btn.text = "继续"
	for control in hud.resume_btn.get_parent().get_children():
		if control is Label: control.text = "已暂停"
		if control is Button and control.text == "Vehicle Inspector": control.visible = false
	CoreUI.apply(hud)

func _reset_range() -> void: pass

func _unhandled_input(event: InputEvent) -> void:
	if not team_ready: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R,KEY_X,KEY_1,KEY_2,KEY_3]:
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			if actor.state.destroyed: spectator_index += 1
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and director.state.phase == "finished": leave_match(); return
	if event.is_action_pressed("pause"):
		if _paused: _resume()
		else: _pause()

func _pause() -> void:
	if director != null and director.state.phase == "finished": return
	super._pause()
	for vehicle in combat_actors(): vehicle.pause_block(true)
func _resume() -> void:
	super._resume()
	for vehicle in combat_actors():
		vehicle.pause_block(false)
		vehicle.gunner.resume_grace = GameConfig.RESUME_GRACE
	if actor.state.destroyed and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	super._process(delta)
	if not team_ready: return
	var state := director.state
	var owner_text: String = {0:"中立",1:"友方占领",2:"敌方占领"}[state.capture_owner]
	top_label.text = "友方 %d  ◆  敌方 %d\n据点A：%s · %.0f%%  %s"%[state.tickets[1],state.tickets[2],owner_text,absf(state.capture_progress)*100,"争夺中" if state.contested else ""]
	if state.phase == "countdown": top_label.text += "\n%d秒后交战"%ceili(state.countdown)
	hud.control_label.text = "4 对 4 占点"
	hud.hint_label.text = "W/S A/D 驾驶  鼠标瞄准  左键开火\nT 维修  F 灭火  C 替补\n进入半径12米据点争夺 · Esc 菜单"
	hud.ammo_label.text = "弹药：%d"%actor.gunner.rounds_remaining
	hud.projectiles_label.text = "在飞弹丸：%d"%projectiles.active_count()
	hud.gunline_label.text = "友车会挡住炮弹，友军伤害关闭"
	action_label.text = ""
	if state.is_protected(actor.entity_id,actor.life_id): action_label.text = "出生保护 %.1f 秒 · 驾驶 / 开火取消"%state.roster.A.protection_left
	elif not actor.state.fires.is_empty(): action_label.text = "起火！F 灭火 · 剩余%d次"%actor.state.extinguisher_charges
	elif not actor.capabilities().drive: action_label.text = "动力失能 · T 维修 / C 替补"
	elif not actor.capabilities().fire: action_label.text = "火炮失能 · T 维修 / C 替补"
	if not actor.state.recovery_action.is_empty(): action_label.text += "\n%s %.1f秒"%[CoreUI.word(actor.state.recovery_action),actor.state.action_progress]
	capture_material.albedo_color = {0:Color("c8c8a0"),1:Color("57b9e5"),2:Color("e79c68")}[state.capture_owner]
	for life in shield_visuals.keys():
		var entry: Dictionary = shield_visuals[life]
		var vehicle: VehicleActor = entry.actor.get_ref()
		if vehicle == null or not is_instance_valid(entry.mesh): shield_visuals.erase(life); continue
		entry.mesh.visible = not vehicle.state.destroyed and state.is_protected(vehicle.entity_id,vehicle.life_id)
	if actor.state.destroyed and state.phase == "playing":
		var row: Dictionary = state.roster.A
		var left := maxf(0,row.respawn_at-state.elapsed)
		waiting_label.text = "阵亡 · %.1f秒后可再出击"%left if left>0 else ("出生点堵塞，等待安全位置" if row.waiting_reason == "spawn_blocked" else "准备再出击")
		respawn_button.disabled = left>0 or state.tickets[1]<=0
		var friends: Array = []
		for id in state.roster:
			var friend := state.actor_for(id)
			if friend != null and friend.state.team_id == 1 and not friend.state.destroyed: friends.append(friend)
		if not friends.is_empty():
			var observed: VehicleActor = friends[spectator_index%friends.size()]
			spectator.global_position = observed.tank.global_position+Vector3(0,7,12)
			spectator.look_at(observed.tank.global_position+Vector3.UP)
