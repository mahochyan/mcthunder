class_name TerrainRange
extends DamageRange
var route := 0
var ready_drive := false
static var ROUTES := [LocalizationService.text("ui_2797bce80aa3"),LocalizationService.text("ui_36bc82c5536b"),LocalizationService.text("ui_388eb11a6e6b"),LocalizationService.text("ui_dcd3c1f82e00")]
const X := [0.0,18.0,36.0,-18.0]

func _ready() -> void:
	super._ready()
	if not _initialized: return
	for vehicle in [source_actor,target_actor]:
		M4EngineeringProfile.apply(vehicle)
		vehicle.label3d.font = CoreUI.FONT
	for marker in _markers: marker.mesh.queue_free()
	_markers.clear()
	for vehicle in [source_actor,target_actor]: _build_markers(vehicle)
	xray = false
	CoreUI.apply(hud)
	hud.font_cjk = true
	hud.S = hud._strings(true)
	hud.resume_btn.text = LocalizationService.text("ui_4c77abeabd14")
	replay.view.chinese = true
	ready_drive = true
	select_route(0)

func select_route(index: int) -> void:
	if not ready_drive or index < 0 or index >= X.size() or _paused: return
	if actor != source_actor: switch_control()
	reset_damage_round()
	route = index
	source_actor.tank.global_transform = Transform3D(Basis.IDENTITY,Vector3(X[index],0.05,4))
	target_actor.tank.global_transform = Transform3D(VehiclePose.compose(Vector3.FORWARD,Vector3(0,cos(deg_to_rad(20)),sin(deg_to_rad(20)))),Vector3(18,tan(deg_to_rad(20))*8+0.05,-20))
	controller.reset_pending()
	controller.require_fire_release()

func _reset_range() -> void:
	if ready_drive: select_route(route)
	else: super._reset_range()

func _build_world() -> void:
	# A real lowered floor at the western pit; no invisible flat collider across it.
	TerrainFixtures.box(self,Vector3(19,-0.5,-10),Vector3(82,1,110))
	TerrainFixtures.box(self,Vector3(-36,-0.5,-10),Vector3(8,1,110))
	TerrainFixtures.box(self,Vector3(-27,-0.5,-40.5),Vector3(10,1,49))
	TerrainFixtures.box(self,Vector3(-27,-0.5,20.5),Vector3(10,1,49))
	TerrainFixtures.box(self,Vector3(-27,-1.5,-10),Vector3(10,1,12))
	for position in [Vector3(10,1.5,-65),Vector3(10,1.5,45)]: TerrainFixtures.box(self,position,Vector3(100,3,1))
	for position in [Vector3(-40,1.5,-10),Vector3(60,1.5,-10)]: TerrainFixtures.box(self,position,Vector3(1,3,110))
	for i in 3:
		TerrainFixtures.ramp(self,Vector3(X[i],0,-12),[10.0,20.0,30.0][i])
		var sign := Label3D.new()
		sign.font = CoreUI.FONT
		sign.text = ROUTES[i]
		sign.position = Vector3(X[i]-4.5,1.5,-10)
		sign.font_size = 46
		add_child(sign)
	TerrainFixtures.box(self,Vector3(-18,0.15,-8),Vector3(7,0.3,2))
	for x in [-20.1,-15.9]: TerrainFixtures.box(self,Vector3(x,1,-17),Vector3(0.6,2,5))
	TerrainFixtures.box(self,Vector3(-18,1.8,-26),Vector3(9,3.6,1))
	TerrainFixtures.box(self,Vector3(-22,1.8,-30),Vector3(1,3.6,9))
	for x in [-30,-24]: TerrainFixtures.box(self,Vector3(x,0.8,-10),Vector3(3,1.6,9))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-25,0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a0b6b3")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("bdc4b0")
	env.environment.ambient_light_energy = 0.65
	add_child(env)

func _process(delta: float) -> void:
	super._process(delta)
	if not ready_drive: return
	var tank := actor.tank
	hud.control_label.text = LocalizationService.text("ui_e883fef43723")+ROUTES[route]+LocalizationService.text("ui_f6000d203b92")+actor.entity_id
	hud.ammo_label.text = LocalizationService.text("ui_913b00faa6c4") % actor.gunner.rounds_remaining
	hud.projectiles_label.text = LocalizationService.text("ui_4cce74d3cbde") % projectiles.active_count()
	hud.gunline_label.text = LocalizationService.text("ui_6df57dbc0ce9")
	hud.hint_label.text = LocalizationService.text("ui_d9a919d932da")
	_status.text = LocalizationService.text("ui_a9dfb7bad808") % [tank.forward_speed,tank.ground_state.slope_deg,tank.defs.max_slope_deg,tank.ground_state.get("support_count",0),LocalizationService.text("ui_5341325f241c") if tank.slope_blocked else LocalizationService.text("ui_ce7ef28b670a"),rad_to_deg(tank.global_rotation.x),rad_to_deg(tank.global_rotation.z),target_actor.state.module_states.engine.integrity,LocalizationService.text("ui_4d99c976beb8") if target_actor.capabilities().drive else LocalizationService.text("ui_ab5d487757fb")]

func _unhandled_input(event: InputEvent) -> void:
	var selected := InputBindingService.scenario_index(event,4)
	if ready_drive and not _paused and selected >= 0:
		select_route(selected)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func input_context() -> String: return "terrain"
