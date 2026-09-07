class_name QueryDebugPanel
extends Control

# 005-d：统一命中查询调试面板——GEOMETRY ONLY（纯几何调试，不结算）。
# 查询走生产同一条 ShotQueryService（真实实体快照 + 显式测试墙方盒）；
# 不调用 register_hit / accept_hit / 冷却 / 弹药 / 任务；不触碰 Gunner；
# 测试墙同时挂 LAYER_WORLD 物理体（真射路径可见），但面板自身的墙交点
# 完全由 QueryGeometry 计算（不访问物理射线）。
# 打开时 main 关闭 PlayerController.commands_enabled（不误触开火/驾驶/瞄准）；
# 姿态变化（如炮塔继续收敛）→ 旧结果标记 STALE（不伪造"当前姿态"）。
# 全部 UI 文字英文（工程规则：游戏内英文 UI）。

signal close_requested

const PROBES: Array = [
	["barrel", "Barrel axis (muzzle)"],
	["camera", "Camera aim ray"],
	["a_to_b", "A center -> B center"],
	["custom", "Custom from/to"],
]

const COLOR_ARMOR := Color(0.95, 0.6, 0.1)
const COLOR_MODULE_ENTER := Color(0.25, 0.9, 0.35)
const COLOR_MODULE_EXIT := Color(0.95, 0.25, 0.25)
const COLOR_CREW_ENTER := Color(0.3, 0.8, 0.9)
const COLOR_CREW_EXIT := Color(0.6, 0.4, 0.95)
const COLOR_WALL_ENTER := Color(0.25, 0.55, 1.0)
const COLOR_WALL_EXIT := Color(0.65, 0.35, 1.0)
const COLOR_STALE := Color(0.5, 0.5, 0.56)
const COLOR_HIGHLIGHT := Color(1.0, 1.0, 0.35)
const COLOR_SEGMENT := Color(0.2, 0.95, 1.0, 0.85)

const WALL_DEFAULT_POS := Vector3(4.0, 1.2, 4.0)
const WALL_DEFAULT_SIZE := Vector3(0.4, 3.0, 3.0)
const WALL_DEFAULT_YAW := 45.0

var main: Main = null            # 目标场景引用（panel 由 main 创建并注入）
var _vehicle_filter := "ALL"     # 实体过滤："ALL" 或实体标识
var _probe := "barrel"
var _include_modules := true
var _include_crew := false
var _wall: StaticBody3D = null
var _wall_pos := WALL_DEFAULT_POS
var _wall_size := WALL_DEFAULT_SIZE
var _wall_yaw_deg := WALL_DEFAULT_YAW

var _marker_holder: Node3D = null
var _segment_line: MeshInstance3D = null
var _markers: Array = []         # [{seq, mi, ev, run, base_scale}] 世界标记
var _marker_seq := 0
var _runs := 0
var _stale := false
var _last_pose_hash := 0
var _last_result := {}           # 最近一次服务结果（ok/complete/events/diagnostics）
var _merged_events: Array = []   # 服务事件 + 墙交点（已排序，含展示 tag）
var _row_meta: Array = []        # 与 ItemList 行一一对应
var _wall_enter_dist := -1.0
var _from_world := Vector3.ZERO
var _to_world := Vector3.ZERO
var _seg_length := 0.0
var _highlighted: MeshInstance3D = null

var _title: Label
var _vehicle_opt: OptionButton
var _probe_opt: OptionButton
var _from_label: Label
var _to_label: Label
var _custom_from: LineEdit
var _custom_to: LineEdit
var _mod_check: CheckBox
var _crew_check: CheckBox
var _wall_btn: Button
var _wall_state: Label
var _status: Label
var _results: ItemList
var _detail: Label


func _ready() -> void:
	size = get_viewport_rect().size
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_build_ui()
	_refresh_vehicle_list()


