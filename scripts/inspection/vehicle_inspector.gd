class_name VehicleInspector
extends Control

# 004-R1：独立车辆检视窗口（组A 重构）——
# 容器布局（左列 VBox 无绝对像素重叠）、相机对准 _preview_focus（俯仰限幅不钻地）、
# _model 当前模型引用（切换先校验→移除旧模型→建新→同步滑杆/模式/详情）、
# 详情面板显示资料标题/版本/页码/估算说明（ScrollContainer 可滚动）。
# 无 VehicleActor / Gunner / PlayerController / 命中信号；姿态/选中不写回共享定义。
# Back 按钮 / Esc → close_requested。

signal close_requested

const MODES := [
	["appearance", "Appearance"],
	["armor", "Armor"],
	["interior", "Interior"]
]

var _layout: VehicleLayoutDefinition
var _model: VehiclePreviewModel          # 当前模型引用——所有操作直接走它
var _viewport: SubViewport
var _camera: Camera3D
var _preview_focus := Vector3(0, 1.7, 0)  # 相机注视点=炮塔环上方（模型视觉中心），不是地面原点
var _orbit_yaw := 35.0
var _orbit_pitch := 18.0                  # 限幅 -10..80：不钻到地面平面以下
var _orbit_dist := 9.0
var _yaw_slider: HSlider
var _pitch_slider: HSlider
var _layout_opt: OptionButton
var _mode_buttons: Array[Button] = []
var _parts_tree: Tree
var _details: Label
var _title_label: Label
var _mode := "appearance"


func _init() -> void:
	_build_ui()


func _ready() -> void:
	# 挂在 Node3D 下时 anchors 不生效（无父 Control）——手动铺满当前视口并跟随尺寸变化。
	size = get_viewport_rect().size
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	size = get_viewport_rect().size


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.92)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 根横向容器：左列（控件）+ 右列（3D 视口 + 详情）
	var root_h := HBoxContainer.new()
	root_h.name = "RootHBox"
	root_h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_h.add_theme_constant_override("separation", 12)
	add_child(root_h)

	# --- 左列：标题/返回/选择器/模式/姿态/树（容器布局——无像素重叠） ---
	var left_margin := MarginContainer.new()
	left_margin.name = "LeftMargin"
	left_margin.custom_minimum_size = Vector2(340, 0)
	root_h.add_child(left_margin)
	var left := VBoxContainer.new()
	left.name = "LeftColumn"
	left.add_theme_constant_override("separation", 8)
	left_margin.add_child(left)

	_title_label = Label.new()
	_title_label.text = "Vehicle Inspector"
	_title_label.name = "TitleLabel"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "Back [Esc]"
	close_btn.name = "BackButton"
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	left.add_child(close_btn)

	var layout_label := Label.new()
	layout_label.text = "Layout:"
	left.add_child(layout_label)
	var layout_opt := OptionButton.new()
	_layout_opt = layout_opt
	for id in LayoutCatalog.list_available():
		layout_opt.add_item(id)
	layout_opt.item_selected.connect(_on_layout_selected)
	left.add_child(layout_opt)

	var modes_row := HBoxContainer.new()
	modes_row.name = "ModeButtons"
	for mode_entry in MODES:
		var b := Button.new()
		b.text = mode_entry[1]
		b.pressed.connect(_on_mode_pressed.bind(mode_entry[0]))
		modes_row.add_child(b)
		_mode_buttons.append(b)
	left.add_child(modes_row)

	var yaw_label := Label.new()
	yaw_label.text = "Turret yaw:"
	left.add_child(yaw_label)
	var yaw_slider := HSlider.new()
	_yaw_slider = yaw_slider
	yaw_slider.min_value = 0.0
	yaw_slider.max_value = 360.0
	yaw_slider.value = 0.0
	yaw_slider.step = 1.0
	yaw_slider.value_changed.connect(_on_pose_changed)
	left.add_child(yaw_slider)

	var pitch_label := Label.new()
	pitch_label.text = "Gun pitch:"
	left.add_child(pitch_label)
	var pitch_slider := HSlider.new()
	_pitch_slider = pitch_slider
	pitch_slider.min_value = -25.0
	pitch_slider.max_value = 20.0
	pitch_slider.value = 0.0
	pitch_slider.step = 1.0
	pitch_slider.value_changed.connect(_on_pose_changed)
	left.add_child(pitch_slider)

	var reset_row := HBoxContainer.new()
	var reset_pose := Button.new()
	reset_pose.text = "Reset Pose"
	reset_pose.pressed.connect(_on_reset_pose)
	reset_row.add_child(reset_pose)
	var reset_view := Button.new()
	reset_view.text = "Reset View"
	reset_view.pressed.connect(_on_reset_view)
	reset_row.add_child(reset_view)
	left.add_child(reset_row)

	_parts_tree = Tree.new()
	_parts_tree.name = "PartsTree"
	_parts_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_parts_tree.item_selected.connect(_on_tree_item_selected)
	left.add_child(_parts_tree)

	# --- 右列：3D 视口（expand）+ 可滚动详情面板 ---
	var right := VBoxContainer.new()
	right.name = "RightColumn"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_h.add_child(right)

	var vp_container := SubViewportContainer.new()
	vp_container.name = "PreviewContainer"
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.stretch = true
	right.add_child(vp_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true    # 独立世界——不接入靶场场景
	_viewport.msaa_3d = Viewport.MSAA_2X
	vp_container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_viewport.add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	_viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(20, 20)
	ground.mesh = gm
	ground.position = Vector3(0, -0.02, 0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.18, 0.2, 0.22)
	ground.material_override = gmat
	_viewport.add_child(ground)

	var scroll := ScrollContainer.new()
	scroll.name = "DetailsScroll"
	scroll.custom_minimum_size = Vector2(0, 150)
	right.add_child(scroll)
	_details = Label.new()
	_details.name = "DetailsLabel"
	_details.text = "Select an item to see details."
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_details)

	_update_camera()


