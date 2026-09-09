class_name CoreRange
extends RecoveryRange
signal return_requested(result: Dictionary)
signal results_requested(result: Dictionary)
var loadout := {"vehicle_id":"test_vehicle","shell_id":"ap120","rounds":10,"infinite":false}
var lesson := 0
var director := TrainingDirector.new()
var _core_ready := false
var _plate_snapshot: Dictionary = {}
var _plate_root: Node3D

func _ready() -> void:
	super._ready()
	if not _initialized or not is_instance_valid(target_actor): return
	for vehicle in [source_actor,target_actor]:
		M4EngineeringProfile.apply(vehicle)
		vehicle.label3d.font = CoreUI.FONT
		vehicle.label3d.text = "本车" if vehicle == source_actor else "训练样车"
	for marker in _markers: marker.mesh.queue_free()
	_markers.clear()
	for vehicle in [source_actor,target_actor]: _build_markers(vehicle)
	CoreUI.apply(hud)
	hud.font_cjk = true
	hud.S = hud._strings(true)
	hud.resume_btn.text = "继续训练"
	hud._training_btn.text = "返回车库"
	hud.armor_training_button.visible = false
	hud.damage_training_button.visible = false
	hud.recovery_training_button.visible = false
	hud.replay_toggle_button.text = "自动回放：开"
	_aim_marker.font = CoreUI.FONT
	_aim_marker.text = "瞄准此处"
	replay.view.chinese = true
	xray = false
	_core_ready = true
	restart_lesson()
	projectiles.shot_record_ready.connect(func(record: Dictionary) -> void: director.accept_record(record,target_actor))
	var result_button := CoreUI.button(hud.resume_btn.get_parent(),"查看课目结果",func() -> void: results_requested.emit(director.finish()))
	result_button.name = "CoreResults"
	CoreUI.apply(result_button)

func restart_lesson() -> void:
	if not _core_ready: return
	if _paused: _resume()
	if actor != source_actor: switch_control()
	# A lesson retry explicitly creates a new round; no runtime damage is fabricated.
	reset_damage_round()
	_start_configured_round()

func _reset_range() -> void:
	if _core_ready: restart_lesson()
	else: super._reset_range()

func _start_configured_round() -> void:
	wrecks.clear_tracking()
	death_history.clear()
	for vehicle in [source_actor,target_actor]:
		var layout := M4EngineeringProfile.layout(lesson == 4 or lesson == 5)
		for patch in layout.armor_patches:
			if patch.id == "hull_front": patch.thickness_mm = 240.0
		vehicle.set_damage_layout(layout)
	TrainingLoadout.apply(source_actor,loadout)
	target_actor.gunner.rounds_remaining = 0 if lesson == 4 else 10
	target_actor.gunner.training_resupply = false
	var angle := PI if lesson == 0 else (PI/2 if lesson == 1 else 0.0)
	target_actor.tank.global_transform = Transform3D(Basis(Vector3.UP,angle),Vector3(0,0,-30))
	_plate_snapshot.clear()
	if is_instance_valid(_plate_root): _plate_root.free()
	_plate_root = Node3D.new()
	add_child(_plate_root)
	if lesson == 6:
		target_actor.tank.global_position = Vector3(14,0,-30)
		_plate_snapshot = ArmorTrainingTargets.training_case(4,_damage_round)
		for patch in (_plate_snapshot.layout as VehicleLayoutDefinition).armor_patches:
			var mesh := MeshInstance3D.new()
			mesh.mesh = ArmorPatchMesh.build_surface(patch.vertices_local_m,patch.triangles,patch.outward_normal_local)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("a58a49")
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = mat
			_plate_root.add_child(mesh)
	director.start(lesson,get_round_id(),source_actor,target_actor)
	controller.reset_pending()
	controller.require_fire_release()
	for vehicle in [source_actor,target_actor]: vehicle.gunner.resume_grace = GameConfig.RESUME_GRACE

func target_point() -> Vector3:
	if not _core_ready: return super.target_point()
	if lesson == 6: return Vector3(0,2.5,-30)
	var local := Vector3(0,1.30,1.45)
	match lesson:
		0: local = Vector3(0,1.45,-2.09)
		1: local = Vector3(0,1.30,1.45)
		3: local = M4EngineeringProfile.TURRET_ORIGIN+Vector3(0,0.33,-0.4)
		4: local = Vector3(0.72,1.05,0.55)
		5: local = Vector3(-1.2,0.5,2.5)
	return target_actor.tank.global_transform*local

