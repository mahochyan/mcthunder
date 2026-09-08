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
var controller: PlayerController
var actor: VehicleActor
var projectiles: ProjectileManager
var hud: HUD
var _paused := false
var _initialized := false
var _last_impact: Dictionary = {}   # 006：最近飞弹终止（HUD 展示）
# --- 006-d 弹道演示状态 ---
var _demo := false
var _demo_dir := "docs/evidence/006/demo"
var _demo_step := 0
var _demo_wait := 0              # 空闲帧等待（暂停段使用；物理冻结时空闲帧仍走）
var _demo_wait_pf := -1          # 目标 Engine.get_physics_frames()（物理帧等待，与渲染限帧无关）
var _demo_errors := 0
var _demo_saved := 0
var _demo_sample_a := {}         # 飞行中采样 A
var _demo_frozen := {}           # 暂停冻结采样
var _demo_fps_sum := 0.0
var _demo_fps_n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	defs = VehicleDefs.new()
	var lr := defs.load_defaults()
	if not lr.ok:
		push_error("ballistics: defs load failed: %s" % ", ".join(lr.errors))
		return
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	actor = VehicleActor.new()
	actor.name = "ActorA"
	add_child(actor)
	var ra := actor.setup(defs, "player_tank", "A", 1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), GameConfig.VIS_LAYER_VEHICLE, controller)
	if not ra.ok:
		push_error("ballistics: actor setup failed: %s" % ", ".join(ra.errors))
		return
	projectiles = ProjectileManager.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	projectiles.snapshot_provider = Callable(self, "query_snapshots")
	projectiles.exclude_provider = Callable(self, "projectile_exclude_rids")
	projectiles.projectile_finished.connect(_on_projectile_finished)
	actor.gunner.projectile_manager = projectiles
	actor.gunner.round_provider = Callable(self, "get_round_id")
	actor.gunner.snapshot_provider = Callable(self, "query_snapshots")
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_requested.connect(_resume)
	hud.training_requested.connect(_return_to_range)
	hud.set_training_button_text(false)   # 训练场按钮 = 返回靶场
	_initialized = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 006-d：-- --ballistics-demo 弹道演示（同一训练装配 + 生产发射路径）
	var ua := OS.get_cmdline_user_args()
	_demo = ua.has("--ballistics-demo")
	for i in ua.size():
		if ua[i] == "--shot-dir" and i + 1 < ua.size():
			_demo_dir = ua[i + 1]

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
	_add_board(Vector3(0, 0, NEAR_Z), "NearBoard")
	_add_board(Vector3(0, 0, FAR_Z), "FarBoard")
	# 背板墙：挡住未中靶的飞弹（近 32m / 远 152m）
	_add_wall(Vector3(0, 3.0, NEAR_Z - 2.0), Vector3(20.0, 6.0, 1.0))
	_add_wall(Vector3(0, 3.0, FAR_Z - 2.0), Vector3(20.0, 6.0, 1.0))
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

func _add_board(pos: Vector3, name: String) -> void:
	var board := TargetBoard.new()
	board.name = name
	board.position = pos
	add_child(board)

func _add_wall(pos: Vector3, size: Vector3) -> void:
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

func get_round_id() -> int:
	return 0   # 训练场无任务轮次（命中只反馈，不推进试射目标）

func query_snapshots() -> Array:
	var out: Array = []
	for c in get_children():
		if c is VehicleActor and c.tank != null and is_instance_valid(c.tank) and c.definition != null:
			var layout_id: String = c.definition.layout_id
			if layout_id.is_empty():
				continue
			var layout := LayoutCatalog.load_layout(layout_id)
			if layout == null:
				continue
			out.append(QuerySnapshotBuilder.build_from_vehicle(c.tank, layout))
	return out

func projectile_exclude_rids(shooter_id: String, shooter_life_id: int) -> Array[RID]:
	if actor != null and actor.entity_id == shooter_id and actor.life_id == shooter_life_id \
			and actor.tank != null and is_instance_valid(actor.tank):
		return [actor.tank.get_rid()]
	return []

func _on_projectile_finished(record: Dictionary) -> void:
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

