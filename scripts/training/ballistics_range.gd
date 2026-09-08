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
		"flight_time_s": float(record.get("flight_time_s", 0.0)),
		"travelled_m": float(record.get("travelled_m", 0.0)),
	}

func _process(_delta: float) -> void:
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
