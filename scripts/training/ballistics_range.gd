class_name BallisticsRange
extends Node3D
## 006：弹道训练场——复用生产车辆/Gunner/ProjectileManager/查询系统
## （不复制一套训练专用射击代码）。
## 近射道 30m、远射道 150m（炮口到接触面约值）；水平发射留足高度与目标尺寸，
## 地面与旧围墙不会先挡住射线。暂停菜单提供"返回靶场"；
## 两次切换都按新局处理（先清理飞弹，不携带旧轮次命中）。

const NEAR_Z := -30.0
const FAR_Z := -150.0

var defs: VehicleDefs
var selected_vehicle_id := "player_tank"
var historical_catalog: VehicleCatalog
var controller: PlayerController
var actor: VehicleActor
var projectiles: ProjectileManager
var hud: HUD
var replay: ReplayController
var _paused := false
var _initialized := false
var _last_impact: Dictionary = {}   # 006：最近飞弹终止（HUD 展示）
# --- 006-d 弹道演示状态 ---
var _demo := false
var _demo_dir := "docs/evidence/006/demo"
var _demo_step := 0
var _demo_wait := 0              # 自增物理 tick 等待（与渲染限帧无关；暂停期间 ALWAYS 仍走）
var _demo_ticks := 0             # 演示自增 tick（_physics_process 驱动）
var _demo_errors := 0
var _demo_saved := 0
var _demo_sample_a := {}         # 飞行中采样 A
var _demo_fps_sum := 0.0
var _demo_fps_n := 0
var _demo_flight_deltas: Array = []    # 006-R1-C：飞行窗口实际帧间隔（秒，覆盖主要飞行时段）
var _demo_flight_open := false
var _demo_capture_requests: Array = [] # 006-R1-C：待捕获（渲染完成后取帧 + 记录捕获时点状态）
var _demo_capturing := false
var _demo_board_base: Dictionary = {}  # 发射时各靶板 hit_count 基线（目标身份验证）
# --- 006-R1-C 射道切换与可见显示层 ---
var _boards: Dictionary = {}           # "NearBoard"/"FarBoard" -> TargetBoard
var _walls: Dictionary = {}            # "NearWall"/"FarWall" -> StaticBody3D
var _lane := "near"                    # 当前启用射道（T 键或演示切换；只启用对应目标与背墙）
var _terminated_pids: Dictionary = {}  # 已终止 projectile_id（HUD 在飞/已终止区分）
var projectile_visuals: ProjectileVisuals

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	defs = VehicleDefs.new()
	var lr := defs.load_defaults()
	if not lr.ok:
		push_error("ballistics: defs load failed: %s" % ", ".join(lr.errors))
		return
	if selected_vehicle_id in VehicleCatalog.IDS:
		historical_catalog = VehicleCatalog.new()
		var loaded := historical_catalog.load_all(defs)
		if not loaded.ok:
			push_error("historical content admission: "+", ".join(loaded.errors))
			return
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	actor = VehicleActor.new()
	actor.name = "ActorA"
	add_child(actor)
	var ra := actor.setup(defs, selected_vehicle_id, "A", 1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), GameConfig.VIS_LAYER_VEHICLE, controller)
	if not ra.ok:
		push_error("ballistics: actor setup failed: %s" % ", ".join(ra.errors))
		return
	projectiles = ProjectileManager.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	projectiles.snapshot_provider = Callable(self, "query_snapshots")
	projectiles.exclude_provider = Callable(self, "projectile_exclude_rids")
	projectiles.projectile_finished.connect(_on_projectile_finished)
	projectiles.damage_handler = Callable(self,"_apply_projectile_damage")
	projectiles.projectile_damage.connect(_on_projectile_damage)
	# 006-R1-C：飞弹可见显示层（只读模拟状态；不写回位置、不参与命中/计分）
	projectile_visuals = ProjectileVisuals.new()
	projectile_visuals.name = "ProjectileVisuals"
	add_child(projectile_visuals)
	actor.gunner.projectile_manager = projectiles
	actor.gunner.round_provider = Callable(self, "get_round_id")
	actor.gunner.snapshot_provider = Callable(self, "query_snapshots")
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_requested.connect(_resume)
	hud.training_requested.connect(_return_to_range)
	hud.armor_training_requested.connect(_open_armor_training)
	hud.damage_training_requested.connect(_open_damage_training)
	hud.recovery_training_requested.connect(_open_recovery_training)
	hud.set_training_button_text(false)   # 训练场按钮 = 返回靶场
	replay = ReplayController.new()
	add_child(replay)
	# These scenes are explicit training contexts. Future battle modes must supply their visibility policy.
	replay.setup(projectiles,hud,func(_record: Dictionary) -> bool: return true)
	_initialized = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 006-d：-- --ballistics-demo 弹道演示（同一训练装配 + 生产发射路径）
	var ua := OS.get_cmdline_user_args()
	_demo = ua.has("--ballistics-demo")
	for i in ua.size():
		if ua[i] == "--shot-dir" and i + 1 < ua.size():
			_demo_dir = ua[i + 1]
	if _demo:
		# 演示步进机跑在物理回调里（本节点优先级 200 > 管理器 100 → 看到推进后状态）；
		# 自增 tick 计数等待与渲染限帧（--max-fps）无关，暂停期间 ALWAYS 节点仍走。
		process_physics_priority = 200