func _process(_delta: float) -> void:
	if _demo:
		_demo_tick()
	if not _initialized or actor == null or hud == null:
		return
	var result_text := ""
	if actor.gunner.last_shot_result == "fired":
		result_text = "LAST SHOT: #%d IN FLIGHT" % actor.gunner.shot_id
	elif actor.gunner.last_shot_result != "":
		result_text = "LAST SHOT: BLOCKED (%s)" % actor.gunner.blocked_reason.to_upper()
	var ammo_text := "AMMO: %d/%d" % [actor.gunner.rounds_remaining, actor.gunner.weapon.initial_rounds if actor.gunner.weapon != null else 30]
	var proj_text := "PROJECTILES: %d" % (projectiles.active_count() if projectiles != null else 0)
	var impact_text := "LAST IMPACT: —"
	if not _last_impact.is_empty():
		impact_text = "LAST IMPACT: #%d %s / %.2f s / %.2f m" % [
			_last_impact.get("shot_id", 0),
			str(_last_impact.get("reason_upper", "")),
			float(_last_impact.get("flight_time_s", 0.0)),
			float(_last_impact.get("travelled_m", 0.0)),
		]
	hud.update_hud(actor.tank.forward_speed, actor.gunner.cooldown_left, actor.gunner.blocked_reason, [], actor.cam_rig.sight, "CONTROL: A (PLAYER) [BALLISTICS]", result_text, "", ammo_text, proj_text, impact_text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_pause()
	elif event.is_action_pressed("reset"):
		_reset_range()

func _reset_range() -> void:
	# 训练场整场重开（与主靶场 R 语义一致：先取消本车飞弹，再复位车辆与装填）
	if not _initialized:
		return
	if projectiles != null:
		projectiles.cancel_by_shooter(actor.entity_id, actor.life_id, "cancelled_reset")
	actor.reset_vehicle()

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
	get_tree().paused = false
	_paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# =====================================================================
# 006-d 弹道演示（-- --ballistics-demo）
# 同一训练装配 + 生产发射路径；记录五个时间点：刚发射未命中 / 实际飞行中 /
# 接触后 / 暂停冻结 / 重开已清空。物理帧计数等待与渲染限帧（--max-fps）无关；
# 自然装填不清冷却；截图归档 --shot-dir；断言失败退出码非 0。
# =====================================================================

func _demo_tick() -> void:
	if _demo_wait_pf >= 0:
		if Engine.get_physics_frames() < _demo_wait_pf:
			return
		_demo_wait_pf = -1
	if _demo_wait > 0:
		_demo_wait -= 1
		return
	_demo_step += 1
	match _demo_step:
		10:
			seed(20250606)   # 固定随机状态（命中判定不含随机；kick_recoil 仅视觉）
			print("[bdemo] engine=%s" % Engine.get_version_info().string)
			print("[bdemo] max_fps_requested=%d physics_tps=%d seed=20250606" % [Engine.max_fps, Engine.physics_ticks_per_second])
			_demo_wait_pf = Engine.get_physics_frames() + 30
		20:   # 瞄准近靶板中心（生产意图路径：相机 aim → 炮塔自然收敛）
			_demo_aim_yaw(Vector3(0, 1.4, NEAR_Z))
			_demo_wait_pf = Engine.get_physics_frames() + 6
		25:
			_demo_aim_pitch(Vector3(0, 1.4, NEAR_Z))
			_demo_wait_pf = Engine.get_physics_frames() + 104
		30:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (near board)" % actor.turret.aim_error_deg())
				return
			print("[bdemo] t_pf=%d aim locked near board (err=%.2f deg)" % [Engine.get_physics_frames(), actor.turret.aim_error_deg()])
			_demo_aim_yaw(Vector3(0, 3.6, NEAR_Z - 2.0))   # 抬瞄越过靶板上缘(2.8) → 未命中
			_demo_wait_pf = Engine.get_physics_frames() + 6
		35:
			_demo_aim_pitch(Vector3(0, 3.6, NEAR_Z - 2.0))
			_demo_wait_pf = Engine.get_physics_frames() + 104
		40:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (above board)" % actor.turret.aim_error_deg())
				return
			if not _demo_fire("shot1"):
				return
			print("[bdemo] shot1 aim above board top -> expected MISS board, WORLD backwall")
			_demo_wait_pf = Engine.get_physics_frames() + 2
		50:
			_demo_shot("demo_1_just_fired_miss.png")   # 刚发射未命中
			_demo_wait_pf = Engine.get_physics_frames() + 30   # 飞行 + 终止预算
		60:
			if projectiles.active_count() > 0:
				_demo_fail("shot1 still active after wait (active=%d)" % projectiles.active_count())
				return
			if not _demo_check_record("shot1", "WORLD", 27.5, 31.5):
				return
			_demo_wait_pf = Engine.get_physics_frames() + int(actor.gunner.cooldown_left * float(Engine.physics_ticks_per_second)) + 5
		70:
			if actor.gunner.cooldown_left > 0.0:
				_demo_fail("shot2 natural reload not done (cooldown=%.2f)" % actor.gunner.cooldown_left)
				return
			print("[bdemo] t_pf=%d natural reload done (cooldown=%.2f)" % [Engine.get_physics_frames(), actor.gunner.cooldown_left])
			_demo_aim_yaw(Vector3(0, 1.4, NEAR_Z))
			_demo_wait_pf = Engine.get_physics_frames() + 6
		75:
			_demo_aim_pitch(Vector3(0, 1.4, NEAR_Z))
			_demo_wait_pf = Engine.get_physics_frames() + 104
		80:
			if actor.turret.aim_error_deg() > 1.0:
				_demo_fail("natural aim err=%.2f deg (near board #2)" % actor.turret.aim_error_deg())
				return
			if not _demo_fire("shot2"):
				return
			_demo_wait_pf = Engine.get_physics_frames() + 3
		90:
			_demo_sample_a = _demo_sample()
			if _demo_sample_a.is_empty():
				_demo_fail("shot2 in-flight sample failed (active=%d)" % projectiles.active_count())
				return
			print("[bdemo] t_pf=%d shot2 IN FLIGHT: age=%.4fs travelled=%.3fm pos=%s" % [Engine.get_physics_frames(), _demo_sample_a["age"], _demo_sample_a["trav"], str(_demo_sample_a["pos"])])
			_demo_shot("demo_2_in_flight.png")   # 实际飞行中
			_demo_wait_pf = Engine.get_physics_frames() + 2
		95:
			var sb := _demo_sample()
			if sb.is_empty():
				_demo_fail("shot2 second sample failed (active=%d)" % projectiles.active_count())
				return
			if float(sb["trav"]) <= float(_demo_sample_a["trav"]):
				_demo_fail("shot2 not advancing (trav %.3f -> %.3f)" % [float(_demo_sample_a["trav"]), float(sb["trav"])])
				return
			print("[bdemo] t_pf=%d shot2 advanced: travelled %.3f -> %.3f m" % [Engine.get_physics_frames(), float(_demo_sample_a["trav"]), float(sb["trav"])])
			_demo_wait_pf = Engine.get_physics_frames() + 20
		100:
			if projectiles.active_count() > 0:
				_demo_fail("shot2 still active after wait (active=%d)" % projectiles.active_count())
				return
			if not _demo_check_record("shot2", "WORLD", 24.0, 27.0):
				return
			_demo_wait_pf = Engine.get_physics_frames() + int(actor.gunner.cooldown_left * float(Engine.physics_ticks_per_second)) + 5
		110:
			if actor.gunner.cooldown_left > 0.0:
				_demo_fail("shot3 natural reload not done (cooldown=%.2f)" % actor.gunner.cooldown_left)
				return
			if not _demo_fire("shot3"):
				return
			_demo_wait_pf = Engine.get_physics_frames() + 4
		120:
			var sf := _demo_sample()
			if sf.is_empty():
				_demo_fail("shot3 pre-pause sample failed (active=%d)" % projectiles.active_count())
				return
			_demo_frozen = sf
			print("[bdemo] t_pf=%d shot3 in flight, pausing: age=%.4fs travelled=%.3fm pos=%s" % [Engine.get_physics_frames(), sf["age"], sf["trav"], str(sf["pos"])])
			_pause()
			_demo_wait = 30   # 空闲帧等待（物理已冻结；暂停菜单可见）
		130:
			var sr := _demo_sample()
			if sr.is_empty():
				_demo_fail("paused sample failed (active=%d)" % projectiles.active_count())
				return
			if sr["pos"] != _demo_frozen["pos"] or sr["age"] != _demo_frozen["age"] or sr["trav"] != _demo_frozen["trav"]:
				_demo_fail("pause not frozen: pos %s vs %s" % [str(_demo_frozen["pos"]), str(sr["pos"])])
				return
			print("[bdemo] pause frozen verified: pos/age/travelled identical over 30 idle frames")
			_demo_shot("demo_4_paused_frozen.png")   # 暂停冻结
			_resume()
			_demo_wait_pf = Engine.get_physics_frames() + 30
		140:
			if projectiles.active_count() > 0:
				_demo_fail("shot3 still active after resume wait (active=%d)" % projectiles.active_count())
				return
			if not _demo_check_record("shot3", "WORLD", 24.0, 27.0):
				return
			_demo_wait_pf = Engine.get_physics_frames() + int(actor.gunner.cooldown_left * float(Engine.physics_ticks_per_second)) + 5
		150:
			if actor.gunner.cooldown_left > 0.0:
				_demo_fail("shot4 natural reload not done (cooldown=%.2f)" % actor.gunner.cooldown_left)
				return
			if not _demo_fire("shot4"):
				return
			_demo_wait_pf = Engine.get_physics_frames() + 2
		160:
			if projectiles.active_count() != 1:
				_demo_fail("shot4 expected 1 in flight before reset (active=%d)" % projectiles.active_count())
				return
			_reset_range()   # 重开（生产 cancel_by_shooter + 车辆复位）
			if projectiles.active_count() != 0:
				_demo_fail("reset did not clear projectiles (active=%d)" % projectiles.active_count())
				return
			print("[bdemo] t_pf=%d reset: in-flight 1 -> 0 (重开已清空)" % Engine.get_physics_frames())
			_demo_shot("demo_5_reset_cleared.png")
			_demo_wait = 30
		170:
			_demo_fps_sum += float(Engine.get_frames_per_second())
			_demo_fps_n += 1
			if _demo_fps_n < 60:
				_demo_step -= 1   # 原地驻留采样实际渲染帧率
		180:
			var fps_avg := _demo_fps_sum / float(maxi(_demo_fps_n, 1))
			print("[bdemo] render_fps_actual=%.1f (requested max_fps=%d) physics_tps=%d physics_frames=%d" % [fps_avg, Engine.max_fps, Engine.physics_ticks_per_second, Engine.get_physics_frames()])
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

func _demo_aim_pitch(p: Vector3) -> void:
	# 相机位置只依赖 aim_yaw（高度恒定），yaw 生效后一次即可定 pitch
	var cam_p: Vector3 = actor.cam_rig.cam.global_position
	var horiz := Vector3(cam_p.x - p.x, 0, cam_p.z - p.z).length()
	actor.cam_rig.aim_pitch = atan2(p.y - cam_p.y, horiz)

func _demo_fire(tag: String) -> bool:
	if not actor.gunner.try_fire():
		_demo_fail("%s fire rejected: %s" % [tag, actor.gunner.blocked_reason])
		return false
	print("[bdemo] t_pf=%d %s FIRED (shot_id=%d)" % [Engine.get_physics_frames(), tag, actor.gunner.shot_id])
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

func _demo_shot(rel: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_demo_fail("capture failed: " + rel)
		return
	var path := ProjectSettings.globalize_path("res://" + _demo_dir + "/" + rel)
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(path)
	if err == OK:
		print("[bdemo] saved ", path)
		_demo_saved += 1
	else:
		_demo_fail("save failed (err=%d): %s" % [err, rel])

func _demo_fail(msg: String) -> void:
	_demo_errors += 1
	push_error("[bdemo] FAIL: " + msg)
	print("[bdemo] FAIL: ", msg)
	_demo_step = 179   # 下一 tick 自增到 180 → 收尾（打印汇总并退出码非 0）
	_demo_wait = 0
	_demo_wait_pf = -1