func _on_viewport_resized() -> void:
	size = get_viewport_rect().size


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 左侧半透面板 + 右侧透出 3D 场景（标记/线段在世界上可见）
	var panel := PanelContainer.new()
	panel.name = "SidePanel"
	panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	_title = Label.new()
	_title.name = "TitleLabel"
	_title.text = "Shot Query Debug — GEOMETRY ONLY"
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_title.add_theme_font_size_override("font_size", 17)
	col.add_child(_title)

	var sub := Label.new()
	sub.name = "SubLabel"
	sub.text = "Pure geometry only: no penetration, no damage, no ammo/task effect. Queries run through the production ShotQueryService; debug runs never call register_hit / cooldowns."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	sub.add_theme_font_size_override("font_size", 12)
	col.add_child(sub)

	var row_veh := HBoxContainer.new()
	var veh_label := Label.new()
	veh_label.text = "Vehicles:"
	veh_label.custom_minimum_size = Vector2(90, 0)
	row_veh.add_child(veh_label)
	_vehicle_opt = OptionButton.new()
	_vehicle_opt.name = "VehicleSelect"
	_vehicle_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicle_opt.item_selected.connect(_on_vehicle_selected)
	row_veh.add_child(_vehicle_opt)
	col.add_child(row_veh)

	var row_probe := HBoxContainer.new()
	var probe_label := Label.new()
	probe_label.text = "Probe line:"
	probe_label.custom_minimum_size = Vector2(90, 0)
	row_probe.add_child(probe_label)
	_probe_opt = OptionButton.new()
	_probe_opt.name = "ProbeSelect"
	_probe_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in PROBES:
		_probe_opt.add_item(entry[1])
	_probe_opt.item_selected.connect(_on_probe_selected)
	row_probe.add_child(_probe_opt)
	col.add_child(row_probe)

	_from_label = Label.new()
	_from_label.name = "FromLabel"
	_from_label.text = "from: -"
	_from_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_from_label.add_theme_font_size_override("font_size", 11)
	col.add_child(_from_label)
	_to_label = Label.new()
	_to_label.name = "ToLabel"
	_to_label.text = "to:   -"
	_to_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_to_label.add_theme_font_size_override("font_size", 11)
	col.add_child(_to_label)

	var custom_col := VBoxContainer.new()
	custom_col.name = "CustomBox"
	var cf_row := HBoxContainer.new()
	var cf_l := Label.new()
	cf_l.text = "custom from (x,y,z):"
	cf_l.custom_minimum_size = Vector2(140, 0)
	cf_row.add_child(cf_l)
	_custom_from = LineEdit.new()
	_custom_from.name = "CustomFrom"
	_custom_from.placeholder_text = "0,1,-5"
	_custom_from.text = "0,1,-5"
	cf_row.add_child(_custom_from)
	custom_col.add_child(cf_row)
	var ct_row := HBoxContainer.new()
	var ct_l := Label.new()
	ct_l.text = "custom to (x,y,z):"
	ct_l.custom_minimum_size = Vector2(140, 0)
	ct_row.add_child(ct_l)
	_custom_to = LineEdit.new()
	_custom_to.name = "CustomTo"
	_custom_to.placeholder_text = "0,1,5"
	_custom_to.text = "0,1,5"
	ct_row.add_child(_custom_to)
	custom_col.add_child(ct_row)
	col.add_child(custom_col)

	var row_checks := HBoxContainer.new()
	_mod_check = CheckBox.new()
	_mod_check.name = "IncludeModules"
	_mod_check.text = "Include modules"
	_mod_check.button_pressed = _include_modules
	_mod_check.toggled.connect(_on_options_changed)
	row_checks.add_child(_mod_check)
	_crew_check = CheckBox.new()
	_crew_check.name = "IncludeCrew"
	_crew_check.text = "Include crew"
	_crew_check.button_pressed = _include_crew
	_crew_check.toggled.connect(_on_options_changed)
	row_checks.add_child(_crew_check)
	col.add_child(row_checks)

	var wall_label := Label.new()
	wall_label.text = "Test wall (explicit geometry box; yaw around Y)"
	wall_label.add_theme_font_size_override("font_size", 12)
	col.add_child(wall_label)
	var w_grp := GridContainer.new()
	w_grp.columns = 4
	var wpl := Label.new(); wpl.text = "pos"
	var wsl := Label.new(); wsl.text = "size"
	var wyl := Label.new(); wyl.text = "yaw°"
	w_grp.add_child(wpl); w_grp.add_child(wsl); w_grp.add_child(wyl)
	_wall_btn = Button.new()
	_wall_btn.name = "AddWallButton"
	_wall_btn.text = "Add Test Wall"
	_wall_btn.pressed.connect(_on_wall_pressed)
	w_grp.add_child(_wall_btn)
	var wpx := LineEdit.new(); wpx.text = "%.1f,%.1f,%.1f" % [WALL_DEFAULT_POS.x, WALL_DEFAULT_POS.y, WALL_DEFAULT_POS.z]
	wpx.custom_minimum_size = Vector2(110, 0)
	wpx.text_submitted.connect(_on_wall_fields)
	wpx.name = "WallPos"
	w_grp.add_child(wpx)
	var wss := LineEdit.new(); wss.text = "%.1f,%.1f,%.1f" % [WALL_DEFAULT_SIZE.x, WALL_DEFAULT_SIZE.y, WALL_DEFAULT_SIZE.z]
	wss.custom_minimum_size = Vector2(110, 0)
	wss.text_submitted.connect(_on_wall_fields)
	wss.name = "WallSize"
	w_grp.add_child(wss)
	var wyd := LineEdit.new(); wyd.text = "%.0f" % WALL_DEFAULT_YAW
	wyd.custom_minimum_size = Vector2(60, 0)
	wyd.text_submitted.connect(_on_wall_fields)
	wyd.name = "WallYaw"
	w_grp.add_child(wyd)
	col.add_child(w_grp)
	_wall_state = Label.new()
	_wall_state.name = "WallState"
	_wall_state.text = "wall: none"
	_wall_state.add_theme_font_size_override("font_size", 11)
	col.add_child(_wall_state)

	var row_btns := HBoxContainer.new()
	var run_btn := Button.new()
	run_btn.name = "RunQueryButton"
	run_btn.text = "Run Query"
	run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_btn.pressed.connect(run_query)
	row_btns.add_child(run_btn)
	var clear_btn := Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(clear_results)
	row_btns.add_child(clear_btn)
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close [Esc]"
	close_btn.pressed.connect(func() -> void: close_requested.emit())
	row_btns.add_child(close_btn)
	col.add_child(row_btns)

	_status = Label.new()
	_status.name = "StatusLabel"
	_status.text = "No query yet."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	col.add_child(_status)

	_results = ItemList.new()
	_results.name = "ResultsList"
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.item_selected.connect(_on_row_selected)
	col.add_child(_results)

	_detail = Label.new()
	_detail.name = "DetailLabel"
	_detail.text = ""
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 64)
	_detail.add_theme_font_size_override("font_size", 11)
	col.add_child(_detail)


