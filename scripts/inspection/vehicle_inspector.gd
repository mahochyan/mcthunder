class_name VehicleInspector
extends Control

# 004-c：独立车辆检视窗口——查看历史研究模型的外观/装甲/内构与依据。
# 无 VehicleActor / Gunner / PlayerController / 命中信号；姿态/选中不写回共享定义。
# 返回按钮 / Esc → close_requested。

signal close_requested

const MODES := [
	["appearance", "Appearance"],
	["armor", "Armor"],
	["interior", "Interior"]
]

var _layout: VehicleLayoutDefinition
var _model: VehiclePreviewModel
var _viewport: SubViewport
var _camera: Camera3D
var _orbit_yaw := 35.0       # 相机绕车辆方位角（度）
var _orbit_pitch := 18.0
var _orbit_dist := 9.0
var _drag := false
var _last_mouse := Vector2.ZERO
var _yaw_slider: HSlider
var _pitch_slider: HSlider
var _layout_opt: OptionButton
var _mode_buttons: Array[Button] = []
var _parts_tree: Tree
var _details: Label
var _title_label: Label


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.92)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_title_label = Label.new()
	_title_label.text = "Vehicle Inspector"
	_title_label.add_theme_font_size_override("font_size", 26)
	add_child(_title_label)
	_title_label.position = Vector2(24, 14)

	# --- 关闭按钮 ---
	var close_btn := Button.new()
	close_btn.text = "Back [Esc]"
	close_btn.position = Vector2(24, 52)
	close_btn.custom_minimum_size = Vector2(140, 36)
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_btn)

	# --- 布局选择器 ---
	var layout_label := Label.new()
	layout_label.text = "Layout:"
	layout_label.position = Vector2(24, 102)
	add_child(layout_label)
	var layout_opt := OptionButton.new()
	_layout_opt = layout_opt
	layout_opt.position = Vector2(24, 124)
	layout_opt.custom_minimum_size = Vector2(320, 32)
	for id in LayoutCatalog.list_available():
		layout_opt.add_item(id)
	layout_opt.item_selected.connect(_on_layout_selected)
	add_child(layout_opt)

	# --- 模式按钮 ---
	var modes_row := HBoxContainer.new()
	modes_row.position = Vector2(24, 166)
	add_child(modes_row)
	for mode_entry in MODES:
		var b := Button.new()
		b.text = mode_entry[1]
		b.custom_minimum_size = Vector2(100, 32)
		b.pressed.connect(_on_mode_pressed.bind(mode_entry[0]))
		modes_row.add_child(b)
		_mode_buttons.append(b)

	# --- 姿态控制 ---
	var yaw_label := Label.new()
	yaw_label.text = "Turret yaw:"
	yaw_label.position = Vector2(24, 170)
	add_child(yaw_label)
	var yaw_slider := HSlider.new()
	yaw_slider.name = "YawSlider"
	yaw_slider.min_value = 0.0
	yaw_slider.max_value = 360.0
	yaw_slider.value = 0.0
	yaw_slider.step = 1.0
	yaw_slider.position = Vector2(24, 192)
	yaw_slider.custom_minimum_size = Vector2(320, 24)
	yaw_slider.value_changed.connect(_on_pose_changed)
	add_child(yaw_slider)
	_yaw_slider = yaw_slider
	var pitch_label := Label.new()
	pitch_label.text = "Gun pitch:"
	pitch_label.position = Vector2(24, 222)
	add_child(pitch_label)
	var pitch_slider := HSlider.new()
	pitch_slider.name = "PitchSlider"
	pitch_slider.min_value = -25.0
	pitch_slider.max_value = 20.0
	pitch_slider.value = 0.0
	pitch_slider.step = 1.0
	pitch_slider.position = Vector2(24, 244)
	pitch_slider.custom_minimum_size = Vector2(320, 24)
	pitch_slider.value_changed.connect(_on_pose_changed)
	add_child(pitch_slider)
	_pitch_slider = pitch_slider

	# --- 3D 视口 ---
	var vp_container := SubViewportContainer.new()
	vp_container.name = "PreviewContainer"
	vp_container.position = Vector2(360, 14)
	vp_container.custom_minimum_size = Vector2(880, 620)
	vp_container.stretch = true
	add_child(vp_container)
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

	# --- 部件/面片树 ---
	_parts_tree = Tree.new()
	_parts_tree.name = "PartsTree"
	_parts_tree.position = Vector2(24, 286)
	_parts_tree.custom_minimum_size = Vector2(320, 380)
	_parts_tree.item_selected.connect(_on_tree_item_selected)
	add_child(_parts_tree)

	# --- 详情面板 ---
	_details = Label.new()
	_details.name = "DetailsLabel"
	_details.text = "Select an item to see details."
	_details.position = Vector2(360, 644)
	_details.custom_minimum_size = Vector2(880, 80)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_details)