func _build_world() -> void:
	# 地面：沿 -Z 长 180m（车辆在 z=0，靶板在 z=-30/-150，墙后 2m 背板）
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = GameConfig.LAYER_WORLD
	ground.collision_mask = 0
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(40.0, 0.5, 180.0)
	gcs.shape = gshape
	ground.add_child(gcs)
	var gmi := MeshInstance3D.new()
	var gmesh := BoxMesh.new()
	gmesh.size = gshape.size
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.4, 0.3)
	gmesh.material = gmat
	gmi.mesh = gmesh
	ground.add_child(gmi)
	ground.position = Vector3(0, -0.25, -80)
	add_child(ground)
	# 近/远靶板（接触面约 30m / 150m）
	_boards["NearBoard"] = _add_board(Vector3(0, 0, NEAR_Z), "NearBoard")
	_boards["FarBoard"] = _add_board(Vector3(0, 0, FAR_Z), "FarBoard")
	# 背板墙：挡住未中靶的飞弹（近 32m / 远 152m）
	_walls["NearWall"] = _add_wall(Vector3(0, 3.0, NEAR_Z - 2.0), Vector3(20.0, 6.0, 1.0))
	_walls["FarWall"] = _add_wall(Vector3(0, 3.0, FAR_Z - 2.0), Vector3(20.0, 6.0, 1.0))
	_set_lane("near")   # 006-R1-C：默认近靶道（T 键/演示切换近远靶，两条射道互不遮挡直射路线）
	# 光照与天空
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)

func _add_board(pos: Vector3, name: String) -> TargetBoard:
	var board := TargetBoard.new()
	board.name = name
	board.position = pos
	add_child(board)
	return board

func _add_wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.58, 0.6)
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	body.position = pos
	add_child(body)
	return body

func _set_lane(lane: String) -> void:
	# 006-R1-C：同一射击位切换近靶/远靶——只启用对应目标与背墙。
	# 修复：近靶+近背墙原先常驻，挡住远靶直射路线；切换后两条射道都可用。
	_lane = lane
	var near_on := lane == "near"
	_enable_node(_boards.get("NearBoard"), near_on)
	_enable_node(_boards.get("FarBoard"), not near_on)
	_enable_node(_walls.get("NearWall"), near_on)
	_enable_node(_walls.get("FarWall"), not near_on)

func _enable_node(n: Node3D, on: bool) -> void:
	# 禁用 = 隐藏 + 退出 WORLD 碰撞层（查询不再命中）；启用 = 恢复
	if n == null:
		return
	n.visible = on
	n.collision_layer = GameConfig.LAYER_WORLD if on else 0

func get_round_id() -> int:
	return 0   # 训练场无任务轮次（命中只反馈，不推进试射目标）

func query_snapshots() -> Array:
	var out: Array = []
	for c in get_children():
		if c is VehicleActor and c.tank != null and is_instance_valid(c.tank) and c.definition != null:
			var layout_id: String = c.definition.layout_id
			if layout_id.is_empty():
				continue
			var layout: VehicleLayoutDefinition = c.damage_layout_override if c.damage_layout_override != null else LayoutCatalog.load_layout(layout_id)
			if layout == null:
				continue
			out.append(QuerySnapshotBuilder.build_from_vehicle(c.tank, layout))
	return out

func projectile_exclude_rids(shooter_id: String, shooter_life_id: int) -> Array[RID]:
	if actor != null and actor.entity_id == shooter_id and actor.life_id == shooter_life_id \
			and actor.tank != null and is_instance_valid(actor.tank):
		return [actor.tank.get_rid()]
	return []