# ---------------------------------------------------------------- 公共 API（按钮与测试同一入口）

func set_probe(id: String) -> void:
	_probe = id
	for i in PROBES.size():
		if PROBES[i][0] == id:
			_probe_opt.select(i)
			break
	_refresh_segment_labels()


func set_vehicle_filter(f: String) -> void:
	_vehicle_filter = f
	for i in _vehicle_opt.item_count:
		if _vehicle_opt.get_item_text(i) == f:
			_vehicle_opt.select(i)
			break


func set_include_modules(on: bool) -> void:
	_include_modules = on
	_mod_check.button_pressed = on


func set_include_crew(on: bool) -> void:
	_include_crew = on
	_crew_check.button_pressed = on


func probe_geometry() -> Dictionary:
	var seg := _probe_segment()
	return {"from_world": seg[0], "to_world": seg[1]}


func set_wall_geometry(pos: Vector3, size: Vector3, yaw_deg: float) -> void:
	# 测试/演示注入（等价于手填三个输入框）——不创建物理体，需再点 Add Test Wall。
	_wall_pos = pos
	_wall_size = size
	_wall_yaw_deg = yaw_deg
	var wpx := find_child("WallPos", true, false) as LineEdit
	var wss := find_child("WallSize", true, false) as LineEdit
	var wyd := find_child("WallYaw", true, false) as LineEdit
	if wpx != null:
		wpx.text = "%.2f,%.2f,%.2f" % [pos.x, pos.y, pos.z]
	if wss != null:
		wss.text = "%.2f,%.2f,%.2f" % [size.x, size.y, size.z]
	if wyd != null:
		wyd.text = "%.1f" % yaw_deg


