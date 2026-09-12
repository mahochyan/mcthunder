class_name RiverJunctionRange
extends BallisticsRange
## Real production tank, input, optics, projectile and pause paths on the large-map environment.
var world_builder: RiverJunctionWorld
var stop_index := 4
var deployment_choice: OptionButton
var area_choice: OptionButton
var trial_team_size := 16
var map_atlas: RiverJunctionAtlas
var ready_drive := false
var boundary_warning := ""
var boundary_seconds := 0.0
var capture_director: TeamMatchDirector
var objective_hud: RiverObjectiveHUD
var objective_materials: Dictionary = {}
var restart_capture_button: Button

func _build_world() -> void:
	world_builder=RiverJunctionWorld.new(); world_builder.build(self)

func _ready() -> void:
	InputBindingService.initialize()
	super._ready()
	if not _initialized: return
	if selected_vehicle_id not in VehicleCatalog.IDS: M4EngineeringProfile.apply(actor)
	CoreUI.apply(hud); hud.font_cjk=true; hud.S=hud._strings(true)
	# The inherited inspector action has no package-aware handler in this training scene.
	for action in hud.resume_btn.get_parent().get_children():
		if action is Button and action.text==LocalizationService.text("ui_48fbf5cf003e"): action.hide()
	replay.view.chinese=true
	actor.cam_rig.cam.far=3600
	actor.cam_rig.cam.near=.25
	ready_drive=true
	area_choice=OptionButton.new(); area_choice.add_item("16v16 布局 · 单车驾驶",16); area_choice.add_item("10v10 布局 · 单车驾驶",10)
	hud.resume_btn.get_parent().add_child(area_choice); hud.resume_btn.get_parent().move_child(area_choice,1)
	area_choice.item_selected.connect(func(index: int) -> void: set_trial_size(area_choice.get_item_id(index)))
	deployment_choice=OptionButton.new(); deployment_choice.name="RiverDrivingStop"
	for stop in RiverJunctionDefinition.driving_stops(): deployment_choice.add_item(stop.title)
	hud.resume_btn.get_parent().add_child(deployment_choice)
	hud.resume_btn.get_parent().move_child(deployment_choice,1)
	deployment_choice.item_selected.connect(select_stop)
	map_atlas=RiverJunctionAtlas.new(); hud.add_child(map_atlas)
	map_atlas.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_atlas.offset_left=-270; map_atlas.offset_right=-20; map_atlas.offset_top=80; map_atlas.offset_bottom=290; map_atlas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	select_stop(stop_index)
	capture_director=TeamMatchDirector.new(); add_child(capture_director)
	actor.command_observer=Callable(capture_director,"observe_command")
	objective_hud=RiverObjectiveHUD.new(); hud.add_child(objective_hud)
	restart_capture_button=Button.new(); restart_capture_button.text="重开占点演练"
	hud.resume_btn.get_parent().add_child(restart_capture_button)
	restart_capture_button.pressed.connect(restart_capture)
	_build_objective_rings()
	restart_capture()

func restart_capture() -> void:
	if capture_director==null: return
	# Single-car training uses the production match rules without claiming a populated team battle.
	capture_director.begin(1,RiverJunctionDefinition.capture_definitions())
	capture_director.state.register_spawn("A",actor)

func _build_objective_rings() -> void:
	for row in RiverJunctionDefinition.capture_definitions():
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 128:
			var corners: Array[Vector3] = []
			for pair in [[i,row.radius-.65],[i+1,row.radius-.65],[i+1,row.radius+.65],[i,row.radius+.65]]:
				var angle: float=float(pair[0])*TAU/128
				var p := Vector2(row.center.x,row.center.z)+Vector2(cos(angle),sin(angle))*float(pair[1])
				corners.append(RiverJunctionDefinition.point(p,.20))
			for index in [0,1,2,0,2,3]: st.add_vertex(corners[index])
		st.generate_normals()
		var mesh := MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.name="CaptureZone_"+row.id
		var mat := StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.albedo_color=RiverObjectiveHUD.COLORS[0]; mesh.material_override=mat; add_child(mesh)
		objective_materials[row.id]=mat