func _apply_projectile_damage(event: Dictionary, available_mm: float) -> Dictionary:
	if int(event.get("round_id",-1)) != get_round_id():
		return {"ok":false,"reason":"stale_round"}
	for child in get_children():
		if child is VehicleActor and child.entity_id == event.get("entity_id","") and child.life_id == int(event.get("life_id",0)):
			return child.apply_projectile_damage(event,available_mm)
	return {"ok":false,"reason":"missing_target"}

func _on_projectile_damage(record: Dictionary) -> void:
	for child in get_children():
		if child is VehicleActor and child.entity_id == record.get("target_id","") and child.life_id == int(record.get("target_life_id",0)):
			child.present_damage_record(record)

func _on_projectile_finished(record: Dictionary) -> void:
	# 006-R1-C：登记已终止 projectile_id（HUD 结束 IN FLIGHT）+ 可见层在真实终止位置收尾
	_terminated_pids[int(record.get("projectile_id", 0))] = true
	if projectile_visuals != null:
		projectile_visuals.present_terminal(record)
	if _demo and _demo_flight_open:
		_demo_flight_open = false
		var n := _demo_flight_deltas.size()
		if n > 0:
			var total := 0.0
			var mn := 1.0e9
			var mx := 0.0
			for d in _demo_flight_deltas:
				total += float(d)
				mn = minf(mn, float(d))
				mx = maxf(mx, float(d))
			print("[bdemo] flight window: idle_frames=%d avg_fps=%.1f min_fps=%.1f max_fps=%.1f span=%.3fs" % [n, float(n) / maxf(total, 1.0e-6), 1.0 / maxf(mx, 1.0e-6), 1.0 / maxf(mn, 1.0e-6), total])
	var reason: String = str(record.get("reason", ""))
	var reason_upper := "EXPIRED"
	match reason:
		"impact_vehicle":
			reason_upper = "VEHICLE"
		"impact_world":
			reason_upper = "WORLD"
		"expired_time", "expired_distance":
			reason_upper = "EXPIRED"
		"unresolved_query":
			reason_upper = "UNRESOLVED"
		"cancelled_reset", "cancelled_scene_exit":
			reason_upper = "CANCELLED"
	_last_impact = {
		"shot_id": int(record.get("shot_id", 0)),
		"reason_upper": reason_upper,
		"impact_point": record.get("impact_point", Vector3.ZERO),
		"flight_time_s": float(record.get("flight_time_s", 0.0)),
		"travelled_m": float(record.get("travelled_m", 0.0)),
	}
	if _demo:
		print("[bdemo] finish record: proj=%d shot=%d reason=%s travelled=%.3fm t=%.4fs point=%s detail=%s" % [
			int(record.get("projectile_id", 0)), int(record.get("shot_id", 0)), reason,
			float(record.get("travelled_m", 0.0)), float(record.get("flight_time_s", 0.0)),
			str(record.get("impact_point", Vector3.ZERO)), str(record.get("detail", ""))])

func _process(delta: float) -> void:
	# 演示收尾段实际渲染帧率采样（飞行窗口另有逐帧间隔记录，见 _on_projectile_finished）
	if _demo and _demo_step >= 34 and _demo_fps_n < 60:
		_demo_fps_sum += float(Engine.get_frames_per_second())
		_demo_fps_n += 1
	# 006-R1-C：飞行窗口实际帧间隔（从发射到终止的空闲帧 deltas，覆盖主要飞行时段）
	if _demo and _demo_flight_open:
		_demo_flight_deltas.append(delta)
	if projectile_visuals != null and projectiles != null:
		projectile_visuals.sync_projectiles(projectiles.active_states())
	# 006-R1-C：渲染完成后捕获（不在物理回调直读视口纹理），并记录捕获时点真实模拟状态
	if _demo and not _demo_capture_requests.is_empty() and not _demo_capturing:
		_demo_capturing = true
		_demo_pump_capture()
	if not _initialized or actor == null or hud == null:
		return
	var result_text := ""
	if actor.gunner.last_shot_result == "fired":
		# 006-R1-C：按 projectile_id 区分在飞/已终止——终止后不再显示 IN FLIGHT
		if actor.gunner.last_projectile_id > 0 and _terminated_pids.has(actor.gunner.last_projectile_id):
			result_text = "LAST SHOT: #%d TERMINATED" % actor.gunner.shot_id
		else:
			result_text = "LAST SHOT: #%d IN FLIGHT" % actor.gunner.shot_id
	elif actor.gunner.last_shot_result != "":
		result_text = "LAST SHOT: BLOCKED (%s)" % actor.gunner.blocked_reason.to_upper()
	var lane_text := "LANE: %s (T to toggle)" % _lane.to_upper()
	var ammo_text := "AMMO: %d/%d" % [actor.gunner.rounds_remaining, actor.gunner.weapon.initial_rounds if actor.gunner.weapon != null else 30]
	if actor.gunner.inventory.typed: ammo_text = actor.gunner.ammo_summary()+" · 1/2 select next"
	var proj_text := "PROJECTILES: %d" % (projectiles.active_count() if projectiles != null else 0)
	var impact_text := "LAST IMPACT: —"
	if not _last_impact.is_empty():
		impact_text = "LAST IMPACT: #%d %s / %.2f s / %.2f m" % [
			_last_impact.get("shot_id", 0),
			str(_last_impact.get("reason_upper", "")),
			float(_last_impact.get("flight_time_s", 0.0)),
			float(_last_impact.get("travelled_m", 0.0)),
		]
	hud.update_hud(actor.tank.forward_speed, actor.gunner.cooldown_left, actor.gunner.blocked_reason, [], actor.cam_rig.sight, "CONTROL: A (PLAYER) [BALLISTICS] " + lane_text, result_text, "", ammo_text, proj_text, impact_text)