func add_wall() -> bool:
	if _wall != null or main == null:
		return false
	var body := main.world.build_box(_wall_pos, _wall_size, Color(0.35, 0.5, 0.85))
	body.rotation.y = deg_to_rad(_wall_yaw_deg)
	_wall = body
	_wall_btn.text = "Remove Test Wall"
	_wall_state.text = "wall: pos %s size %s yaw %.1f° (LAYER_WORLD + geometry box)" % [str(_wall_pos), str(_wall_size), _wall_yaw_deg]
	return true


func remove_wall() -> bool:
	if _wall == null:
		return false
	var w := _wall
	_wall = null
	w.queue_free()
	_wall_btn.text = "Add Test Wall"
	_wall_state.text = "wall: none"
	_wall_enter_dist = -1.0
	return true


func clear_results() -> void:
	_runs = 0
	_stale = false
	_last_result = {}
	_merged_events = []
	_row_meta = []
	_wall_enter_dist = -1.0
	_results.clear()
	_detail.text = ""
	_status.text = "Cleared."
	for m in _markers:
		if is_instance_valid(m.get("mi", null)):
			(m["mi"] as Node).queue_free()
	_markers = []
	_clear_segment_line()
	if _highlighted != null:
		_highlighted = null


func last_result() -> Dictionary:
	return _last_result.duplicate(true) if not _last_result.is_empty() else {}


func last_events() -> Array:
	return _merged_events.duplicate(true)


func marker_count() -> int:
	return _markers.size()


func current_run_marker_count() -> int:
	# 最近一次运行生成的标记数（旧运行标记保留但变灰，不计入）
	var n := 0
	for m in _markers:
		if int(m.get("run", 0)) == _runs:
			n += 1
	return n


func has_wall() -> bool:
	return _wall != null


func is_stale() -> bool:
	return _stale


func free_world_art() -> void:
	# 关闭面板时一并移除世界标记与线段（挂载点随 main 场景生命周期）
	clear_results()
	if _marker_holder != null and is_instance_valid(_marker_holder):
		_marker_holder.queue_free()
	_marker_holder = null
	_segment_line = null


func current_rows() -> Array:
	# 与 ItemList 行一一对应的元数据（[{index, event}]）
	return _row_meta.duplicate(true)


func run_query() -> Dictionary:
	if main == null:
		return {}
	_refresh_vehicle_list()   # 新生成实体纳入选择（运行前刷一次）
	var seg := _probe_segment()
	_from_world = seg[0]
	_to_world = seg[1]
	_seg_length = _from_world.distance_to(_to_world)
	if _seg_length <= QueryGeometry.EPS_M:
		_status.text = "INVALID segment (zero length) — set a valid probe."
		return {}
	var snapshots := _filtered_snapshots()
	var qr := ShotQueryService.query({
		"query_id": "dbg_%d" % (_runs + 1),
		"physics_tick": Engine.get_physics_frames(),
		"from_world": _from_world,
		"to_world": _to_world,
		"excluded_instances": [],
		"include_modules": _include_modules,
		"include_crew": _include_crew,
	}, snapshots)
	_last_result = qr
	var wall_crossings := _compute_wall_crossings()
	_merged_events = _merge_and_sort(qr.get("events", []), wall_crossings)
	# 上一运行结果标陈旧（旧标记留世界但变灰）
	for m in _markers:
		if int(m.get("run", 0)) == _runs:
			_draw_marker_as(m, COLOR_STALE, float(m.get("base_scale", 1.0)))
	_runs += 1
	_row_meta = []
	_results.clear()
	_draw_segment_line()
	for k in _merged_events.size():
		var ev: Dictionary = _merged_events[k]
		var seq := _spawn_world_marker(ev, _runs)
		var tag := _occlusion_tag(ev)
		var row := "%d  %6.2fm  %s  %s  %s" % [seq, float(ev.get("distance_m", 0.0)), str(ev.get("event_type", "")), str(ev.get("kind", "")), _row_identity(ev)]
		_results.add_item(row)
		_row_meta.append({"index": seq, "event": ev, "tag": tag})
	if _merged_events.is_empty():
		_results.add_item("(no intersections)")
		_row_meta.append({"index": -1, "event": {}, "tag": ""})
	_stale = false
	_last_pose_hash = _pose_hash()
	_update_status(qr, wall_crossings)
	return qr