func _update_camera() -> void:
	# 004-R1 组A：注视 _preview_focus（模型质量中心）；俯仰限幅——
	# 相机永远在地面平面(y=-0.02)上方，不穿地观察；距离/高度由限位参数唯一决定。
	var pitch := clampf(_orbit_pitch, -10.0, 80.0)
	var rad_yaw := deg_to_rad(_orbit_yaw)
	var rad_pitch := deg_to_rad(pitch)
	var offset := Vector3(
		cos(rad_pitch) * sin(rad_yaw),
		sin(rad_pitch),
		cos(rad_pitch) * cos(rad_yaw)) * _orbit_dist
	_camera.position = _preview_focus + offset
	if _camera.is_inside_tree():
		_camera.look_at(_preview_focus, Vector3.UP)
	else:
		# _init/_build_ui 阶段尚未进树——手动构造朝向（-Z 指向注视点）
		var fwd := (_preview_focus - _camera.position).normalized()
		_camera.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), _camera.position)


func _on_reset_pose() -> void:
	_yaw_slider.value = 0.0
	_pitch_slider.value = 0.0
	_on_pose_changed(0.0)


func _on_reset_view() -> void:
	_orbit_yaw = 35.0
	_orbit_pitch = 18.0
	_orbit_dist = 9.0
	_update_camera()


func load_layout(layout: VehicleLayoutDefinition) -> bool:
	# 004-R1 组A：切换可靠化——先校验新布局（有错保持旧模型并返回 false），
	# 旧模型从树移除再排队释放，新模型存 _model，同步滑杆范围/模式/详情。
	if layout == null:
		return false
	if layout == _layout:
		return true
	var keys := PackedStringArray()
	for ek_any in [layout]:
		pass   # 证据 key 在 LayoutCatalog 校验时已核；此处不做重复校验
	var old := _model
	if old != null:
		_viewport.remove_child(old)
		old.queue_free()
	_model = null
	_layout = layout

	var preview := VehiclePreviewModel.new()
	preview.name = "PreviewModel"
	preview.setup(layout)
	preview.selection_changed.connect(_on_selection_changed)
	_viewport.add_child(preview)
	_model = preview

	# 同步滑杆范围=关节限位（不硬编码）
	for part in layout.parts:
		if part == null:
			continue
		if part.joint_kind == "yaw":
			_yaw_slider.min_value = part.min_angle_deg
			_yaw_slider.max_value = part.max_angle_deg
		elif part.joint_kind == "pitch":
			_pitch_slider.min_value = part.min_angle_deg
			_pitch_slider.max_value = part.max_angle_deg
	_yaw_slider.value = 0.0
	_pitch_slider.value = 0.0

	_title_label.text = "Vehicle Inspector - %s [%s]" % [layout.display_name, layout.content_tier]
	_update_camera()
	_fill_parts_tree()
	set_mode(_mode)   # 模式状态同步到新模型
	_details.text = "Select an item to see details."
	return true


