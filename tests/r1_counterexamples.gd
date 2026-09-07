# 004-R1 前置：GPT 要求"先保存当前相机、控件重叠、实际车体边界的可重复反例，再修复"。
# 运行：godot --headless --path <root> -s res://tests/r1_counterexamples.gd
# 输出 docs/evidence/004-R1/counterexamples.json + 控制台摘要。本脚本只读现状，不改任何东西。

extends SceneTree

var _out := {}


func _init() -> void:
	_cam_counterexample()
	await process_frame
	await process_frame
	await _widget_counterexample()
	await _hole_counterexample()
	var f := FileAccess.open("res://docs/evidence/004-R1/counterexamples.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_out, "  "))
	f.close()
	print("COUNTEREXAMPLES_SAVED")
	quit(0)


func _cam_counterexample() -> void:
	# 当前 _update_camera 公式逐字复算（scripts/inspection/vehicle_inspector.gd）：
	# offset = Vector3(cos(pitch)*sin(yaw), sin(pitch), cos(pitch)*cos(yaw)) * dist
	# camera.position = target + offset; look_at(target=Vector3.ZERO)
	var yaw := 35.0
	var dist := 9.0
	var rows := []
	for pitch in [0.0, 18.0, -18.0]:
		var offset := Vector3(
			cos(deg_to_rad(pitch)) * sin(deg_to_rad(yaw)),
			sin(deg_to_rad(pitch)),
			cos(deg_to_rad(pitch)) * cos(deg_to_rad(yaw))) * dist
		rows.append({
			"pitch_deg": pitch,
			"camera_pos": str(Vector3.ZERO + offset),
			"camera_y": offset.y,
			"below_ground_plane_y_minus_002": offset.y < -0.02,
			"look_target": "(0, 0, 0) (ground origin; vehicle body spans y 0..3.375, mass center ~y 1.2)",
		})
	_out["camera"] = {
		"claim": "orbit pitch -18 deg places camera below the ground plane (y=-0.02) that the preview adds; the ground mesh occludes the vehicle from below; focus point is the ground origin instead of the model center",
		"ground_plane_y": -0.02,
		"rows": rows,
	}


func _widget_counterexample() -> void:
	# 当前绝对坐标布局（vehicle_inspector.gd _build_ui）的模式按钮/姿态控件 rect 交叠。
	var modes_row := Rect2(24, 166, 3 * 100, 32)          # HBox 3 按钮，每个 custom_minimum 100x32
	var yaw_label := Rect2(24, 170, 0, 0)                  # Label "Turret yaw:" position (24,170)
	var yaw_slider := Rect2(24, 192, 320, 24)              # HSlider position (24,192)
	var pitch_label := Rect2(24, 222, 0, 0)
	var pitch_slider := Rect2(24, 244, 320, 24)
	_out["widget_overlap"] = {
		"claim": "mode buttons row (y 166..198) overlaps yaw label (y 170) and yaw slider (y 192..216); slider row ends y=216 > 198 so button row also crosses slider",
		"modes_row": str(modes_row),
		"yaw_label_y": yaw_label.position.y,
		"yaw_slider": str(yaw_slider),
		"modes_row_intersects_yaw_slider": modes_row.intersects(yaw_slider),
		"pitch_label_y": pitch_label.position.y,
		"pitch_slider": str(pitch_slider),
	}


func _hole_counterexample() -> void:
	# 当前 M4A3 布局逐部件边界复核：侧面折点缺口。
	var layout := LayoutCatalog.load_layout("us_m4a3_75w_vvss_1944")
	if layout == null:
		_out["hull_boundary"] = {"error": "layout not loaded (register evidence first)"}
		return
	var per_part := {}
	for part in layout.parts:
		if part == null:
			continue
		var verts := PackedVector3Array()
		var tris := PackedInt32Array()
		var vbase := 0
		for patch in layout.armor_patches:
			if patch == null or patch.part_id != part.id:
				continue
			for v in patch.vertices_local_m:
				verts.append(v)
			for t in patch.triangles:
				tris.append(t + vbase)
			vbase += patch.vertices_local_m.size()
		if tris.is_empty():
			continue
		per_part[part.id] = {
			"vertex_count": verts.size(),
			"boundary_edges": check_edge_adjacency(verts, tris),
		}
	_out["hull_boundary"] = {
		"claim": "hull side plates skip the front-upper fold vertex (-1.15, 1.0, -2.95); each side has a triangular gap between the side plate edge and the two front plates (~0.25 m^2)",
		"fold_vertex_left": "(-1.15, 1.00, -2.95)",
		"parts": per_part,
	}


func check_edge_adjacency(vertices: PackedVector3Array, triangles: PackedInt32Array) -> Array:
	# 与 LayoutValidator.check_edge_adjacency 相同统计，返回边界边端点坐标对（便于人工核对缺口）。
	var problems := []
	var forward := {}
	for start in range(0, triangles.size(), 3):
		for offset in range(3):
			var a := triangles[start + offset]
			var b := triangles[start + ((offset + 1) % 3)]
			var fwd_key := "%d:%d" % [a, b]
			var bwd_key := "%d:%d" % [b, a]
			forward[fwd_key] = int(forward.get(fwd_key, 0)) + 1
			forward[bwd_key] = int(forward.get(bwd_key, 0)) + 0
	var seen := {}
	for fwd_key in forward.keys():
		var pp := (fwd_key as String).split(":")
		var a := int(pp[0])
		var b := int(pp[1])
		var bwd_key := "%d:%d" % [b, a]
		if seen.has(fwd_key) or seen.has(bwd_key):
			continue
		seen[fwd_key] = true
		seen[bwd_key] = true
		var f := int(forward.get(fwd_key, 0))
		var r := int(forward.get(bwd_key, 0))
		if f != 1 or r != 1:
			problems.append({
				"edge": fwd_key,
				"forward_count": f,
				"reverse_count": r,
				"a": str(vertices[a]),
				"b": str(vertices[b]),
			})
	return problems