# ---------------------------------------------------------------- 查询组装

func _filtered_snapshots() -> Array:
	var all: Array = main.query_snapshots()
	var out: Array = []
	for s in all:
		if _vehicle_filter == "ALL" or str(s.get("entity_id", "")) == _vehicle_filter:
			out.append(s)
	return out


func _probe_segment() -> Array:
	var range_m: float = GameConfig.GUN_RANGE
	if main.gunner != null and main.gunner.weapon != null:
		range_m = main.gunner.weapon.gun_range
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	match _probe:
		"barrel":
			from = main.turret.muzzle.global_position
			to = from + main.turret.barrel_direction() * range_m
		"camera":
			from = main.cam_rig.cam.global_position
			to = from + (-main.cam_rig.cam.global_transform.basis.z) * 150.0
		"a_to_b":
			from = main.actor_a.tank.global_position + Vector3(0, 1.0, 0)
			to = main.actor_b.tank.global_position + Vector3(0, 1.0, 0)
		_:
			from = _parse_vec3(_custom_from.text, Vector3(0, 1, -5))
			to = _parse_vec3(_custom_to.text, Vector3(0, 1, 5))
	return [from, to]


func _parse_vec3(text: String, fallback: Vector3) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		return fallback
	var values: Array = []
	for p in parts:
		var f: float = fallback[values.size()]
		if p.strip_edges().is_valid_float():
			f = float(p.strip_edges())
		values.append(f)
	return Vector3(values[0], values[1], values[2])


func _compute_wall_crossings() -> Array:
	_wall_enter_dist = -1.0
	if _wall == null or _seg_length <= QueryGeometry.EPS_M:
		return []
	var wall_basis := Basis(Vector3.UP, deg_to_rad(_wall_yaw_deg))
	var tf := Transform3D(wall_basis, _wall_pos)
	var inv := tf.affine_inverse()
	var lf := inv * _from_world
	var lt := inv * _to_world
	var r := QueryGeometry.segment_box_local(lf, lt, _wall_size)
	if not r.get("ok", false) or not r.get("hit", false):
		return []
	var out: Array = []
	var t_enter: float = float(r["t_enter"])
	var t_exit: float = float(r["t_exit"])
	if r.get("grazing", false):
		var pt := _from_world.lerp(_to_world, t_enter)
		out.append(_wall_event("touch", t_enter, pt, Vector3.ZERO, false))
		_wall_enter_dist = _seg_length * t_enter
		return out
	if r.get("has_entry_boundary", false):
		var en: Vector3 = r["normal_enter_local"]
		var pt_e := _from_world.lerp(_to_world, t_enter)
		out.append(_wall_event("enter", t_enter, pt_e, tf.basis * en, true))
		_wall_enter_dist = _seg_length * t_enter
	if r.get("has_exit_boundary", false):
		var ex: Vector3 = r["normal_exit_local"]
		var pt_x := _from_world.lerp(_to_world, t_exit)
		out.append(_wall_event("exit", t_exit, pt_x, tf.basis * ex, true))
	return out


func _wall_event(event_type: String, t: float, point: Vector3, normal: Vector3, normal_known: bool) -> Dictionary:
	return {
		"kind": "wall",
		"event_type": event_type,
		"entity_id": "test",
		"life_id": 0,
		"part_id": "wall",
		"surface_id": "test_wall",
		"distance_m": _seg_length * t,
		"t": t,
		"point_world": point,
		"normal_world": normal,
		"normal_known": normal_known,
		"at_start": t <= QueryGeometry.EPS_M / maxf(_seg_length, 0.0001),
		"at_end": t >= 1.0 - QueryGeometry.EPS_M / maxf(_seg_length, 0.0001),
		"on_edge": false,
		"has_thickness": false,
	}


func _merge_and_sort(service_events: Array, wall_events: Array) -> Array:
	var merged: Array = []
	for ev in service_events:
		merged.append(ev)
	for ev in wall_events:
		merged.append(ev)
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = float(a.get("distance_m", 0.0))
		var db: float = float(b.get("distance_m", 0.0))
		if absf(da - db) > QueryGeometry.EPS_M:
			return da < db
		return _sort_key(a) < _sort_key(b)
	)
	return merged


