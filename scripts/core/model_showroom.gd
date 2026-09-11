class_name ModelShowroom
extends PanelContainer
## Art-only catalog: these assets do not imply completed combat definitions.
const MODELS := [
	["Leopard 2A7V · 10,000 tris", "res://assets/vehicles/leopard2a7v/leopard2a7v.glb"],
	["M1A1 HC · 3,896 tris", "res://assets/vehicles/m1a1/m1a1.glb"],
	["ZTZ-99A · 3,996 tris", "res://assets/vehicles/ztz99a/ztz99a_4000.glb"],
]
var viewport: SubViewport
var pivot: Node3D
var camera: Camera3D
var model: Node3D
var choice: OptionButton
var status: Label
var radius := 8.0
var yaw := 0.65
var pitch := 0.32
var zoom := 1.0

func _ready() -> void:
	name = "ModelShowroom"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CoreUI.theme()
	var background := StyleBoxFlat.new()
	background.bg_color = Color("17252d")
	background.set_content_margin_all(16)
	add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	CoreUI.label(bar, "模型展厅 / Model showroom", 25)
	choice = OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(choice)
	for entry in MODELS: choice.add_item(entry[0])
	choice.item_selected.connect(select_model)
	CoreUI.button(bar, "返回车库 / Back", queue_free)
	CoreUI.label(column, "美术预览 · 战斗车型待接入 / Art preview · combat integration pending", 16)
	var views := HBoxContainer.new()
	column.add_child(views)
	CoreUI.button(views, "旋转 ←", func() -> void: yaw -= 0.4; _update_camera())
	CoreUI.button(views, "旋转 →", func() -> void: yaw += 0.4; _update_camera())
	CoreUI.button(views, "侧视", func() -> void: yaw = PI / 2; pitch = 0.0; _update_camera())
	CoreUI.button(views, "俯视", func() -> void: pitch = 1.5; _update_camera())
	CoreUI.button(views, "复位", func() -> void: yaw = 0.65; pitch = 0.32; zoom = 1.0; _update_camera())
	CoreUI.button(views, "放大 +", func() -> void: zoom = maxf(0.6, zoom - 0.1); _update_camera())
	CoreUI.button(views, "缩小 −", func() -> void: zoom = minf(2.0, zoom + 0.1); _update_camera())
	var container := SubViewportContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.stretch = true
	column.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	pivot = Node3D.new()
	viewport.add_child(pivot)
	camera = Camera3D.new()
	camera.fov = 40
	camera.current = true
	viewport.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("26343f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	viewport.add_child(light)
	status = CoreUI.label(column, "", 15)
	viewport.size_changed.connect(_update_camera)
	select_model(0)

func select_model(index: int) -> void:
	if index < 0 or index >= MODELS.size(): return
	if is_instance_valid(model):
		pivot.remove_child(model)
		model.queue_free()
	var scene := load(MODELS[index][1]) as PackedScene
	if scene == null:
		status.text = "模型载入失败 / Model could not be loaded"
		return
	model = scene.instantiate() as Node3D
	pivot.add_child(model)
	var bounds := AABB()
	var initialized := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(box) if initialized else box
		initialized = true
	model.position -= bounds.get_center()
	radius = maxf(bounds.size.length() * 0.5, 0.5)
	yaw = 0.65
	pitch = 0.32
	zoom = 1.0
	status.text = "%s · %.2f × %.2f × %.2f m" % [MODELS[index][0], bounds.size.x, bounds.size.y, bounds.size.z]
	_update_camera()

func _update_camera() -> void:
	# Fit the bounding sphere for either portrait or landscape viewport sizes.
	var aspect := float(maxi(viewport.size.x, 1)) / float(maxi(viewport.size.y, 1))
	var half_fov := minf(deg_to_rad(camera.fov * 0.5), atan(tan(deg_to_rad(camera.fov * 0.5)) * aspect))
	var distance := radius / sin(half_fov) * 1.08 * zoom
	camera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(Vector3.ZERO)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
