class_name AIDriveRange
extends DamageRange
const TITLES := ["直线停车","直角转弯","绕过箱区","窄道拒绝","阻挡与倒车脱困"]
const GOALS := [Vector3(0,0,-8),Vector3(12,0,-8),Vector3(0,0,-42),Vector3(24,0,-30),Vector3(0,0,-42)]
var driver: AIPathDriver
var navigator := DriveNavigator.new()
var trial := 2
var ai_ready := false
var overview: Camera3D
var watching := true
var show_path := true
var path_mesh: MeshInstance3D
var goal_marker: Node3D

func _ready() -> void:
	super._ready()
	if not _initialized: return
	var loaded := navigator.load_graph("res://configs/navigation/ai_training_graph.json")
	if not loaded.ok: push_error("AI graph unavailable: "+loaded.reason); return
	for vehicle in [source_actor,target_actor]:
		M4EngineeringProfile.apply(vehicle)
		vehicle.label3d.font = CoreUI.FONT
	for marker in _markers: marker.mesh.queue_free()
	_markers.clear()
	for vehicle in [source_actor,target_actor]: _build_markers(vehicle)
	xray = false
	driver = AIPathDriver.new()
	driver.name = "AIPathDriver"
	add_child(driver)
	driver.configure(target_actor,navigator)
	target_actor.set_controller(driver)
	driver.state_changed.connect(func(_event: Dictionary) -> void: _refresh_path.call_deferred())
	overview = Camera3D.new()
	overview.position = Vector3(34,32,20)
	overview.fov = 58
	add_child(overview)
	overview.look_at(Vector3(0,0,-17))
	path_mesh = MeshInstance3D.new()
	add_child(path_mesh)
	goal_marker = Node3D.new()
	add_child(goal_marker)
	for p in [Vector3(-2,0,0),Vector3(2,0,0)]: CoreVehicleVisual.box(goal_marker,p,Vector3(0.13,0.08,4),Color("dbbd65"))
	for p in [Vector3(0,0,-2),Vector3(0,0,2)]: CoreVehicleVisual.box(goal_marker,p,Vector3(4,0.08,0.13),Color("dbbd65"))
	CoreUI.apply(hud)
	hud.font_cjk = true
	hud.S = hud._strings(true)
	hud.resume_btn.text = "继续观察"
	replay.view.chinese = true
	ai_ready = true
	select_trial(trial)

func set_watching(value: bool) -> void:
	watching = value
	source_actor.set_controller(null if watching else controller)
	controller.reset_pending()
	controller.require_fire_release()
	overview.current = watching
	if not watching: source_actor.cam_rig.cam.current = true

func select_trial(index: int) -> void:
	if not ai_ready or index < 0 or index >= TITLES.size() or _paused: return
	driver.cancel("new_trial")
	reset_damage_round()
	trial = index
	source_actor.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.03,-1) if index == 4 else Vector3(-22,0.03,6))
	target_actor.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.03,6))
	driver.set_goal(GOALS[index])
	goal_marker.position = GOALS[index]+Vector3.UP*0.06
	set_watching(true)
	_refresh_path()

func _refresh_path() -> void:
	if not is_instance_valid(path_mesh) or driver == null: return
	var mesh := ImmediateMesh.new()
	if driver.path.size() > 1:
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i in range(1,driver.path.size()):
			mesh.surface_add_vertex(driver.path[i-1]+Vector3.UP*0.08)
			mesh.surface_add_vertex(driver.path[i]+Vector3.UP*0.08)
		mesh.surface_end()
	path_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("83ccbc")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mesh.material_override = mat
	path_mesh.visible = show_path

func _build_world() -> void:
	TerrainFixtures.box(self,Vector3(0,-0.5,-18),Vector3(72,1,88))
	TerrainFixtures.box(self,Vector3(0,1.8,-22),Vector3(9,3.6,9),Color("716d51"))
	for x in [22.7,25.3]: TerrainFixtures.box(self,Vector3(x,1.5,-24),Vector3(0.6,3,16),Color("79664c"))
	for p in [Vector3(0,1.5,-62),Vector3(0,1.5,26)]: TerrainFixtures.box(self,p,Vector3(72,3,1))
	for p in [Vector3(-36,1.5,-18),Vector3(36,1.5,-18)]: TerrainFixtures.box(self,p,Vector3(1,3,88))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-20,0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9dafac")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9c4b3")
	env.environment.ambient_light_energy = 0.7
	add_child(env)

func _reset_range() -> void:
	if ai_ready: select_trial(trial)
	else: super._reset_range()

func _unhandled_input(event: InputEvent) -> void:
	if ai_ready and event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			select_trial(event.keycode-KEY_1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB:
			set_watching(not watching)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_P:
			show_path = not show_path
			path_mesh.visible = show_path
			return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if not ai_ready: return
	source_actor.label3d.text = "玩家车"
	target_actor.label3d.text = "电脑车 / "+CoreUI.word(driver.phase)
	hud.control_label.text = "电脑驾驶 / "+TITLES[trial]
	hud.hint_label.text = "1–5 新开路线  Tab 观察 / 驾驶玩家车\nW/S A/D 可开到电脑车前面挡路\nP 路径辅助  X 内构  R 重试  Esc 返回车库"
	hud.ammo_label.text = "玩家弹药：%d" % source_actor.gunner.rounds_remaining
	hud.projectiles_label.text = "在飞弹丸：%d" % projectiles.active_count()
	hud.gunline_label.text = "电脑只生成驾驶命令，使用相同物理碰撞"
	_status.text = "电脑驾驶状态\n\n案例：%s\n阶段：%s\n原因：%s\n路点：%d / %d\n脱困尝试：%d / %d\n速度：%.2f m/s\n距目标：%.1f m\n\n电脑发动机：%.0f%%\n驾驶能力：%s\n\nTab切换玩家车；电脑控制不变。\nP为本实验室的只读路径辅助。\n\n窄道会明确拒绝，脱困有次数上限。" % [TITLES[trial],CoreUI.word(driver.phase),CoreUI.word(driver.reason),driver.waypoint+1,driver.path.size(),driver.attempts,GameConfig.AI_RECOVERY_ATTEMPTS,target_actor.tank.forward_speed,target_actor.tank.global_position.distance_to(driver.goal),target_actor.state.module_states.engine.integrity,"可用" if target_actor.capabilities().drive else "失能"]