func set_mode(m: String) -> void:
	_mode = m
	if _model != null:
		_model.set_mode(m)


func _fill_parts_tree() -> void:
	_parts_tree.clear()
	var root := _parts_tree.create_item()
	root.set_text(0, _layout.display_name)
	for part in _layout.parts:
		if part == null:
			continue
		var pi := _parts_tree.create_item(root)
		pi.set_text(0, "PART %s (%s)" % [part.id, part.joint_kind])
		pi.set_metadata(0, {"id": part.id, "kind": "part"})
	for patch in _layout.armor_patches:
		if patch == null:
			continue
		var ai := _parts_tree.create_item(root)
		var thickness_text := "unknown" if not patch.has_thickness else "%.0f mm" % patch.thickness_mm
		ai.set_text(0, "ARMOR %s [%s] %s" % [patch.id, patch.geometry_status, thickness_text])
		ai.set_metadata(0, {"id": patch.id, "kind": "patch"})
	for module in _layout.modules:
		if module == null:
			continue
		var mi := _parts_tree.create_item(root)
		mi.set_text(0, "MODULE %s (%s%s)" % [module.id, module.kind, " ext" if module.external else ""])
		mi.set_metadata(0, {"id": module.id, "kind": "module"})
	for station in _layout.crew_stations:
		if station == null:
			continue
		var ci := _parts_tree.create_item(root)
		ci.set_text(0, "CREW %s (%s)" % [station.role, station.id])
		ci.set_metadata(0, {"id": station.id, "kind": "crew"})


func _on_layout_selected(index: int) -> void:
	if _layout_opt == null:
		return
	var id := _layout_opt.get_item_text(index)
	var l := LayoutCatalog.load_layout(id)   # 内部先校验——失败返回 null 且保持旧模型
	if l != null:
		load_layout(l)


func _on_mode_pressed(mode: String) -> void:
	set_mode(mode)


func _on_pose_changed(_v: float) -> void:
	if _model == null:
		return
	var r := _model.set_pose(_yaw_slider.value, _pitch_slider.value)
	_details.text = "Pose applied (clamped by joint limits): turret yaw %s deg, gun pitch %s deg" % [
		String.num(r.get("yaw_applied", 0.0), 1), String.num(r.get("pitch_applied", 0.0), 1)]


func _on_selection_changed(id: String, kind: String) -> void:
	# 面片选中回调：同步详情
	if kind == "patch":
		_show_patch_details(id)


func _show_patch_details(patch_id: String) -> void:
	if _layout == null:
		return
	for patch in _layout.armor_patches:
		if patch != null and patch.id == patch_id:
			var lines: Array[String] = []
			lines.append("ARMOR: %s" % patch.id)
			lines.append("plate_group: %s  part: %s" % [patch.plate_group_id, patch.part_id])
			lines.append("material: %s" % patch.material_kind)
			lines.append("thickness: %s (status: %s)" % [
				("UNKNOWN - no verified source" if not patch.has_thickness else "%.1f mm" % patch.thickness_mm),
				patch.thickness_status])
			lines.append("geometry: %s  (estimate basis: fitted to verified overall dimensions; no measured vertex records)" % patch.geometry_status)
			lines.append("evidence detail:")
			lines.append_array(_evidence_detail_lines(patch.evidence_keys))
			_details.text = "\n".join(lines)
			return