func _sort_key(ev: Dictionary) -> String:
	return "%s:%d:%s:%s:%s" % [
		str(ev.get("kind", "")), int(ev.get("life_id", 0)),
		str(ev.get("entity_id", "")), str(ev.get("part_id", "")),
		str(ev.get("surface_id", ev.get("module_id", ev.get("crew_id", "")))),
	]


func _row_identity(ev: Dictionary) -> String:
	var kind: String = str(ev.get("kind", ""))
	var obj: String = str(ev.get("surface_id", ev.get("module_id", ev.get("crew_id", ""))))
	var part: String = str(ev.get("part_id", ""))
	var ent: String = str(ev.get("entity_id", ""))
	var extra := ""
	if kind == "armor" and ev.get("has_thickness", false):
		extra = "  %.0fmm" % float(ev.get("thickness_mm", 0.0))
	return "%s:%s:%s%s" % [ent, part, obj, extra]


func _occlusion_tag(ev: Dictionary) -> String:
	if _wall_enter_dist < 0.0:
		return ""
	var d: float = float(ev.get("distance_m", 0.0))
	if absf(d - _wall_enter_dist) <= 0.001:
		return "WALL"
	if d < _wall_enter_dist - 0.001:
		return "<wall"
	return ">wall"


# ---------------------------------------------------------------- 世界标记

func _ensure_world_art() -> void:
	if _marker_holder == null:
		_marker_holder = Node3D.new()
		_marker_holder.name = "QueryDebugMarkers"
		main.add_child(_marker_holder)
	if _segment_line == null:
		_segment_line = MeshInstance3D.new()
		_segment_line.name = "QueryDebugSegment"
		var m := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = COLOR_SEGMENT
		_segment_line.mesh = m
		_segment_line.material_override = mat
		_segment_line.top_level = true
		_segment_line.layers = 1
		_marker_holder.add_child(_segment_line)


func _spawn_world_marker(ev: Dictionary, run: int) -> int:
	_ensure_world_art()
	_marker_seq += 1
	var mi := MeshInstance3D.new()
	var sphere: PrimitiveMesh
	var is_wall := str(ev.get("kind", "")) == "wall"
	if is_wall:
		var b := BoxMesh.new()
		b.size = Vector3(0.26, 0.26, 0.26)
		sphere = b
	else:
		var s := SphereMesh.new()
		s.radius = 0.14
		s.height = 0.28
		sphere = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _event_color(ev)
	sphere.material = mat
	mi.mesh = sphere
	mi.material_override = mat
	mi.top_level = true
	mi.layers = 1
	_marker_holder.add_child(mi)   # 先入树再设世界位置（未入树节点读不到 global_transform）
	mi.global_position = ev.get("point_world", Vector3.ZERO)
	mi.set_meta("seq", _marker_seq)
	mi.set_meta("run", run)
	mi.set_meta("base_scale", 1.0)
	_markers.append({"seq": _marker_seq, "mi": mi, "ev": ev, "run": run, "base_scale": 1.0})
	return _marker_seq


func _event_color(ev: Dictionary) -> Color:
	match str(ev.get("kind", "")):
		"wall":
			return COLOR_WALL_ENTER if str(ev.get("event_type", "")) != "exit" else COLOR_WALL_EXIT
		"module":
			return COLOR_MODULE_ENTER if str(ev.get("event_type", "")) != "exit" else COLOR_MODULE_EXIT
		"crew":
			return COLOR_CREW_ENTER if str(ev.get("event_type", "")) != "exit" else COLOR_CREW_EXIT
		_:
			return COLOR_ARMOR


func _draw_marker_as(m: Dictionary, color: Color, scale: float) -> void:
	var mi = m.get("mi", null)
	if mi == null or not is_instance_valid(mi):
		return
	var mat := mi.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = color
	mi.scale = Vector3.ONE * scale


func _draw_segment_line() -> void:
	if _segment_line == null or _segment_line.mesh == null:
		return
	var im := _segment_line.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(_from_world)
	im.surface_add_vertex(_to_world)
	im.surface_end()
	_segment_line.visible = true