func _demo_pump_capture() -> void:
	# 006-R1-C：等本帧渲染完成（frame_post_draw）再取纹理；PNG 旁打印捕获时点的
	# 真实模拟状态（projectile_id/年龄/位置/在飞数量），不把先前采样值当作图片状态。
	var req: Dictionary = _demo_capture_requests.pop_front()
	await RenderingServer.frame_post_draw
	var rel := str(req.get("filename", "capture.png"))
	var sts: Array = projectiles.active_states()
	var desc := ""
	for st in sts:
		desc += "#%d age=%.4fs trav=%.2fm pos=%s " % [int(st.projectile_id), float(st.age_s), float(st.travelled_m), str(st.position_world)]
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_demo_capturing = false
		_demo_fail("capture failed: " + rel)
		return
	var path: String
	if _demo_dir.is_absolute_path():
		path = _demo_dir.path_join(rel)   # 绝对 shot-dir 直接使用
	else:
		path = ProjectSettings.globalize_path("res://" + _demo_dir + "/" + rel)
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(path)
	if err == OK:
		print("[bdemo] capture %s (NOT_REVIEWED): active=%d state=[%s]" % [rel, sts.size(), desc.strip_edges()])
		_demo_saved += 1
	else:
		_demo_fail("save failed (err=%d): %s" % [err, rel])
	_demo_capturing = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_pause()
	elif event.is_action_pressed("reset"):
		_reset_range()
	elif event.is_action_pressed("toggle_target"):
		# 006-R1-C：手动切换近靶/远靶（只启用对应目标与背墙）
		_set_lane("far" if _lane == "near" else "near")
		print("[bdemo] lane switched -> %s" % _lane)

func _reset_range() -> void:
	# 训练场整场重开（与主靶场 R 语义一致：先取消本车飞弹，再复位车辆与装填）
	if not _initialized:
		return
	if projectiles != null:
		projectiles.cancel_by_shooter(actor.entity_id, actor.life_id, "cancelled_reset")
	actor.reset_vehicle()
	# 006-R1-C：训练闭环——靶板反馈/最近结果/在飞终止登记/视觉状态同步复位
	for k in _boards:
		var b = _boards[k]
		if b != null:
			b.reset()
	_last_impact = {}
	_terminated_pids.clear()
	if projectile_visuals != null:
		projectile_visuals.clear_all()

