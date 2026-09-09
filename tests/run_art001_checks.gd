extends SceneTree
## ART-001 单车高低模烘焙试产自动检查（T-ART-01..08）。
## 运行: godot --headless --path <工程根> -s res://tests/run_art001_checks.gd
## 失败时退出码非 0，并打印全部 [PASS]/[FAIL] 明细。
## 贴图微调不需要重跑全套（见交付文档）。

const DIR := "res://assets/art001/m4a3_pilot/"
const TOL_PLANE_M := 0.01   # 装甲平面 ≤1cm
const TOL_PIVOT_M := 0.001  # 炮塔/耳轴/炮口枢轴 ≤1mm
const TOL_AXIS_RAD := 0.001745  # 轴向 ≤0.1°

var fails: Array[String] = []
var count := 0

func _initialize() -> void:
	var wd := create_timer(120.0)
	wd.timeout.connect(func() -> void:
		print("[WATCHDOG] 120s 超时，强制退出")
		quit(2))
	call_deferred("_run")

func _ok(cond: bool, label: String) -> void:
	count += 1
	if cond:
		print("[PASS] " + label)
	else:
		fails.append(label)
		print("[FAIL] " + label)

func _run() -> void:
	print("=== ART-001 烘焙试产检查 ===")
	print("engine=", Engine.get_version_info()["string"], "  os=", OS.get_name())
	var manifest := _load_manifest()
	_t01_budget(manifest)
	_t02_bake_validity(manifest)
	_t03_material_channels()
	_t04_fair_compare()
	_t05_visible_quality()
	await _t06_game_compat(manifest)
	_t07_runtime_assets(manifest)
	_t08_cost(manifest)
	print("=== 结果: %d 项, %d 失败 ===" % [count, fails.size()])
	_finish()

func _finish() -> void:
	quit(0 if fails.is_empty() else 1)

