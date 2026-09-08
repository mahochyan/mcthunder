class_name ReplayView
extends PanelContainer
var chinese := false
## Pure presentation world: meshes, lights and camera only. Never runs combat logic.
const PLAY_SECONDS := 3.0
var record: Dictionary = {}
var events: Array[Dictionary] = []
var selected_event := -1
var playing := false
var current_time := 0.0
var current_position := Vector3.ZERO
var highlighted_items: Array[String] = []
var error_reason := ""
var viewport: SubViewport
var _world: Node3D
var _geometry: Node3D
var _camera: Camera3D
var _trail: MeshInstance3D
var _dot: MeshInstance3D
var _title: Label
var _details: Label
var _frame_index := -1
var _box_meshes: Array[Dictionary] = []
var _elapsed := 0.0
var _auto_close := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -356
	offset_right = -16
	offset_top = -308
	offset_bottom = -16
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size",16)
	column.add_child(_title)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(320,184)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,184)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	_world = Node3D.new()
	viewport.add_child(_world)
	_geometry = Node3D.new()
	_world.add_child(_geometry)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 6.0
	_camera.near = 0.01
	_camera.far = 400
	_world.add_child(_camera)
	_camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#10202b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 1.0
	_world.add_child(environment)
	_trail = MeshInstance3D.new()
	_world.add_child(_trail)
	_trail.material_override = _material(Color("#ffdc63"))
	_dot = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	_dot.mesh = sphere
	_dot.material_override = _material(Color("#fff19a"))
	_world.add_child(_dot)
	_details = Label.new()
	_details.custom_minimum_size.x = 320
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size",14)
	column.add_child(_details)
	visible = false

func present(source: Dictionary, auto_close: bool = true) -> Dictionary:
	var valid := ShotRecordBuilder.validate(source)
	if not valid.ok:
		show_error(str(valid.reason))
		return valid
	if not source.get("complete",false):
		show_error(str(source.get("unavailable_reason","incomplete_record")))
		return {"ok":false,"reason":error_reason}
	if source.frames.is_empty():
		show_error("no_target_geometry")
		return {"ok":false,"reason":error_reason}
	record = source.duplicate(true)
	events.clear()
	for event in record.contacts+record.damage: events.append(event.duplicate(true))
	events.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.flight_time_s != b.flight_time_s: return a.flight_time_s < b.flight_time_s
		return str(a.kind) < str(b.kind))
	error_reason = ""
	selected_event = -1
	playing = true
	_auto_close = auto_close
	_elapsed = 0.0
	current_time = 0.0
	_frame_index = -1
	visible = true
	_title.text = "SHOT #%d REPLAY · V CLOSE" % record.identity.shot_id
	seek(0)
	return {"ok":true}

func show_error(reason: String) -> void:
	clear_display()
	error_reason = reason
	visible = true
	_title.text = "REPLAY UNAVAILABLE · V CLOSE"
	_details.text = reason.replace("_"," ")

func clear_display() -> void:
	playing = false
	record.clear()
	events.clear()
	highlighted_items.clear()
	selected_event = -1
	_frame_index = -1
	if _geometry != null:
		for child in _geometry.get_children(): child.free()
	_box_meshes.clear()
	if _trail != null: _trail.mesh = null
	if _dot != null: _dot.visible = false
	visible = false

func close_view() -> void:
	playing = false
	visible = false

func _process(delta: float) -> void:
	if not visible or not playing or get_tree().paused or record.is_empty(): return
	_elapsed += delta
	var length := float(record.terminal.flight_time_s)
	seek(clampf(_elapsed/PLAY_SECONDS,0,1)*length)
	if _elapsed >= PLAY_SECONDS:
		playing = false
		if _auto_close: visible = false

func seek(time_s: float) -> void:
	if record.is_empty(): return
	current_time = clampf(time_s,0,float(record.terminal.flight_time_s))
	var frame_index := 0
	for i in record.frames.size():
		if float(record.frames[i].time_s) <= current_time+1e-7: frame_index = i
	if selected_event >= 0: frame_index = int(events[selected_event].geometry_frame)
	if frame_index != _frame_index: _build_frame(frame_index)
	current_position = sample_position(record.path,current_time)
	_dot.visible = true
	_dot.position = current_position
	_build_trail()
	_update_highlights()
	_update_details()

func select_event(index: int) -> bool:
	if events.is_empty(): return false
	selected_event = posmod(index,events.size())
	playing = false
	seek(float(events[selected_event].flight_time_s))
	return true

static func sample_position(path: Array, time_s: float) -> Vector3:
	if path.is_empty(): return Vector3.ZERO
	for i in range(1,path.size()):
		var a: Dictionary = path[i-1]
		var b: Dictionary = path[i]
		if float(b.time_s) >= time_s:
			var span := float(b.time_s)-float(a.time_s)
			var fraction := clampf((time_s-float(a.time_s))/span,0,1) if span>1e-9 else 1.0
			return (a.point_world as Vector3).lerp(b.point_world,fraction)
	return path.back().point_world