func set_trial_size(value: int) -> void:
	if not ready_drive or value not in [10,16]: return
	trial_team_size=value; area_choice.select(0 if value==16 else 1)
	deployment_choice.clear()
	for stop in RiverJunctionDefinition.driving_stops(value): deployment_choice.add_item(stop.title)
	map_atlas.team_size=value
	select_stop(2+RiverJunctionDefinition.layout(value).crossings.find(0.0))
	restart_capture()

func select_stop(index: int) -> void:
	if not ready_drive or index<0 or index>=RiverJunctionDefinition.driving_stops(trial_team_size).size(): return
	stop_index=index
	var stop: Dictionary=RiverJunctionDefinition.driving_stops(trial_team_size)[index]
	var pose := Transform3D(Basis(Vector3.UP,float(stop.get("yaw",0))),RiverJunctionDefinition.point(stop.xz,.15))
	# Tank spawn is local to its Actor; actor remains at the origin in this scene.
	actor.tank.set_spawn(actor.global_transform.affine_inverse()*pose)
	super._reset_range()
	controller.reset_pending(); controller.require_fire_release()
	actor.pause_block(_paused)
	deployment_choice.select(index); boundary_seconds=0; boundary_warning=""
	if capture_director!=null: capture_director.state.register_spawn("A",actor)

func _reset_range() -> void:
	if ready_drive: select_stop(stop_index)
	else: super._reset_range()

func _unhandled_input(event: InputEvent) -> void:
	if ready_drive and not _paused and event.is_action_pressed("toggle_target"):
		select_stop((stop_index+1)%deployment_choice.item_count); get_viewport().set_input_as_handled(); return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if not ready_drive: return
	var p := actor.tank.global_position
	map_atlas.camera_xz=Vector2(p.x,p.z); map_atlas.queue_redraw(); map_atlas.visible=not _paused and not actor.cam_rig.sight
	hud.control_label.text="河谷枢纽 · 单车实地驾驶（%dv%d布局）/ "%[trial_team_size,trial_team_size]+deployment_choice.get_item_text(stop_index)
	hud.hint_label.text="正常驾驶 / 瞄准 / 射击 · 暂停菜单可选择部署位置 · 重置返回当前部署点"
	hud.projectiles_label.text="%.0f / %.0f m   坡度 %.1f°   %s"%[p.x,p.z,float(actor.tank.ground_state.get("slope_deg",0)),boundary_warning]
	if capture_director!=null:
		var state := capture_director.state
		objective_hud.rows=state.objectives.snapshot()
		for row in objective_hud.rows:
			map_atlas.objective_states[row.id]=row
			objective_materials[row.id].albedo_color=RiverObjectiveHUD.COLORS[row.owner]
		objective_hud.status="占点演练 · 友军 %d : %d 敌军 · 12 秒占领 / 每点每秒扣 1 票"%[state.tickets[1],state.tickets[2]]
		if state.phase=="countdown": objective_hud.status="占点演练 · %.0f 秒后开始 · 驶入 A / B / C 区域"%ceilf(state.countdown)
		elif state.phase=="finished": objective_hud.status="演练结束 · %s · 暂停菜单可重开（无对局奖励）"%{"victory":"胜利","defeat":"失败","draw":"平局"}.get(state.result.outcome,"")
		objective_hud.visible=not _paused and not actor.cam_rig.sight
		objective_hud.queue_redraw()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not ready_drive or _paused: return
	var p := actor.tank.global_position
	var bounds: Rect2=RiverJunctionDefinition.layout(trial_team_size).bounds
	if not bounds.has_point(Vector2(p.x,p.z)) or p.y < -1.8:
		boundary_seconds+=delta
		boundary_warning="驶出驾驶区 / 深水：%.0f 秒后返回部署点"%maxf(0,5-boundary_seconds)
		if boundary_seconds>=5: select_stop(stop_index)
	else: boundary_seconds=0; boundary_warning=""