func _load_manifest() -> Dictionary:
	var f := FileAccess.open(DIR + "manifest.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func _img(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))

func _t01_budget(manifest: Dictionary) -> void:
	var budget: Dictionary = manifest.get("budget", {})
	var tris := int(budget.get("blender_low_tris", -1))
	_ok(tris > 0 and tris <= 1000, "T-ART-01 低模三角面 ≤1000（实际 %d）" % tris)
	# 三向一致：manifest ↔ Godot 导入
	var scene := load(DIR + "m4a3_1k.glb") as PackedScene
	_ok(scene != null, "T-ART-01 烘焙 GLB 可加载")
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	var godot_tris := 0
	var stack := [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					godot_tris += _surface_tris(mi.mesh, s)
		for c in n.get_children():
			stack.push_back(c)
	_ok(godot_tris == tris, "T-ART-01 GLB 导入三角面与 Blender 记录一致（%d vs %d）" % [godot_tris, tris])
	inst.free()

func _surface_tris(mesh: Mesh, s: int) -> int:
	var arrays := mesh.surface_get_arrays(s)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() > 0:
		return idx.size() / 3
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return verts.size() / 3

func _t02_bake_validity(manifest: Dictionary) -> void:
	var nrm := _img(DIR + "normal_gl.png")
	_ok(nrm != null, "T-ART-02 法线贴图存在")
	if nrm == null:
		return
	_ok(nrm.get_width() == 1024 and nrm.get_height() == 1024, "T-ART-02 法线 1024×1024")
	# 非均匀：真烘焙法线应有偏离平色的细节像素，且切线分量双向分布
	var flat := 0
	var pos := 0
	var neg := 0
	var total := 0
	var step := 7
	for y in range(0, nrm.get_height(), step):
		for x in range(0, nrm.get_width(), step):
			var c := nrm.get_pixel(x, y)
			total += 1
			if absf(c.r - 0.5) < 0.02 and absf(c.g - 0.5) < 0.02 and absf(c.b - 1.0) < 0.02:
				flat += 1
			else:
				if c.r > 0.55: pos += 1
				if c.r < 0.45: neg += 1
	var detail_pct := 100.0 * float(total - flat) / float(maxi(total, 1))
	_ok(detail_pct > 2.0, "T-ART-02 法线含真实烘焙细节（细节占比 %.1f%% > 2%%）" % detail_pct)
	_ok(pos > 0 and neg > 0, "T-ART-02 切线分量双向分布（+%d/-%d 采样点）" % [pos, neg])
	var ao := _img(DIR + "orm.png")
	_ok(ao != null, "T-ART-02 ORM 贴图存在")
	_ok(FileAccess.file_exists("res://authoring/art001/uv_layout.png"), "T-ART-02 UV 布局图存在")
	var maps: Dictionary = manifest.get("maps", {})
	_ok(int(maps.get("size", 0)) == 1024, "T-ART-02 图集尺寸记录 1024")

func _t03_material_channels() -> void:
	var orm := _img(DIR + "orm.png")
	_ok(orm != null, "T-ART-03 ORM 贴图可读")
	if orm == null:
		return
	var r_sum := 0.0
	var g_sum := 0.0
	var b_sum := 0.0
	var n := 0
	for y in range(0, orm.get_height(), 5):
		for x in range(0, orm.get_width(), 5):
			var c := orm.get_pixel(x, y)
			r_sum += c.r
			g_sum += c.g
			b_sum += c.b
			n += 1
	var r_mean := r_sum / n
	var g_mean := g_sum / n
	var b_mean := b_sum / n
	_ok(r_mean > 0.3 and r_mean < 1.05, "T-ART-03 R=AO 均值合理（%.2f）" % r_mean)
	_ok(g_mean > 0.2 and g_mean <= 1.0, "T-ART-03 G=Roughness 均值合理（%.2f）" % g_mean)
	_ok(b_mean < g_mean, "T-ART-03 B=Metallic 低于 Roughness（%.2f < %.2f，无整体裸金属）" % [b_mean, g_mean])

func _t04_fair_compare() -> void:
	var a := BakeComparison.material_for("A")
	var b := BakeComparison.material_for("B")
	var c := BakeComparison.material_for("C")
	_ok(not b.normal_enabled and not c.normal_enabled == false, "T-ART-04 变体存在")
	_ok(b.albedo_texture != null and c.albedo_texture != null and b.albedo_texture == c.albedo_texture, "T-ART-04 B/C 共享同一 BaseColor")
	_ok(not b.normal_enabled, "T-ART-04 B 无法线（公平对照）")
	_ok(c.normal_enabled, "T-ART-04 C 有法线")
	_ok(c.roughness_texture == b.roughness_texture and c.ao_texture == b.ao_texture, "T-ART-04 B/C 的 ORM 完全一致")

func _t05_visible_quality() -> void:
	var scene := load(DIR + "m4a3_1k.glb") as PackedScene
	if scene == null:
		_ok(false, "T-ART-05 GLB 可加载")
		return
	var inst := scene.instantiate() as Node3D
	var meshes := []
	var stack := [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes.append(n)
		for ch in n.get_children():
			stack.push_back(ch)
	var m_c := BakeComparison.set_variant(meshes, "C")
	var all_set := true
	for mi in meshes:
		if (mi as MeshInstance3D).material_override != m_c:
			all_set = false
	_ok(all_set and meshes.size() > 0, "T-ART-05 同一几何上 C 变体应用到全部 %d 个网格" % meshes.size())
	inst.free()

func _t06_game_compat(manifest: Dictionary) -> void:
	# 真实主场景 + 真实内容管线 + 真实射击代码
	var ps: PackedScene = load("res://scenes/main.tscn")
	_ok(ps != null, "T-ART-06 主场景可加载")
	if ps == null:
		return
	var main = ps.instantiate()
	root.add_child(main)
	await process_frame
	_ok(main.tank != null and main.turret != null, "T-ART-06 真实 actor 就绪")
	var catalog := VehicleCatalog.new()
	var defs := VehicleDefs.new()
	var loaded: Dictionary = catalog.load_all(defs)
	_ok(bool(loaded.get("ok", false)), "T-ART-06 历史车辆包加载")
	if not bool(loaded.get("ok", false)):
		for e in loaded.get("errors", []):
			print("  catalog: ", e)
		main.queue_free()
		return
	var id := "us_m4a3_75w_vvss_1944"
	var packet: Dictionary = defs.content_packets[id]
	var layout = defs.layouts.values()[0]
	var actor := VehicleActor.new()
	actor.name = "Art001TestActor"
	main.add_child(actor)
	var res: Dictionary = actor.setup(defs, id, "art001-test", 1, Transform3D(Basis(), Vector3(0, 0, 8)), 2, null)
	_ok(bool(res.get("ok", false)), "T-ART-06 真实 setup 成功")
	if not bool(res.get("ok", false)):
		actor.queue_free()
		main.queue_free()
		return
	# 接入 main 的飞弹管理器（与真实射管一致）
	actor.gunner.projectile_manager = main.projectiles
	actor.gunner.round_provider = Callable(main, "get_round_id")
	actor.gunner.snapshot_provider = Callable(main, "query_snapshots")
	# 枢轴/轴向校验（烘焙 GLB 节点 vs packet 几何）
	var glb := load(DIR + "m4a3_1k.glb") as PackedScene
	var src := glb.instantiate() as Node3D
	var g: Dictionary = packet.geometry
	var turret_node := src.find_child("turret", true, false)
	var barrel_node := src.find_child("barrel", true, false)
	_ok(turret_node != null and barrel_node != null, "T-ART-06 GLB 含 hull/turret/barrel 节点")
	if turret_node != null:
		var to := Vector3(float(g.turret_origin[0]), float(g.turret_origin[1]), float(g.turret_origin[2]))
		_ok(turret_node.position.distance_to(to) <= TOL_PIVOT_M, "T-ART-06 炮塔枢轴 ≤1mm（%.4fmm）" % (turret_node.position.distance_to(to) * 1000.0))
		_ok(turret_node.rotation.length() <= TOL_AXIS_RAD, "T-ART-06 炮塔轴向 ≤0.1°")
	if barrel_node != null:
		var go := Vector3(float(g.gun_origin[0]), float(g.gun_origin[1]), float(g.gun_origin[2]))
		_ok(barrel_node.position.distance_to(go) <= TOL_PIVOT_M, "T-ART-06 火炮枢轴 ≤1mm（%.4fmm）" % (barrel_node.position.distance_to(go) * 1000.0))
	src.free()
	# 漏件反例：注入缺 LOW_barrel_Shell 的名单必须在动原车前被拒绝，节点数不变
	var bad_wl := {
		"hull": ["LOW_hull_Shell", "LOW_hull_Hatches", "LOW_wheels", "LOW_tracks"],
		"turret": ["LOW_turret_Shell", "LOW_turret_Cupola"],
		"barrel": ["LOW_gun_Tube"],
	}
	var adapter_bad := BakedVisualAdapter.new()
	var nb0 := _count_descendants(actor)
	var rbad: Dictionary = adapter_bad.bind(actor, bad_wl)
	_ok(not bool(rbad.get("ok", false)), "T-ART-06 漏件名单被拒绝（%s）" % str(rbad.get("error", "-")))
	_ok(_count_descendants(actor) == nb0, "T-ART-06 漏件拒绝未动原车（节点 %d）" % _count_descendants(actor))
	# 绑定适配器：先自然开火一次（不清冷却）；待首射特效惰性节点稳定后记录基准
	var adapter := BakedVisualAdapter.new()
	var gunner = actor.gunner
	var f0: bool = gunner.try_fire()
	_ok(f0, "T-ART-06 绑定前自然开火成功（%s）" % str(gunner.blocked_reason))
	await process_frame
	await process_frame
	var nodes_pristine := _count_descendants(actor)
	var bind_res: Dictionary = adapter.bind(actor)
	_ok(bool(bind_res.get("ok", false)), "T-ART-06 适配器绑定成功")
	_ok(int(bind_res.get("hidden", 0)) > 0, "T-ART-06 程序装配视觉已隐藏（%d 个）" % int(bind_res.get("hidden", 0)))
	# 导入集合与导出清单一致（精确校验，非 added>=5）
	var expect_names := ["LOW_hull_Shell", "LOW_hull_Hatches", "LOW_wheels", "LOW_tracks", "LOW_turret_Shell", "LOW_turret_Cupola", "LOW_gun_Tube", "LOW_barrel_Shell"]
	var got_names := []
	for mi3 in adapter.mesh_instances():
		got_names.append(str(mi3.name))
	got_names.sort()
	var expect_sorted := expect_names.duplicate()
	expect_sorted.sort()
	_ok(got_names == expect_sorted, "T-ART-06 导入集合=导出清单（%d 网格无漏件/错件/重复）" % got_names.size())
	# 候选三角数 = 装甲忠实壳体（884：壳体按 Armor 扇形完整重建，含炮塔顶盖；
	# 旧 774 因壳体构建器只取每块 Armor 网格前 4 顶点而丢失顶盖/多边形板，属欠数）
	var tris := adapter.candidate_tri_count()
	_ok(tris == 884, "T-ART-06 候选三角数=884 装甲忠实（实际 %d）" % tris)
	# 整车可见几何审计：无旧外观残留（不存在两套外观叠加）
	var leftovers: Array[String] = BakedVisualAdapter.audit_no_leftover(actor)
	_ok(leftovers.is_empty(), "T-ART-06 整车无残留旧外观（%s）" % str(leftovers))
	# 后坐接线结构：recoil_visual = 独立后坐子节点（只装炮管），炮盾留在俯仰容器
	var rv := actor.turret.recoil_visual
	_ok(rv != null and str(rv.name) == "BakedPilotGunRecoil" and (rv.get_parent() != null and str(rv.get_parent().name) == "BakedPilotVisual_barrel"),
		"T-ART-06 后坐子节点层级正确（BakedPilotVisual_barrel/BakedPilotGunRecoil）")
	# 变体切换确实覆盖绑定网格（先设 B 验证覆盖，再设 C 供对照）
	var b_meshes := adapter.mesh_instances()
	var m_set: StandardMaterial3D = BakeComparison.set_variant(b_meshes, "B")
	var all_covered := b_meshes.size() > 0
	for mi2 in b_meshes:
		if (mi2 as MeshInstance3D).material_override != m_set:
			all_covered = false
	BakeComparison.set_variant(b_meshes, "C")
	_ok(all_covered, "T-ART-06 变体切换覆盖全部绑定网格（%d 个）" % b_meshes.size())
	# 自然冷却循环：绑定后立即再开火应被冷却挡下，等待自然装填后可再开火
	var f2: bool = gunner.try_fire()
	_ok(not f2 and gunner.blocked_reason == "cooldown", "T-ART-06 绑定后冷却自然生效（%s）" % str(gunner.blocked_reason))
	for i in range(500):
		await physics_frame
	# 后坐运动关系（真实开火触发）：以 BarrelPivot 为基准比较相对变换
	var tube := adapter.mesh_instances().filter(func(m): return str(m.name) == "LOW_gun_Tube")
	var shell := adapter.mesh_instances().filter(func(m): return str(m.name) == "LOW_barrel_Shell")
	_ok(tube.size() == 1 and shell.size() == 1, "T-ART-06 炮管/炮盾网格各就位")
	var pivot_inv := actor.turret.barrel_pivot.global_transform.affine_inverse()
	var tube_rel0 := pivot_inv * (tube[0] as MeshInstance3D).global_transform
	var shell_rel0 := pivot_inv * (shell[0] as MeshInstance3D).global_transform
	var muzzle_rel0 := pivot_inv * actor.turret.muzzle.global_transform
	var f3: bool = gunner.try_fire()
	_ok(f3, "T-ART-06 自然装填后再次开火成功（cd=%.2f %s）" % [gunner.cooldown_left, str(gunner.blocked_reason)])
	await physics_frame
	var tube_rel1 := pivot_inv * (tube[0] as MeshInstance3D).global_transform
	var shell_rel1 := pivot_inv * (shell[0] as MeshInstance3D).global_transform
	var muzzle_rel1 := pivot_inv * actor.turret.muzzle.global_transform
	_ok(tube_rel1.origin.z > tube_rel0.origin.z + 0.05, "T-ART-06 真实开火候选炮管后坐（Δz=%.3f）" % (tube_rel1.origin.z - tube_rel0.origin.z))
	_ok(shell_rel0.origin.distance_to(shell_rel1.origin) < 0.001, "T-ART-06 炮盾不随炮管后坐（Δ=%.5f m）" % shell_rel0.origin.distance_to(shell_rel1.origin))
	_ok(muzzle_rel0.origin.distance_to(muzzle_rel1.origin) < 0.001, "T-ART-06 炮口/查询部件不因视觉后坐改变")
	# 后坐自然回零
	for i in range(40):
		await physics_frame
	var tube_rel2 := pivot_inv * (tube[0] as MeshInstance3D).global_transform
	_ok(absf(tube_rel2.origin.z - tube_rel0.origin.z) < 0.01, "T-ART-06 候选炮管后坐自然回零（Δz=%.4f）" % absf(tube_rel2.origin.z - tube_rel0.origin.z))
	# 真实驾驶：经同一命令提交入口驱动（与控制者同一路径），绑定视觉下加速
	for i in range(150):
		var cmd := VehicleCommand.new()
		cmd.throttle = 1.0
		actor.submit_command(cmd)
		await physics_frame
	_ok(actor.tank.forward_speed > 4.0, "T-ART-06 绑定视觉下驾驶加速有效（v=%.2f）" % actor.tank.forward_speed)
	# 转炮+俯仰姿态下的对齐（烘焙部件须跟随部件节点运动）
	await physics_frame
	var align: Dictionary = BakedVisualAdapter.audit_alignment(adapter, actor, layout.armor_patches, TOL_PLANE_M, PI / 2.0, 0.17)
	_ok(bool(align.get("ok", false)), "T-ART-06 转炮90°/俯仰10°装配对齐 ≤1cm（worst=%s checked=%s err=%s）" % [str(align.get("worst_m", "NA")), str(align.get("checked", "NA")), str(align.get("error", "-"))])
	# 还原：容器清空 + 旧视觉恢复 + 节点数回到未绑定基准（真实状态检查，非无条件 PASS）
	var restore_res: Dictionary = adapter.restore(actor)
	await process_frame
	var nodes_restored := _count_descendants(actor)
	var skin_visible := true
	for child in actor.tank.get_children():
		if str(child.name).begins_with("Skin_"):
			skin_visible = skin_visible and (child as Node3D).visible
	_ok(bool(restore_res.get("ok", false)) and int(restore_res.get("removed_containers", 0)) == 3, "T-ART-06 适配器还原容器（%s）" % str(restore_res))
	_ok(adapter.mesh_instances().is_empty(), "T-ART-06 还原后无残留烘焙网格")
	_ok(skin_visible, "T-ART-06 还原后旧程序视觉恢复显示")
	_ok(nodes_restored == nodes_pristine, "T-ART-06 还原后节点数回到基准（%d → %d）" % [nodes_pristine, nodes_restored])
	# 连续绑定/还原十次：节点数不增长、状态可复
	var stable := true
	for cycle in range(10):
		var rb: Dictionary = adapter.bind(actor)
		if not bool(rb.get("ok", false)):
			stable = false
			break
		adapter.restore(actor)
		await process_frame
	var nodes_final := _count_descendants(actor)
	_ok(stable and nodes_final == nodes_pristine, "T-ART-06 绑定/还原×10 节点数稳定（基准 %d → 最终 %d）" % [nodes_pristine, nodes_final])
	# 绑定态下重复绑定被拒绝且不破坏还原清单；正常还原后状态一致
	var rb2: Dictionary = adapter.bind(actor)
	var rb3: Dictionary = adapter.bind(actor)
	_ok(bool(rb2.get("ok", false)) and not bool(rb3.get("ok", false)), "T-ART-06 绑定态重复绑定被拒绝")
	var rr2: Dictionary = adapter.restore(actor)
	await process_frame
	_ok(bool(rr2.get("ok", false)) and _count_descendants(actor) == nodes_pristine, "T-ART-06 拒绝路径不破坏还原清单（节点 %d）" % _count_descendants(actor))
	actor.queue_free()
	main.queue_free()

func _count_descendants(node: Node) -> int:
	var count := 0
	var stack := [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		count += 1
		for ch in n.get_children():
			stack.push_back(ch)
	return count

func _t07_runtime_assets(manifest: Dictionary) -> void:
	_ok(manifest.has("glb_sha256") and manifest.has("basecolor_sha256"), "T-ART-07 manifest 记录 SHA256")
	var checks := {
		"glb_sha256": DIR + "m4a3_1k.glb",
		"basecolor_sha256": DIR + "basecolor.png",
		"normal_sha256": DIR + "normal_gl.png",
		"orm_sha256": DIR + "orm.png",
	}
	for key in checks:
		var expect := str(manifest.get(key, ""))
		if expect == "":
			_ok(false, "T-ART-07 manifest 缺少 " + key)
			continue
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path(checks[key]))
		_ok(actual == expect, "T-ART-07 %s 哈希一致" % checks[key])

func _t08_cost(manifest: Dictionary) -> void:
	var timings: Dictionary = manifest.get("bake_timings", {})
	_ok(timings.size() >= 24 and timings.size() % 4 == 0, "T-ART-08 烘焙计时记录完整（%d 遍）" % timings.size())
	var slow := 0.0
	for k in timings:
		slow = maxf(slow, float(timings[k]))
	_ok(slow < 60.0, "T-ART-08 单次烘焙 <60s（最长 %.1fs）" % slow)
	_ok(FileAccess.file_exists(DIR + "m4a3_1k.glb"), "T-ART-08 运行时资产在位")
	var total_tris := int(manifest.get("budget", {}).get("blender_low_tris", 0))
	print("T-ART-08 单车低模 %d 三角面（8 车约 %d 面，纯渲染帧率对比见交付文档）" % [total_tris, total_tris * 8])