func _build_frame(index: int) -> void:
	for child in _geometry.get_children(): child.free()
	_box_meshes.clear()
	_frame_index = index
	var frame: Dictionary = record.frames[index]
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	for patch in frame.patches:
		var vertices := PackedVector3Array(patch.vertices_world)
		var triangles := PackedInt32Array(patch.triangles)
		for vertex in vertices:
			minimum = minimum.min(vertex)
			maximum = maximum.max(vertex)
		var surface := MeshInstance3D.new()
		surface.mesh = ArmorPatchMesh.build_surface(vertices,triangles,patch.normal_world)
		surface.material_override = _material(Color(0.38,0.65,0.77,0.10))
		_geometry.add_child(surface)
		var wire := MeshInstance3D.new()
		wire.mesh = ArmorPatchMesh.build_wire(vertices,triangles,patch.normal_world)
		wire.material_override = _material(Color(0.46,0.68,0.78,0.65))
		_geometry.add_child(wire)
	for box in frame.boxes:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = box.size_m
		mesh.mesh = shape
		mesh.transform = box.box_world_transform
		var mat := _material(Color(0.42,0.52,0.57,0.18))
		mesh.material_override = mat
		_geometry.add_child(mesh)
		_box_meshes.append({"id":box.id,"kind":box.kind,"mesh":mesh,"material":mat})
		var p: Vector3 = box.box_world_transform.origin
		minimum = minimum.min(p-box.size_m)
		maximum = maximum.max(p+box.size_m)
	if not minimum.is_finite():
		minimum = current_position-Vector3.ONE
		maximum = current_position+Vector3.ONE
	var center := (minimum+maximum)*0.5
	var extent := maxf((maximum-minimum).length(),2.0)
	_camera.size = maxf(3.0,extent*0.82)
	_camera.position = center+Vector3(1.0,0.7,1.25).normalized()*maxf(8,extent*2)
	_camera.look_at(center)

func _build_trail() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var any := false
	for i in range(1,record.path.size()):
		var a: Dictionary = record.path[i-1]
		var b: Dictionary = record.path[i]
		if float(a.time_s)>current_time: break
		var end: Vector3 = b.point_world if float(b.time_s)<=current_time else current_position
		if (a.point_world as Vector3).distance_to(end)>1e-6:
			mesh.surface_add_vertex(a.point_world)
			mesh.surface_add_vertex(end)
			any = true
		if float(b.time_s)>=current_time: break
	if not any:
		mesh.surface_add_vertex(current_position)
		mesh.surface_add_vertex(current_position+Vector3(0.00001,0,0))
	mesh.surface_end()
	_trail.mesh = mesh

func _update_highlights() -> void:
	highlighted_items.clear()
	var frame: Dictionary = record.frames[_frame_index]
	for row in _box_meshes:
		var damaged := false
		var selected := false
		for damage in record.damage:
			if damage.target_id == frame.entity_id and damage.kind == row.kind and damage.item_id == row.id and float(damage.flight_time_s)<=current_time+1e-7 and damage.get("before",{}) != damage.get("after",{}):
				damaged = true
		if selected_event >= 0:
			var event: Dictionary = events[selected_event]
			selected = event.kind == row.kind and event.get("item_id","") == row.id
		row.material.albedo_color = Color(1,0.26,0.15,0.85) if damaged else Color(0.42,0.52,0.57,0.18)
		if selected and damaged: row.material.albedo_color = Color(1,0.74,0.14,0.95)
		if damaged: highlighted_items.append(str(row.kind)+":"+str(row.id))

func _update_details() -> void:
	if chinese: _title.text = "实弹回放 · V 关闭"
	var event: Dictionary = {}
	if selected_event>=0:
		event = events[selected_event]
	else:
		for candidate in events:
			if float(candidate.flight_time_s)<=current_time+1e-7: event = candidate
	if event.is_empty():
		_details.text = ("实际飞行 · %.3f 秒\nN 接触 · , / . 历史 · J 导出" if chinese else "RECORDED FLIGHT · %.3f s\nN contact · , / . history · J export") % current_time
		return
	var item := str(event.get("item_id",event.get("surface_id","")))
	var result := str(event.get("result",event.get("reason",""))).replace("_"," ").to_upper()
	_details.text = "%s · %s\n%.1f → %.1f mm · N next contact" % [item.replace("_"," "),result,event.get("before_mm",0),event.get("after_mm",0)]
	if chinese:
		_details.text = "%s · %s\n%.1f → %.1f mm · N 下一接触" % [CoreUI.word(item),CoreUI.word(str(event.get("result",event.get("reason","")))),event.get("before_mm",0),event.get("after_mm",0)]

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if color.a<1: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