func query_snapshots() -> Array:
	var out := super.query_snapshots()
	if not _plate_snapshot.is_empty(): out.append(_plate_snapshot)
	return out

func _process(delta: float) -> void:
	super._process(delta)
	if not _core_ready: return
	if not _paused: director.step(target_actor,source_actor,projectiles.active_count(),loadout.infinite)
	var state := target_actor.state
	var caps := target_actor.capabilities()
	hud.control_label.text = "课目 %d：%s  /  控制%s" % [lesson+1,TrainingDirector.TITLES[lesson],"本车" if actor == source_actor else "样车"]
	hud.ammo_label.text = "弹药 %d  ·  %s%s" % [actor.gunner.rounds_remaining,loadout.shell_id.to_upper(),"  无限训练补给" if actor.gunner.training_resupply else ""]
	hud.projectiles_label.text = "在飞弹丸 %d" % projectiles.active_count()
	hud.gunline_label.text = "炮线指示；弹丸会受重力影响"
	hud.result_label.text = {"running":"进行中","passed":"课目完成 · Enter 查看结果","failed":"课目未完成 · R 重试"}.get(director.status,"")
	hud.result_label.modulate = Color("ffd078") if director.status != "running" else Color.WHITE
	hud.hint_label.text = InputBindingService.driving_hint()+"\n"+InputBindingService.recovery_hint()+" · Tab 接管 · X 内构\n"+InputBindingService.hint("replay_toggle")+" 回放 · "+InputBindingService.hint("reset")+" 重试 · Enter 结果 · Esc 菜单"
	var lines: Array[String] = [TrainingDirector.TITLES[lesson],TrainingDirector.GOALS[lesson],"", "目标："+("阵亡" if state.destroyed else "存活"),
		"驾驶：%s  射击：%s" % ["可用" if caps.drive else "失能","可用" if caps.fire else "失能"],
		"发动机 %.0f%%  炮闩 %.0f%%" % [state.module_states.engine.integrity,state.module_states.breech.integrity],
		"左履带 %.0f%%  乘员 %d/5" % [state.module_states.track_left.integrity,state.alive_crew_count()],
		"弹架 %d / 膛内 %d / 装填途中 %d" % [target_actor.gunner.inventory.racks.get("ammo_rack",0),target_actor.gunner.inventory.chamber,target_actor.gunner.inventory.in_transfer]]
	if not actor.state.recovery_action.is_empty(): lines.append("%s：%.1f秒" % [CoreUI.word(actor.state.recovery_action),actor.state.action_progress])
	lines.append("\n"+("一炮解释" if not director.last_record.is_empty() else "操作提示"))
	lines.append(director.explanation)
	lines.append("\n训练设计参数；未认证历史性能")
	_status.text = "\n".join(lines)
	_status.add_theme_font_size_override("font_size",15)
	_aim_marker.visible = actor == source_actor and director.status == "running"
	_aim_marker.position = target_point()+Vector3(0,0.5,0)

func _unhandled_input(event: InputEvent) -> void:
	if _core_ready and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and not _paused:
			results_requested.emit(director.finish())
			get_viewport().set_input_as_handled()
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_7: return # Fixed lesson chosen in garage.
	super._unhandled_input(event)

func _return_to_range() -> void:
	if _core_ready: return_requested.emit(director.finish())

func _build_world() -> void:
	var floor_body := _add_wall(Vector3(0,-0.3,-35),Vector3(110,0.6,140))
	floor_body.get_child(1).mesh.material.albedo_color = Color("55644d")
	var backstop := _add_wall(Vector3(0,4,-58),Vector3(70,8,1))
	backstop.get_child(1).mesh.material.albedo_color = Color("606957")
	for i in range(-6,7):
		CoreVehicleVisual.box(self,Vector3(i*4,0.015,-12),Vector3(0.08,0.025,80),Color("929c76"))
	for distance in [10,20,30,40]:
		CoreVehicleVisual.box(self,Vector3(0,0.025,-distance),Vector3(10,0.035,0.12),Color("cec8a1"))
		var sign := Label3D.new()
		sign.font = CoreUI.FONT
		sign.text = "%d米" % distance
		sign.position = Vector3(-6,1,-distance)
		sign.font_size = 48
		add_child(sign)
	for side in [-1,1]:
		for i in 6:
			var wall := _add_wall(Vector3(side*18,0.6,-i*7),Vector3(3,1.2,2))
			wall.get_child(1).mesh.material.albedo_color = Color("526151")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("94afae")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8c0aa")
	environment.environment.ambient_light_energy = 0.45
	add_child(environment)