func load_layout(layout: VehicleLayoutDefinition) -> void:
	_layout = layout
	_title_label.text = "Vehicle Inspector - %s [%s]" % [layout.display_name, layout.content_tier]
	# 清旧模型
	var old := _viewport.find_child("PreviewModel", true, false)
	if old != null:
		old.queue_free()
	var preview := VehiclePreviewModel.new()
	preview.name = "PreviewModel"
	preview.setup(layout)
	preview.selection_changed.connect(_on_selection_changed)
	_viewport.add_child(preview)
	_update_camera()
	_fill_parts_tree()


func _update_camera() -> void:
	var rad_yaw := deg_to_rad(_orbit_yaw)
	var rad_pitch := deg_to_rad(_orbit_pitch)
	var target := Vector3.ZERO
	var offset := Vector3(
		cos(_orbit_pitch) * sin(rad_yaw),
		sin(_orbit_pitch),
		cos(_orbit_pitch) * cos(rad_yaw)) * _orbit_dist
	_camera.position = target + offset
	_camera.look_at(target, Vector3.UP)


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
	var l := LayoutCatalog.load_layout(id)
	if l != null:
		load_layout(l)


func _on_mode_pressed(mode: String) -> void:
	var preview: VehiclePreviewModel = _viewport.find_child("PreviewModel", true, false)
	if preview != null:
		preview.set_mode(mode)


func _on_pose_changed(_v: float) -> void:
	var preview: VehiclePreviewModel = _viewport.find_child("PreviewModel", true, false)
	if preview == null:
		return
	var yaw_slider := find_child("YawSlider", true, false) as HSlider
	var pitch_slider := find_child("PitchSlider", true, false) as HSlider
	if yaw_slider != null and pitch_slider != null:
		var r := preview.set_pose(yaw_slider.value, pitch_slider.value)
		_details.text = "Pose applied (clamped by joint limits): turret yaw %s deg, gun pitch %s deg" % [
			String.num(r.get("yaw_applied", 0.0), 1), String.num(r.get("pitch_applied", 0.0), 1)]


func _on_selection_changed(patch_id: String, _kind: String) -> void:
	_show_patch_details(patch_id)


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
			lines.append("geometry: %s" % patch.geometry_status)
			lines.append("evidence: %s" % ", ".join(patch.evidence_keys))
			_details.text = "\n".join(lines)
			return


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
				lines.append("material: %s  geometry: %s" % [patch.material_kind, patch.geometry_status])
				lines.append("evidence: %s" % ", ".join(patch.evidence_keys))
	elif kind == "module":
		for module in _layout.modules:
			if module != null and module.id == id:
				lines.append("MODULE: %s  kind: %s" % [module.id, module.kind])
				lines.append("part: %s  size: %s" % [module.part_id, str(module.size_m)])
				lines.append("geometry: %s%s" % [module.geometry_status, " (external)" if module.external else ""])
				lines.append("evidence: %s" % ", ".join(module.evidence_keys))
	elif kind == "crew":
		for station in _layout.crew_stations:
			if station != null and station.id == id:
				lines.append("CREW: %s  role: %s" % [station.id, station.role])
				lines.append("part: %s" % station.part_id)
				lines.append("position: %s  volume: %s" % [station.position_status, station.volume_status])
				lines.append("evidence: %s" % ", ".join(station.evidence_keys))
	elif kind == "part":
		for part in _layout.parts:
			if part != null and part.id == id:
				lines.append("PART: %s  parent: %s  joint: %s" % [part.id, part.parent_id, part.joint_kind])
				if part.joint_kind != "fixed":
					lines.append("limits: %.1f..%.1f deg" % [part.min_angle_deg, part.max_angle_deg])
				lines.append("evidence: %s" % ", ".join(part.evidence_keys))
	if lines.is_empty():
		lines.append("No details.")
	_details.text = "\n".join(lines)


func _on_tree_item_selected() -> void:
	var selected := _parts_tree.get_selected()
	if selected == null:
		return
	var meta = selected.get_metadata(0)
	show_selected_details(meta)
	# 面片树选中同步高亮（界面选中，不是炮弹命中）
	if meta != null and meta.get("kind", "") == "patch":
		var preview: VehiclePreviewModel = _viewport.find_child("PreviewModel", true, false)
		if preview != null:
			preview.select_patch(meta.get("id", ""))


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
			_orbit_pitch = clampf(_orbit_pitch + mm.relative.y * 0.3, -70.0, 80.0)
			_update_camera()
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()