func _pause() -> void:
	if not _initialized or _paused:
		return
	_paused = true
	actor.pause_block(true)
	if controller != null and controller.has_method("reset_pending"):
		controller.reset_pending()
	get_tree().paused = true
	hud.show_pause(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	if not _initialized or not _paused:
		return
	_paused = false
	get_tree().paused = false
	actor.pause_block(false)
	hud.show_pause(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.gunner.resume_grace = GameConfig.RESUME_GRACE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _initialized and not _paused:
			_pause()

func _return_to_range() -> void:
	# 训练场 -> 靶场（切换按新局处理：先清理飞弹与临时视觉）
	if not _initialized or not _paused:
		return
	if projectiles != null:
		projectiles.cancel_all("cancelled_scene_exit")
	if projectile_visuals != null:
		projectile_visuals.clear_all()   # 006-R1-C：不残留训练视觉
	get_tree().paused = false
	_paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _open_armor_training() -> void:
	if not _initialized or not _paused:
		return
	projectiles.cancel_all("cancelled_scene_exit")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/training/armor_range.tscn")

func _open_damage_training() -> void:
	if not _initialized or not _paused:
		return
	projectiles.cancel_all("cancelled_scene_exit")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/training/damage_range.tscn")

func _open_recovery_training() -> void:
	if not _initialized or not _paused: return
	projectiles.cancel_all("cancelled_scene_exit")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/training/recovery_range.tscn")

# =====================================================================
# 006-d / 006-R1-C 弹道演示（-- --ballistics-demo）
# 同一训练装配 + 生产发射路径；时点：刚发射未命中 / 近靶飞行中 / 近靶接触后
# （验证 NearBoard 身份）/ 远靶飞行中（明显更长飞行）/ 远靶接触后（验证 FarBoard
# 身份 + 真实炮口-接触面距离）/ 重开已清空。物理帧计数等待与渲染限帧（--max-fps）
# 无关；自然装填不清冷却；截图在渲染完成后捕获并记录捕获时点状态（NOT_REVIEWED）；
# 断言失败退出码非 0。
# =====================================================================

func _physics_process(_delta: float) -> void:
	# 006-d：演示步进机跑在物理回调（优先级 200 > 管理器 100 → 看到推进后状态）；
	# 自增 tick 等待与渲染限帧无关；暂停期间 ALWAYS 节点仍走。
	if _demo:
		_demo_ticks += 1
		if _demo_ticks > 6000:   # 看门狗：演示总时长上限（~100s 物理时间），防永久挂起
			print("[bdemo] FAIL: watchdog: demo_ticks=%d step=%d" % [_demo_ticks, _demo_step])
			print("[bdemo] shots_saved=%d errors=%d" % [_demo_saved, _demo_errors])
			print("BALLISTICS_DEMO_FAIL")
			get_tree().quit(1)
			return
		_demo_tick()

func _demo_tick() -> void:
	# 006-d/R1 弹道演示（-- --ballistics-demo）：同一训练装配 + 生产发射路径。
	# 时点：刚发射未命中 / 近靶飞行中 / 近靶接触后(验证 NearBoard 身份) /
	#       远靶飞行中(明显更长飞行) / 远靶接触后(验证 FarBoard 身份+真实距离) / 重开已清空。
	# 截图在渲染完成后捕获（frame_post_draw），并记录捕获时点真实模拟状态。
	if _demo_wait > 0:
		_demo_wait -= 1
		return
	_demo_step += 1
	# 步进机标签必须连续（match 自动 +1 推进；空号会白耗 tick）
	match _demo_step:
		10:
			seed(20250606)   # 固定随机状态（命中判定不含随机；kick_recoil 仅视觉）
			print("[bdemo] engine=%s" % Engine.get_version_info().string)
			print("[bdemo] max_fps_requested=%d vsync_mode=%d physics_tps=%d seed=20250606" % [Engine.max_fps, DisplayServer.window_get_vsync_mode(), Engine.physics_ticks_per_second])
			print("[bdemo] lane=%s (near board ~%.1fm, far board ~%.1fm muzzle->contact)" % [_lane, abs(NEAR_Z) - 3.2, abs(FAR_Z) - 3.2])
			_demo_wait = 30
		11:   # 瞄准近靶板中心（生产意图路径：相机 aim → 炮塔自然收敛）
			_demo_aim_yaw(Vector3(0, 1.4, NEAR_Z))
			_demo_wait = 6
		12:
			_demo_aim_pitch(Vector3(0, 1.4, NEAR_Z))
			_demo_wait = 104   # 自然收敛预算（炮塔有限转速上限 ~77 tick）
		13:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (near board)" % actor.turret.aim_error_deg())
				return
			print("[bdemo] t_pf=%d aim locked near board (err=%.2f deg)" % [Engine.get_physics_frames(), actor.turret.aim_error_deg()])
			_demo_aim_yaw(Vector3(0, 3.6, NEAR_Z - 2.0))   # 抬瞄越过靶板上缘(2.8) → 未命中
			_demo_wait = 6
		14:
			_demo_aim_pitch(Vector3(0, 3.6, NEAR_Z - 2.0))
			_demo_wait = 104
		15:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (above board)" % actor.turret.aim_error_deg())
				return
			_demo_board_base = {"NearBoard": int(_boards["NearBoard"].hit_count), "FarBoard": int(_boards["FarBoard"].hit_count)}
			if not _demo_fire("shot1"):
				return
			print("[bdemo] shot1 aim above board top -> expected MISS board, WORLD backwall")
			_demo_wait = 2   # 飞行 ~5.3 步，截图须在撞板前
		16:
			_demo_capture_requests.append({"filename": "demo_1_just_fired_miss.png"})   # 刚发射未命中
			_demo_wait = 30   # 飞行 + 终止预算
		17:
			if projectiles.active_count() > 0:
				_demo_fail("shot1 still active after wait (active=%d)" % projectiles.active_count())
				return
			if not _demo_check_record("shot1", "WORLD", 27.5, 31.5):
				return
			_demo_wait = _demo_reload_ticks()
		18:
			if actor.gunner.cooldown_left > 0.0:
				_demo_fail("shot2 natural reload not done (cooldown=%.2f)" % actor.gunner.cooldown_left)
				return
			print("[bdemo] t_pf=%d natural reload done (cooldown=%.2f)" % [Engine.get_physics_frames(), actor.gunner.cooldown_left])
			_demo_aim_yaw(Vector3(0, 1.4, NEAR_Z))
			_demo_wait = 6
		19:
			_demo_aim_pitch(Vector3(0, 1.4, NEAR_Z))
			_demo_wait = 104
		20:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (near board #2)" % actor.turret.aim_error_deg())
				return
			_demo_board_base = {"NearBoard": int(_boards["NearBoard"].hit_count), "FarBoard": int(_boards["FarBoard"].hit_count)}
			if not _demo_fire("shot2"):
				return
			_demo_wait = 2   # 近靶飞行仅 ~5.3 物理步（26.6m），采样须赶在撞板前
		21:
			_demo_sample_a = _demo_sample()
			if _demo_sample_a.is_empty():
				_demo_fail("shot2 in-flight sample failed (active=%d)" % projectiles.active_count())
				return
			print("[bdemo] t_pf=%d shot2 IN FLIGHT: age=%.4fs travelled=%.3fm pos=%s" % [Engine.get_physics_frames(), _demo_sample_a["age"], _demo_sample_a["trav"], str(_demo_sample_a["pos"])])
			_demo_capture_requests.append({"filename": "demo_2_in_flight.png"})   # 实际飞行中
			_demo_wait = 1
		22:
			var sb := _demo_sample()
			if sb.is_empty():
				_demo_fail("shot2 second sample failed (active=%d)" % projectiles.active_count())
				return
			if float(sb["trav"]) <= float(_demo_sample_a["trav"]):
				_demo_fail("shot2 not advancing (trav %.3f -> %.3f)" % [float(_demo_sample_a["trav"]), float(sb["trav"])])
				return
			print("[bdemo] t_pf=%d shot2 advanced: travelled %.3f -> %.3f m" % [Engine.get_physics_frames(), float(_demo_sample_a["trav"]), float(sb["trav"])])
			_demo_wait = 20
		23:
			if projectiles.active_count() > 0:
				_demo_fail("shot2 still active after wait (active=%d)" % projectiles.active_count())
				return
			if not _demo_check_record("shot2", "WORLD", 24.0, 27.0):
				return
			if not _demo_check_board_identity("shot2", "NearBoard"):
				return
			_demo_capture_requests.append({"filename": "demo_3_after_impact.png"})   # 接触后（HUD LAST IMPACT + 靶板反馈）
			_demo_wait = _demo_reload_ticks()
		24:
			if actor.gunner.cooldown_left > 0.0:
				_demo_fail("shot3 natural reload not done (cooldown=%.2f)" % actor.gunner.cooldown_left)
				return
			# 006-R1-C：切换远靶道——近靶/近背墙禁用，远靶直射路线无遮挡
			_set_lane("far")
			print("[bdemo] t_pf=%d lane switched -> far (FarBoard ~%.1fm muzzle->contact)" % [Engine.get_physics_frames(), abs(FAR_Z) - 3.2])
			_demo_aim_yaw(Vector3(0, 2.6, FAR_Z))   # 略抬高：补偿 150m 重力下坠 ~1.2m
			_demo_wait = 6
		25:
			_demo_aim_pitch(Vector3(0, 2.6, FAR_Z))
			_demo_wait = 104
		26:
			# 第二遍俯仰收敛：轨道相机高度随俯仰变化，一次近似不准——
			# 用更新后的相机位置重算一遍（远瞄必须两遍，近瞄几乎无差）
			_demo_aim_pitch(Vector3(0, 2.6, FAR_Z))
			_demo_wait = 104
		27:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (far board)" % actor.turret.aim_error_deg())
				return
			var bd: Vector3 = actor.turret.barrel_direction()
			print("[bdemo] t_pf=%d far aim pre-fire: barrel_dir=%s cam_yaw=%.3f cam_pitch=%.3f err=%.2f deg" % [Engine.get_physics_frames(), str(bd), actor.cam_rig.aim_yaw, actor.cam_rig.aim_pitch, actor.turret.aim_error_deg()])
			_demo_board_base = {"NearBoard": int(_boards["NearBoard"].hit_count), "FarBoard": int(_boards["FarBoard"].hit_count)}
			if not _demo_fire("shot3"):
				return
			_demo_wait = 8   # 远靶飞行 ~30 物理步（146.6m），采样窗口充足
		28:
			_demo_sample_a = _demo_sample()
			if _demo_sample_a.is_empty():
				_demo_fail("shot3 far in-flight sample failed (active=%d)" % projectiles.active_count())
				return
			print("[bdemo] t_pf=%d shot3 IN FLIGHT (far): age=%.4fs travelled=%.3fm pos=%s" % [Engine.get_physics_frames(), _demo_sample_a["age"], _demo_sample_a["trav"], str(_demo_sample_a["pos"])])
			_demo_capture_requests.append({"filename": "demo_4_far_in_flight.png"})   # 远靶实际飞行中
			_demo_wait = 5
		29:
			var sb2 := _demo_sample()
			if sb2.is_empty():
				_demo_fail("shot3 far second sample failed (active=%d)" % projectiles.active_count())
				return
			if float(sb2["trav"]) <= float(_demo_sample_a["trav"]):
				_demo_fail("shot3 not advancing (trav %.3f -> %.3f)" % [float(_demo_sample_a["trav"]), float(sb2["trav"])])
				return
			print("[bdemo] t_pf=%d shot3 advanced: travelled %.3f -> %.3f m" % [Engine.get_physics_frames(), float(_demo_sample_a["trav"]), float(sb2["trav"])])
			_demo_wait = 25
		30:
			if projectiles.active_count() > 0:
				_demo_fail("shot3 still active after wait (active=%d)" % projectiles.active_count())
				return
			if not _demo_check_record("shot3", "WORLD", 144.0, 148.5):
				return
			if not _demo_check_board_identity("shot3", "FarBoard"):
				return
			print("[bdemo] far REAL muzzle->contact distance = %.3f m (按飞弹实际路程记录，不按靶板标称值)" % float(_last_impact.get("travelled_m", 0.0)))
			_demo_capture_requests.append({"filename": "demo_5_far_after_impact.png"})   # 远靶接触后
			_demo_wait = _demo_reload_ticks()
		31:
			if actor.gunner.cooldown_left > 0.0:
				_demo_fail("shot4 natural reload not done (cooldown=%.2f)" % actor.gunner.cooldown_left)
				return
			_demo_board_base = {"NearBoard": int(_boards["NearBoard"].hit_count), "FarBoard": int(_boards["FarBoard"].hit_count)}
			if not _demo_fire("shot4"):
				return
			_demo_wait = 2
		32:
			if projectiles.active_count() != 1:
				_demo_fail("shot4 expected 1 in flight before reset (active=%d)" % projectiles.active_count())
				return
			_reset_range()   # 重开（生产 cancel_by_shooter + 车辆复位 + 靶板/最近结果/视觉复位）
			if projectiles.active_count() != 0:
				_demo_fail("reset did not clear projectiles (active=%d)" % projectiles.active_count())
				return
			if int(_boards["FarBoard"].hit_count) != 0 or int(_boards["NearBoard"].hit_count) != 0:
				_demo_fail("reset did not clear board feedback (far=%d near=%d)" % [int(_boards["FarBoard"].hit_count), int(_boards["NearBoard"].hit_count)])
				return
			print("[bdemo] t_pf=%d reset: in-flight 1 -> 0, board feedback/last-impact/visuals cleared (重开已清空)" % Engine.get_physics_frames())
			_demo_capture_requests.append({"filename": "demo_6_reset_cleared.png"})
			_demo_wait = 30
		33:
			# 采样期：step 保持 33（_process 在此期间累计实际渲染帧率）
			if _demo_ticks % 120 == 0:
				print("[bdemo] t_pf=%d fps sampling: n=%d/%d paused=%s" % [Engine.get_physics_frames(), _demo_fps_n, 60, str(get_tree().paused)])
			if _demo_fps_n >= 60:
				_demo_step = 39   # 下一 tick 到 40 收尾
			else:
				_demo_wait = 120  # 再等 2s 物理时间（期间空闲帧持续累计）
		40:
			var fps_avg := _demo_fps_sum / float(maxi(_demo_fps_n, 1))
			print("[bdemo] render_fps_actual=%.1f (requested max_fps=%d) physics_tps=%d physics_frames=%d demo_ticks=%d" % [fps_avg, Engine.max_fps, Engine.physics_ticks_per_second, Engine.get_physics_frames(), _demo_ticks])
			print("[bdemo] shots_saved=%d errors=%d" % [_demo_saved, _demo_errors])
			if _demo_errors > 0:
				print("BALLISTICS_DEMO_FAIL")
				get_tree().quit(1)
			else:
				print("BALLISTICS_DEMO_PASS")
				get_tree().quit(0)

func _demo_aim_yaw(p: Vector3) -> void:
	var dp := p - actor.tank.global_position
	actor.cam_rig.aim_yaw = atan2(-dp.x, -dp.z)
	actor.cam_rig.aim_pitch = 0.0

func _demo_reload_ticks() -> int:
	# 自然装填等待（不清冷却）：剩余装填秒数 → 物理 tick 数，留 5 tick 余量
	return int(actor.gunner.cooldown_left * float(Engine.physics_ticks_per_second)) + 5

func _demo_aim_pitch(p: Vector3) -> void:
	# 相机位置只依赖 aim_yaw（高度恒定），yaw 生效后一次即可定 pitch
	var cam_p: Vector3 = actor.cam_rig.cam.global_position
	var horiz := Vector3(cam_p.x - p.x, 0, cam_p.z - p.z).length()
	actor.cam_rig.aim_pitch = atan2(p.y - cam_p.y, horiz)

func _demo_fire(tag: String) -> bool:
	if not actor.gunner.try_fire():
		_demo_fail("%s fire rejected: %s" % [tag, actor.gunner.blocked_reason])
		return false
	print("[bdemo] t_pf=%d %s FIRED (shot_id=%d projectile_id=%d)" % [Engine.get_physics_frames(), tag, actor.gunner.shot_id, actor.gunner.last_projectile_id])
	_demo_flight_open = true   # 006-R1-C：开始记录飞行窗口实际帧间隔
	_demo_flight_deltas.clear()
	return true

func _demo_check_board_identity(tag: String, board_name: String) -> bool:
	# 006-R1-C：目标身份验证——指定靶板 hit_count 恰 +1，另一块不变
	# （不能仅凭终止原因 WORLD 断言命中目标：撞背墙同为 WORLD）
	var b = _boards.get(board_name)
	if b == null:
		_demo_fail(tag + ": board missing " + board_name)
		return false
	var base := int(_demo_board_base.get(board_name, 0))
	if int(b.hit_count) != base + 1:
		_demo_fail("%s expected %s hit_count=%d (base=%d) — 目标身份不符" % [tag, board_name, int(b.hit_count), base])
		return false
	var other := "FarBoard" if board_name == "NearBoard" else "NearBoard"
	var ob = _boards.get(other)
	if ob != null and int(ob.hit_count) != int(_demo_board_base.get(other, 0)):
		_demo_fail("%s unexpected %s hit (target identity mismatch)" % [tag, other])
		return false
	print("[bdemo] %s TARGET IDENTITY OK: %s (hit_count=%d)" % [tag, board_name, int(b.hit_count)])
	return true

func _demo_sample() -> Dictionary:
	var sts: Array = projectiles.active_states()
	if sts.size() != 1:
		return {}
	var st = sts[0]
	return {"pos": st.position_world, "age": st.age_s, "trav": st.travelled_m}

func _demo_check_record(tag: String, reason: String, tr_min: float, tr_max: float) -> bool:
	var li := _last_impact
	var ru := str(li.get("reason_upper", ""))
	var tr := float(li.get("travelled_m", 0.0))
	if ru != reason:
		_demo_fail("%s expected %s got %s" % [tag, reason, ru])
		return false
	if tr < tr_min or tr > tr_max:
		_demo_fail("%s travelled %.3f out of [%.1f, %.1f]" % [tag, tr, tr_min, tr_max])
		return false
	print("[bdemo] %s IMPACT: shot=%d reason=%s travelled=%.3fm t=%.4fs point=%s" % [
		tag, int(li.get("shot_id", 0)), ru, tr, float(li.get("flight_time_s", 0.0)), str(li.get("impact_point", Vector3.ZERO))])
	return true

func _demo_fail(msg: String) -> void:
	_demo_errors += 1
	push_error("[bdemo] FAIL: " + msg)
	print("[bdemo] FAIL: ", msg)
	_demo_step = 39   # 下一 tick 自增到 40 → 收尾（打印汇总并退出码非 0）
	_demo_wait = 0