func _clear_segment_line() -> void:
	if _segment_line != null and _segment_line.mesh != null:
		(_segment_line.mesh as ImmediateMesh).clear_surfaces()
		_segment_line.visible = false


# ---------------------------------------------------------------- 状态/陈旧

func _pose_hash() -> int:
	var parts: Array = []
	for s in main.query_snapshots():
		var t: Transform3D = s.get("part_world_transforms", {}).get("hull", Transform3D.IDENTITY)
		parts.append("%s:%.3f,%.3f,%.3f|%.3f,%.3f,%.3f,%.3f" % [
			str(s.get("entity_id", "")),
			t.origin.x, t.origin.y, t.origin.z,
			t.basis.get_rotation_quaternion().x,
			t.basis.get_rotation_quaternion().y,
			t.basis.get_rotation_quaternion().z,
			t.basis.get_rotation_quaternion().w,
		])
	return hash(",".join(parts))


func _process(_delta: float) -> void:
	if main == null or _runs == 0 or _stale:
		return
	if _pose_hash() != _last_pose_hash:
		_stale = true
		for m in _markers:
			if int(m.get("run", 0)) == _runs:
				_draw_marker_as(m, COLOR_STALE, float(m.get("base_scale", 1.0)))
		_update_status(_last_result, _wall_compute_for_status())


func _wall_compute_for_status() -> Array:
	# 状态展示需要"是否有墙"与"墙交点"，不重算成本敏感路径——直接重算（面板打开期间单次）
	if _wall == null:
		return []
	return _compute_wall_crossings()


func _update_status(qr: Dictionary, wall_crossings: Array) -> void:
	var lines: Array[String] = []
	var ok: bool = qr.get("ok", false)
	lines.append("Run #%d · %s · complete=%s · events=%d%s" % [
		_runs, "ok" if ok else "FAILED",
		"yes" if qr.get("complete", false) else "no",
		_merged_events.size(),
		"  world_stop: none (GEOMETRY ONLY)" if _wall == null else "",
	])
	if _wall != null:
		if wall_crossings.is_empty():
			lines.append("test wall: box present, segment misses it")
		else:
			var types: Array[String] = []
			for wc in wall_crossings:
				types.append(str(wc.get("event_type", "")))
			lines.append("test wall: enter %.2fm (%s)" % [_wall_enter_dist, ", ".join(types)])
	if _stale:
		lines.append("STALE — pose changed since this run (markers dimmed); Run Query again.")
	var diag: Array = qr.get("diagnostics", [])
	if diag.size() > 0:
		lines.append("diagnostics:")
		for d in diag:
			lines.append("  %s" % str(d))
	if not ok:
		var diag_parts: Array[String] = []
		for d in diag:
			diag_parts.append(str(d))
		lines.append("query failed: " + ", ".join(diag_parts))
	_status.text = "\n".join(lines)
	_apply_row_tags()


func _apply_row_tags() -> void:
	# 行文字追加遮挡标记（<wall / >wall / WALL）
	for i in _row_meta.size():
		var tag: String = str(_row_meta[i].get("tag", ""))
		if tag.is_empty():
			continue
		var row_text: String = _results.get_item_text(i)
		_results.set_item_text(i, "%s  [%s]" % [row_text, tag])


# ---------------------------------------------------------------- 交互

func _on_vehicle_selected(index: int) -> void:
	_vehicle_filter = _vehicle_opt.get_item_text(index)


func _on_probe_selected(index: int) -> void:
	_probe = PROBES[index][0]
	_refresh_segment_labels()


func _refresh_segment_labels() -> void:
	if _from_label == null:
		return
	var seg := _probe_segment()
	_from_label.text = "from: %s" % _fmt(seg[0])
	_to_label.text = "to:   %s" % _fmt(seg[1])


func _fmt(v: Vector3) -> String:
	return "%.2f, %.2f, %.2f" % [v.x, v.y, v.z]


func _on_options_changed(_v: bool) -> void:
	_include_modules = _mod_check.button_pressed
	_include_crew = _crew_check.button_pressed