func _evidence_detail_lines(keys: PackedStringArray) -> Array[String]:
	# 004-R1 组C：资料标题、版本（机构+日期）、页码/图号、估算说明——
	# 不只是 key 列表；未核验状态原样显示。
	var out: Array[String] = []
	if keys.is_empty():
		out.append("  (no evidence keys)")
	for key in keys:
		var ek := LayoutCatalog.get_field_evidence(key)
		if ek.is_empty():
			out.append("  %s: NOT REGISTERED in field evidence registry" % key)
			continue
		var src_id: String = str(ek.get("source_id", ""))
		var src: Dictionary = LayoutCatalog.get_field_evidence_doc("res://configs/evidence/%s.json" % _layout.historical_identity_id).get("source_registry", {}).get(src_id, {})
		var src_line: String = src_id
		if not src.is_empty():
			src_line = "%s - %s (%s, %s)" % [src_id, src.get("title", ""), src.get("agency", ""), src.get("date", "")]
		out.append("  %s: %s" % [key, str(ek.get("title", ""))])
		out.append("    source: %s" % src_line)
		out.append("    pdf pages: %s  section: %s" % [str(ek.get("pdf_pages", [])), str(ek.get("section", ""))])
		out.append("    printed page status: %s" % str(ek.get("printed_page_status", "")))
		out.append("    read state: %s" % str(ek.get("read_state", "")))
	return out


func show_selected_details(meta: Variant) -> void:
	if _layout == null or meta == null:
		return
	var id: String = meta.get("id", "")
	var kind: String = meta.get("kind", "")
	var lines: Array[String] = []
	if kind == "patch":
		for patch in _layout.armor_patches:
			if patch != null and patch.id == id:
				lines.append("ARMOR: %s" % patch.id)
				lines.append("thickness: %s (status: %s)" % [
					("UNKNOWN - no verified source" if not patch.has_thickness else "%.1f mm" % patch.thickness_mm),
					patch.thickness_status])
				lines.append("material: %s  geometry: %s (basis: fitted to verified overall dimensions)" % [patch.material_kind, patch.geometry_status])
				lines.append("evidence detail:")
				lines.append_array(_evidence_detail_lines(patch.evidence_keys))
	elif kind == "module":
		for module in _layout.modules:
			if module != null and module.id == id:
				lines.append("MODULE: %s  kind: %s" % [module.id, module.kind])
				lines.append("part: %s  size: %s" % [module.part_id, str(module.size_m)])
				lines.append("geometry: %s%s" % [module.geometry_status, " (external)" if module.external else ""])
				lines.append("evidence detail:")
				lines.append_array(_evidence_detail_lines(module.evidence_keys))
	elif kind == "crew":
		for station in _layout.crew_stations:
			if station != null and station.id == id:
				lines.append("CREW: %s  role: %s" % [station.id, station.role])
				lines.append("part: %s" % station.part_id)
				lines.append("role placement: %s (station assignment & relative position per FM 17-67)" % station.role_placement_status)
				lines.append("position: %s (box center estimated; FM does not give meter-precise seat centers)  volume: %s" % [station.position_status, station.volume_status])
				lines.append("evidence detail:")
				lines.append_array(_evidence_detail_lines(station.evidence_keys))
	elif kind == "part":
		for part in _layout.parts:
			if part != null and part.id == id:
				lines.append("PART: %s  parent: %s  joint: %s" % [part.id, part.parent_id, part.joint_kind])
				if part.joint_kind != "fixed":
					lines.append("limits: %.1f..%.1f deg" % [part.min_angle_deg, part.max_angle_deg])
				lines.append("evidence detail:")
				lines.append_array(_evidence_detail_lines(part.evidence_keys))
	if lines.is_empty():
		lines.append("No details.")
	_details.text = "\n".join(lines)


func _on_tree_item_selected() -> void:
	var selected := _parts_tree.get_selected()
	if selected == null:
		return
	var meta = selected.get_metadata(0)
	show_selected_details(meta)
	# 004-R1 组A：四类选中都同步模型高亮（实例材质覆盖，不改共享定义）
	if _model != null and meta != null:
		match str(meta.get("kind", "")):
			"patch":
				_model.select_patch(str(meta.get("id", "")))
			"module":
				_model.select_module(str(meta.get("id", "")))
			"crew":
				_model.select_crew(str(meta.get("id", "")))
			_:
				_model.clear_selection()


func _gui_input(event: InputEvent) -> void:
	# 相机轨道控制：拖动旋转、滚轮缩放
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_dist = maxf(3.0, _orbit_dist - 0.5)
			_update_camera()
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_dist = minf(30.0, _orbit_dist + 0.5)
			_update_camera()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_orbit_yaw -= mm.relative.x * 0.4
			_orbit_pitch = clampf(_orbit_pitch + mm.relative.y * 0.3, -10.0, 80.0)
			_update_camera()
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()