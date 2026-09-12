class_name RiverJunctionSurvey
extends PanelContainer
## Garage-accessible environmental design review. No match roster, rewards or save mutation.
signal map_ready
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var atlas: RiverJunctionAtlas
var mode: OptionButton
var note: Label
var location_label: Label
var objective_buttons: Array[Button]=[]
var ready_map := false
var focused := true
var team_size := 16
var world_builder: RiverJunctionWorld

func _ready() -> void:
	name="RiverJunctionSurvey"; theme=GarageTheme.theme(); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",GarageTheme.box(Color("10191c"),Color("34423f"),18))
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",12); add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	var brand := GarageTheme.text(header,"河谷枢纽  /  RIVER JUNCTION",25); brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	CoreUI.button(header,"返回车库   ×",queue_free)
	var body := HBoxContainer.new(); body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",18); column.add_child(body)
	var sidebar := VBoxContainer.new(); sidebar.custom_minimum_size.x=260; body.add_child(sidebar)
	GarageTheme.text(sidebar,"战场勘察   /   DESIGN PREVIEW",12,GarageTheme.ACCENT)
	mode=OptionButton.new(); mode.add_item("16v16  ·  三占点",16); mode.add_item("10v10  ·  三占点",10); sidebar.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void: set_layout(mode.get_item_id(index)))
	atlas=RiverJunctionAtlas.new(); sidebar.add_child(atlas); atlas.point_selected.connect(focus_point)
	note=GarageTheme.text(sidebar,"",14,GarageTheme.MUTED); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.x=240
	CoreUI.button(sidebar,"全图鸟瞰",overview)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; sidebar.add_child(scroll)
	var targets := VBoxContainer.new(); targets.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(targets)
	for id in RiverJunctionDefinition.OBJECTIVES:
		var row: Dictionary=RiverJunctionDefinition.OBJECTIVES[id]
		var button := CoreUI.button(targets,id+"   "+row.title,func() -> void: focus_objective(id)); button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.tooltip_text=row.role; button.set_meta("objective_id",id); objective_buttons.append(button)
	GarageTheme.text(targets,"战术地标 · 无占领计分",12,GarageTheme.MUTED)
	for id in RiverJunctionDefinition.LANDMARKS:
		var row: Dictionary=RiverJunctionDefinition.LANDMARKS[id]
		var button := CoreUI.button(targets,row.title,func() -> void:
			focus_point(row.xz); location_label.text=row.title+"  ·  "+row.role)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	CoreUI.button(sidebar,"镇内视角",street_view)
	var hero := VBoxContainer.new(); hero.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(hero)
	location_label=GarageTheme.text(hero,"正在构建河谷地形与环境…",15,GarageTheme.ACCENT)
	var container := SubViewportContainer.new(); container.stretch=true; container.size_flags_horizontal=Control.SIZE_EXPAND_FILL; container.size_flags_vertical=Control.SIZE_EXPAND_FILL; container.custom_minimum_size=Vector2(200,200); hero.add_child(container)
	viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.handle_input_locally=false; viewport.msaa_3d=Viewport.MSAA_2X; container.add_child(viewport)
	container.gui_input.connect(_view_input)
	stage=Node3D.new(); viewport.add_child(stage)
	camera=Camera3D.new(); camera.far=4200; camera.near=.3; camera.fov=60; stage.add_child(camera)
	GarageTheme.text(column,"按住右键观察 / WASD 移动 / Q E 升降 / Shift 加速 · 点击地图或据点快速定位",13,GarageTheme.MUTED)
	GarageTheme.text(column,"环境与布局预览 · 20 / 32 人对局尚未接入",12,GarageTheme.MUTED)
	ModalNavigation.attach(self,queue_free)
	await get_tree().process_frame
	if is_queued_for_deletion(): return
	world_builder=RiverJunctionWorld.new(); world_builder.build(stage)
	ready_map=true; set_layout(16); overview(); map_ready.emit()

func set_layout(value: int) -> void:
	if value not in [10,16]: return
	team_size=value; mode.select(0 if value==16 else 1); atlas.team_size=value; atlas.queue_redraw()
	var config := RiverJunctionDefinition.layout(value)
	note.text=("2.08 × 1.60 km · 5 处河道通路" if value==16 else "1.48 × 1.20 km · 3 处河道通路")+"\n城镇 / 工业 / 丘陵三条主战线"
	for button in objective_buttons: button.visible=button.get_meta("objective_id") in config.objectives

func overview() -> void:
	if not ready_map: return
	camera.near=4.0
	camera.position=Vector3(150,1730,1210); camera.look_at(Vector3(0,0,0)); location_label.text="全图鸟瞰  ·  河谷地形 2.4 × 2.0 km"

func focus_point(p: Vector2) -> void:
	if not ready_map: return
	camera.near=1.0
	p=p.clamp(Vector2(-1080,-880),Vector2(1080,880))
	var target := RiverJunctionDefinition.point(p)
	camera.position=target+Vector3(130,155,190); camera.look_at(target); location_label.text="自由勘察  ·  %d / %d m"%[p.x,p.y]

func focus_objective(id: String) -> void:
	focus_point(RiverJunctionDefinition.OBJECTIVES[id].xz)
	location_label.text=id+"  /  "+RiverJunctionDefinition.OBJECTIVES[id].title+"  ·  "+RiverJunctionDefinition.OBJECTIVES[id].role

func street_view() -> void:
	if not ready_map: return
	camera.near=.3
	camera.position=Vector3(530,11.5,190); camera.look_at(Vector3(516,11,70)); location_label.text="河畔镇  ·  街道尺度与环境样板"

func _view_input(event: InputEvent) -> void:
	if not ready_map: return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
		camera.rotation.y-=event.relative.x*.003; camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.003,-1.5,1.5); camera.rotation.z=0
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not ready_map or not focused or not is_visible_in_tree(): return
	# Deliberate right-button fly control avoids moving while operating sidebar buttons.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var movement := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position+=(camera.basis*Vector3(movement.x,0,movement.z)+Vector3.UP*movement.y).normalized()*(160 if Input.is_physical_key_pressed(KEY_SHIFT) else 45)*delta
		camera.position.x=clampf(camera.position.x,-1190,1190); camera.position.z=clampf(camera.position.z,-990,990)
		camera.position.y=clampf(camera.position.y,RiverJunctionDefinition.height(camera.position.x,camera.position.z)+2,2200)
	atlas.camera_xz=Vector2(camera.position.x,camera.position.z); atlas.queue_redraw()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: focused=true
