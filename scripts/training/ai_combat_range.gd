class_name AICombatRange
extends DamageRange
static var WORDS := {"patrol":LocalizationService.text("ui_8c30c509dc7b"),"observe":LocalizationService.text("ui_616ee39dc4dd"),"engage":LocalizationService.text("ui_6e6bc0e3272e"),"search":LocalizationService.text("ui_ff84f259db5d"),"repair":LocalizationService.text("ui_df0b91c4a516"),"retreat":LocalizationService.text("ui_f2adfafb5b50"),"destroyed":LocalizationService.text("ui_122fcc1852a6")}
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
	hud.replay_toggle_button.text = LocalizationService.text("ui_b75283bf7268")
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
	if combat_ready and event.is_pressed() and not event.is_echo() and not _paused:
		var selected := InputBindingService.scenario_index(event,3)
		if selected >= 0:
			level = ["easy","normal","hard"][selected]
			restart_combat()
			return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if not combat_ready: return
	source_actor.label3d.text = LocalizationService.text("ui_991e63fe2920")
	target_actor.label3d.text = LocalizationService.text("ui_d48f1dcf88d2")
	hud.control_label.text = LocalizationService.text("ui_ff13698c8992")
	hud.hint_label.text = LocalizationService.text("ui_d88afc32f07e")
	hud.gunline_label.text = LocalizationService.text("ui_5d4496dad887")
	_status.text = LocalizationService.text("ui_dbef75e98109") % [{"easy":LocalizationService.text("ui_01805727314e"),"normal":LocalizationService.text("ui_de907d10df98"),"hard":LocalizationService.text("ui_4ea02714a1e9")}[level],WORDS.get(ai.phase,ai.phase),LocalizationService.text("ui_b5141d3d19e9") if ai.observation.get("visible",false) else LocalizationService.text("ui_0c70665b6eb6"),ai.difficulty.reaction,target_actor.gunner.shots_fired-round_shots_start,target_actor.gunner.rounds_remaining]

func input_context() -> String: return "ai_combat"
