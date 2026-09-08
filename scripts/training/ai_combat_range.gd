class_name AICombatRange
extends DamageRange
const WORDS := {"patrol":"巡逻","observe":"观察 / 反应中","engage":"交战","search":"搜索最后位置","repair":"停车恢复","retreat":"撤退","destroyed":"已失能"}
var ai := AITankController.new()
var nav := DriveNavigator.new()
var combat_ready := false
var level := "normal"
var round_shots_start := 0

func _ready() -> void:
	super._ready()
	if not _initialized: return
	nav.load_graph("res://configs/navigation/ai_training_graph.json")
	for vehicle in [source_actor,target_actor]:
		M4EngineeringProfile.apply(vehicle)
		vehicle.state.recovery_enabled = true
		vehicle.label3d.font = CoreUI.FONT
	for marker in _markers: marker.mesh.queue_free()
	_markers.clear()
	xray = false
	add_child(ai)
	ai.configure(target_actor,nav,Callable(self,"combat_actors"),level,1401)
	round_shots_start = target_actor.gunner.shots_fired
	target_actor.set_controller(ai)
	CoreUI.apply(hud)
	hud.font_cjk = true
	hud.S = hud._strings(true)
	replay.view.chinese = true
	replay.auto_replay = false
	hud.replay_toggle_button.text = "自动回放：关"
	combat_ready = true
	restart_combat()

func combat_actors() -> Array: return [source_actor,target_actor]

func restart_combat() -> void:
	reset_damage_round()
	round_shots_start = target_actor.gunner.shots_fired
	source_actor.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,0.03,6))
	target_actor.tank.global_transform = Transform3D(Basis(Vector3.UP,PI),Vector3(0,0.03,-42))
	for vehicle in combat_actors(): vehicle.state.recovery_enabled = true
	ai.configure(target_actor,nav,Callable(self,"combat_actors"),level,1401)
	target_actor.turret.set_aim_point(source_actor.tank.global_position+Vector3.UP*1.3)
	target_actor.turret.snap_to_aim()
	ai.set_patrol(Vector3(0,0,-42),Vector3(0,0,-42))
	source_actor.set_controller(controller)
	source_actor.cam_rig.cam.current = true

func switch_control() -> void: pass # Lab always keeps the player's own vehicle.
func _reset_range() -> void:
	if combat_ready: restart_combat()
	else: super._reset_range()
func _build_world() -> void:
	TerrainFixtures.box(self,Vector3(0,-0.5,-18),Vector3(72,1,88))
	TerrainFixtures.box(self,Vector3(0,1.8,-12),Vector3(8,3.6,3),Color("776c56"))
	for side in [-1,1]: TerrainFixtures.box(self,Vector3(side*36,2,-18),Vector3(1,4,88))
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

func _unhandled_input(event: InputEvent) -> void:
	if combat_ready and event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			level = ["easy","normal","hard"][event.keycode-KEY_1]
			restart_combat()
			return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if not combat_ready: return
	source_actor.label3d.text = "玩家"
	target_actor.label3d.text = "电脑"
	hud.control_label.text = "电脑交战实验室"
	hud.hint_label.text = "W/S A/D 驾驶  鼠标瞄准  左键开火\n从墙侧探出，再退回观察电脑搜索\n1 简单  2 普通  3 困难  R 重开  Esc 菜单"
	hud.gunline_label.text = "双方使用相同的火炮、装甲与损伤规则"
	_status.text = "电脑观察辅助\n\n难度：%s\n状态：%s\n当前可见：%s\n反应时间：%.2f秒\n已开火：%d\n弹药：%d\n\n隐藏后只保留最后观测，\n不会更新墙后位置。\n\n这是实验室观察辅助，\n正式对战会隐藏电脑状态。" % [{"easy":"简单","normal":"普通","hard":"困难"}[level],WORDS.get(ai.phase,ai.phase),"是" if ai.observation.get("visible",false) else "否",ai.difficulty.reaction,target_actor.gunner.shots_fired-round_shots_start,target_actor.gunner.rounds_remaining]