func _on_wall_fields(_t: String) -> void:
	var wpx := find_child("WallPos", true, false) as LineEdit
	var wss := find_child("WallSize", true, false) as LineEdit
	var wyd := find_child("WallYaw", true, false) as LineEdit
	if wpx != null:
		_wall_pos = _parse_vec3(wpx.text, _wall_pos)
	if wss != null:
		_wall_size = _parse_vec3(wss.text, _wall_size)
	if wyd != null:
		var v: float = _wall_yaw_deg
		if wyd.text.strip_edges().is_valid_float():
			v = float(wyd.text.strip_edges())
		_wall_yaw_deg = v


func _on_wall_pressed() -> void:
	if _wall == null:
		add_wall()
	else:
		remove_wall()


func _on_row_selected(index: int) -> void:
	if index < 0 or index >= _row_meta.size():
		return
	var meta: Dictionary = _row_meta[index]
	var seq: int = int(meta.get("index", -1))
	if _highlighted != null and is_instance_valid(_highlighted):
		_reset_marker_appearance(_highlighted)
	_highlighted = null
	if seq > 0:
		for m in _markers:
			if int(m.get("seq", 0)) == seq:
				var mi = m.get("mi", null)
				if mi != null and is_instance_valid(mi):
					_draw_marker_as(m, COLOR_HIGHLIGHT, float(m.get("base_scale", 1.0)) * 1.6)
					_highlighted = mi
				break
	_detail.text = _detail_text(meta.get("event", {}))


func _reset_marker_appearance(mi: MeshInstance3D) -> void:
	# 回到该标记运行时的颜色（当前运行=亮色；非当前运行=陈旧灰）
	for m in _markers:
		if m.get("mi", null) == mi:
			var run: int = int(m.get("run", 0))
			var color: Color = COLOR_STALE if (run != _runs or _stale) else _event_color(m.get("ev", {}))
			_draw_marker_as(m, color, float(m.get("base_scale", 1.0)))
			return


func _detail_text(ev: Dictionary) -> String:
	if ev.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("event #: kind=%s type=%s" % [str(ev.get("kind", "")), str(ev.get("event_type", ""))])
	lines.append("entity=%s part=%s item=%s" % [str(ev.get("entity_id", "")), str(ev.get("part_id", "")),
		str(ev.get("surface_id", ev.get("module_id", ev.get("crew_id", ""))))])
	lines.append("point=%s  normal=%s%s" % [_fmt(ev.get("point_world", Vector3.ZERO)), _fmt(ev.get("normal_world", Vector3.ZERO)),
		"" if ev.get("normal_known", false) else " (unknown)"])
	if ev.get("at_start", false) or ev.get("at_end", false) or ev.get("on_edge", false):
		lines.append("flags: %s%s%s" % [
			"at_start " if ev.get("at_start", false) else "",
			"at_end " if ev.get("at_end", false) else "",
			"on_edge" if ev.get("on_edge", false) else "",
		])
	if ev.get("kind", "") == "armor":
		if ev.get("has_thickness", false):
			lines.append("thickness=%.1fmm (%s) material=%s" % [float(ev.get("thickness_mm", 0.0)),
				str(ev.get("thickness_status", "")), str(ev.get("material_kind", ""))])
		else:
			lines.append("thickness=UNKNOWN material=%s" % str(ev.get("material_kind", "")))
	return "\n".join(lines)


func _refresh_vehicle_list() -> void:
	if _vehicle_opt == null or main == null:
		return
	var current := "ALL"
	if _vehicle_opt.item_count > 0:
		current = _vehicle_opt.get_item_text(_vehicle_opt.selected)
	_vehicle_opt.clear()
	_vehicle_opt.add_item("ALL")
	for s in main.query_snapshots():
		var eid: String = str(s.get("entity_id", ""))
		var dup := false
		for i in range(1, _vehicle_opt.item_count):
			if _vehicle_opt.get_item_text(i) == eid:
				dup = true
				break
		if not dup:
			_vehicle_opt.add_item(eid)
	var found := false
	for i in _vehicle_opt.item_count:
		if _vehicle_opt.get_item_text(i) == current:
			_vehicle_opt.select(i)
			found = true
			break
	if not found:
		_vehicle_opt.select(0)
		_vehicle_filter = "ALL"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
