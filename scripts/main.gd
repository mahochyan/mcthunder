class_name Main
extends Node3D
## 流程（职责：装配 / 暂停恢复 / 重置 / 失焦自动暂停 / 瞄准标记 / 截图自检模式）。
## 003：装配两辆独立车辆实体（A=玩家控制，B=测试目标零命令）；统一生成/销毁入口；
## reset_vehicle（单车）与 reset_range（整场）分离；试射目标（A 命中 B 三次）。
## 节点处理模式：Main=ALWAYS（Esc 与失焦在暂停时仍可用）；Actor 子树=PAUSABLE；HUD 继承 ALWAYS。

var world: WorldBuilder
var defs: VehicleDefs
var controller: PlayerController
var actor_a: VehicleActor
var actor_b: VehicleActor
var projectiles: ProjectileManager   # 006：唯一推进飞弹的物理执行器（当前战斗场景拥有）
var tank: TankVehicle        # 兼容引用 → actor_a.tank（现有测试/autoshot 使用）
var turret: TurretRig        # 兼容引用 → actor_a.turret
var cam_rig: CameraRig       # 兼容引用 → actor_a.cam_rig
var gunner: Gunner           # 兼容引用 → actor_a.gunner
var hud: HUD
var targets: Array = []
var trial_hits := 0           # 003：试射目标计数（gate.accept_hit 接受后同步；任务状态单一来源 = _gate）
const TRIAL_TARGET := 3
var _last_impact: Dictionary = {}   # 006：最近一次飞弹终止（按 projectile_id 保存，HUD 展示）
var _gate := TrialHitGate.new()   # 003-R2：任务收分唯一来源（轮次/命中数/去重集合都在 gate 维护，Main 只读）
var _paused := false
var _inspector_open := false   # 004-c：车辆检视窗口打开标志（Esc 路由 / 靶场输入隔离）
var _inspector: VehicleInspector = null   # 004-c：检视窗口实例引用
var _inspector_layer: CanvasLayer = null  # 004-R1：检视窗口专用层（Control 锚点需要 CanvasLayer 父）
var _aborted := false         # 003-R2：启动失败短路标志（true = 停止正常帧/输入处理）
var _abort_reason := ""
var _initialized := false     # 003-R2：初始化完成标记（全部成功后才允许正常暂停/恢复/重置）
var _err_label: Label = null  # 003-R2：abort 错误画面引用（幂等：不重复创建）
var _autoshot := false
var _inspect_demo := false   # 004-d：--inspect-demo 检视窗口可见证据模式
var _query_demo := false     # 005-d：--query-demo 查询调试面板可见证据模式
var _query_panel: QueryDebugPanel = null        # 005-d：统一命中查询调试面板
var _query_panel_layer: CanvasLayer = null      # 005-d：面板专用层（Control 锚点需要 CanvasLayer 父）
var _query_panel_open := false                  # 005-d：面板打开标志（输入隔离/路由）
var _demo_s0 := 0    # 005-d：演示中面板使用前弹药计数（证明调试查询不消耗）
var _demo_t0 := 0    # 005-d：演示中面板使用前任务计数
var _debug_on := false
var _shot_step := 0
var _shot_errors := 0    # 002-R1：截图失败汇总（必需截图失败 → 自检退出码非 0）
var _shots_saved := 0
var _shot_dir := "docs"  # 002-R2：--shot-dir <路径> 指定归档目录（分分辨率独立保存）
var _autoshot_wait := 0   # 003-R1：正常演示跨帧等待（>0 每帧递减，纯等待后推进到下一步；装填轮询用 _shot_step -= 1 原地驻留）
var _demo_poll := 0       # 003-R2：自然瞄准/装填轮询帧计数（有限超时判据）
var _marker_desired: MeshInstance3D   # 青色圆球 = 玩家想瞄的点（相机中心）
var _marker_actual: MeshInstance3D    # 橙色方块 = 炮管实际指向

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_autoshot = OS.get_cmdline_user_args().has("--autoshot")
	_inspect_demo = OS.get_cmdline_user_args().has("--inspect-demo")   # 004-d：检视窗口可见证据
	_query_demo = OS.get_cmdline_user_args().has("--query-demo")   # 005-d：查询面板可见证据
	var ua := OS.get_cmdline_user_args()
	for i in ua.size():
		if ua[i] == "--shot-dir" and i + 1 < ua.size():
			_shot_dir = ua[i + 1]
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	world.build()
	targets = world.targets
	defs = VehicleDefs.new()
	var lr := defs.load_defaults()
	if not lr.ok:
		# 003-R2：启动失败受控短路——打印错误后真正停止装配，不继续使用半初始化组件
		_abort_initialization("default defs load failed", lr.errors)
		return
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	actor_a = VehicleActor.new()
	actor_a.name = "ActorA"
	add_child(actor_a)
	var ra := actor_a.setup(defs, "player_tank", "A", 1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 8)), GameConfig.VIS_LAYER_VEHICLE, controller)
	if not ra.ok:
		_abort_initialization("actor A setup failed", ra.errors)
		return
	actor_b = VehicleActor.new()
	actor_b.name = "ActorB"
	add_child(actor_b)
	var rb := actor_b.setup(defs, "player_tank", "B", 2, Transform3D(Basis.IDENTITY, Vector3(8, 0, 0)), GameConfig.VIS_LAYER_VEHICLE_B, null)
	if not rb.ok:
		_abort_initialization("actor B setup failed", rb.errors)
		return
	# 兼容引用（指向 A 组件）
	tank = actor_a.tank
	turret = actor_a.turret
	cam_rig = actor_a.cam_rig
	gunner = actor_a.gunner
	# 006：飞弹管理器——当前战斗场景拥有（不挂在 Gunner 下；射手销毁后已飞弹丸继续存在）
	projectiles = ProjectileManager.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	projectiles.snapshot_provider = Callable(self, "query_snapshots")
	projectiles.exclude_provider = Callable(self, "projectile_exclude_rids")
	projectiles.projectile_finished.connect(_on_projectile_finished)
	actor_a.gunner.projectile_manager = projectiles
	actor_b.gunner.projectile_manager = projectiles
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_requested.connect(_resume)
	hud.inspect_requested.connect(open_vehicle_inspector)   # 004-c：暂停菜单检视入口
	hud.training_requested.connect(_open_training)   # 006：暂停菜单弹道训练入口
	# 试射目标：B 的真实生产命中事件推进计数（完整身份校验见 _on_b_hit / gate）
	actor_b.tank.hit_registered.connect(_on_b_hit)
	# 003-R2：发射身份的轮次来源（A/B 由 _ready 直建，不经 spawn_vehicle，需注入）
	actor_a.gunner.round_provider = Callable(self, "get_round_id")
	actor_b.gunner.round_provider = Callable(self, "get_round_id")
	# 005：统一命中查询的快照来源（A/B 与后续 spawn 的实体都纳入）
	actor_a.gunner.snapshot_provider = Callable(self, "query_snapshots")
	actor_b.gunner.snapshot_provider = Callable(self, "query_snapshots")
	# 003-R2：任务开始——gate 锁定双方身份并推进轮次（唯一来源初始化）；
	# 失败 = 初始化失败，走同一短路（不只打印后继续）
	if not _gate.begin_round(actor_a.entity_id, actor_a.life_id, actor_b.entity_id, actor_b.life_id, TRIAL_TARGET):
		_abort_initialization("task gate init rejected", ["begin_round rejected: shooter/target identity invalid"])
		return
	if not _autoshot and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 003-R2：全部初始化成功（A/B/HUD/信号/gate）——允许正常暂停/恢复/重置
	_initialized = true

func _abort_initialization(reason: String, errors: Array) -> void:
	# 003-R2：启动失败受控短路——先设终止状态再清理（幂等：重复调用不重复创建错误画面）；
	# 关闭正常帧与输入处理、清理本次已建实体、显示实际错误；
	# 无窗口/截图自检模式以非零码退出（自动验收可见）。
	_initialized = false
	if _aborted:
		push_error("003-R2 ABORT (repeat, ignored): %s" % reason)
		return
	_aborted = true
	_abort_reason = reason
	push_error("003-R2 ABORT: %s: %s" % [reason, ", ".join(errors)])
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	set_process_input(false)
	# 清理半建对象（装配边界失败时可能有已加入树的实体）
	for c in get_children():
		if c is VehicleActor:
			c.queue_free()
	actor_a = null
	actor_b = null
	# 可见错误显示（不建正式菜单系统；不依赖正常 HUD——它可能尚未创建）
	if _err_label == null:
		_err_label = Label.new()
		_err_label.text = "INIT FAILED: %s\n%s" % [reason, "\n".join(errors)]
		_err_label.position = Vector2(40, 40)
		add_child(_err_label)
	if DisplayServer.get_name() == "headless" or _autoshot:
		print("[003-R2] ABORT exit: initialization failed (headless/autoshot)")
		get_tree().quit(1)   # 非零退出 = 自动验收可见

func get_round_id() -> int:
	# 003-R2：gunner 发射身份的轮次来源（开火时刻冻结；轮次唯一来源 = _gate）
	return _gate.round_id

func query_snapshots() -> Array:
	# 005：统一命中查询快照来源——遍历本场景全部 VehicleActor，
	# 有布局关联的实体构建当前姿态快照（变换只读一次，不持有 Node 引用）。
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

func spawn_vehicle(vehicle_id: String, entity_id: String, pos: Vector3, ctrl: Node = null, defs_override: VehicleDefs = null, spawn_tf: Transform3D = Transform3D()) -> VehicleActor:
	# 003：统一实体生成入口（T003-04 生命周期测试用）；003-R1：可指定配置注册表与出生变换
	var d: VehicleDefs = defs_override if defs_override != null else defs
	var tf: Transform3D = spawn_tf if spawn_tf != Transform3D() else Transform3D(Basis.IDENTITY, pos)
	var a := VehicleActor.new()
	a.name = "Spawned_" + entity_id
	add_child(a)
	var r := a.setup(d, vehicle_id, entity_id, 9, tf, GameConfig.VIS_LAYER_VEHICLE_B, ctrl)
	if not r.ok:
		a.queue_free()
		return null
	a.gunner.round_provider = Callable(self, "get_round_id")   # 003-R2：发射身份轮次来源
	a.gunner.snapshot_provider = Callable(self, "query_snapshots")   # 005：统一命中查询快照来源
	a.gunner.projectile_manager = projectiles   # 006：飞弹推进执行器（与 A/B 同一管理器）
	return a

func despawn_vehicle(a: VehicleActor) -> void:
	# 003：统一实体销毁入口（信号随对象释放自动断开；相机 current 由本地控制者设置管理）
	if a == null:
		return
	a.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# 004-c：检视窗口打开时 Esc = 返回暂停菜单（真实返回流程），不恢复游戏
		if _inspector_open:
			close_vehicle_inspector()
			return
		# 005-d：查询调试面板打开时 Esc = 关闭面板（不暂停、不恢复）
		if _query_panel_open:
			close_query_debug()
			return
		if _paused:
			_resume()
		else:
			_pause()
	elif _inspector_open:
		return   # 004-c：检视期间不触发靶场输入（重置/开火/调试）
	elif event.is_action_pressed("query_debug_toggle"):
		# 005-d：F6 开关查询调试面板（暂停菜单打开时不弹出）
		if _query_panel_open:
			close_query_debug()
		elif not _paused:
			open_query_debug()
	elif _query_panel_open:
		return   # 005-d：面板打开期间不触发靶场输入（重置/调试/开火）
	elif event.is_action_pressed("reset"):
		_reset_all()
	elif event.is_action_pressed("debug_toggle"):
		_debug_on = not _debug_on
		hud.set_debug_visible(_debug_on)

func _can_use_gameplay() -> bool:
	# 003-R2：正常玩法入口统一守卫——初始化完成且未终止、实体与 HUD 有效。
	# 初始化失败后，失焦通知/暂停/恢复/重置不得再访问正常 HUD 或实体。
	return (
		_initialized
		and not _aborted
		and is_instance_valid(actor_a)
		and is_instance_valid(actor_b)
		and is_instance_valid(hud)
	)

func _pause() -> void:
	if not _can_use_gameplay():
		return
	if _paused:
		return
	# 005-R1-C：暂停入口先关查询面板（覆盖失焦自动暂停与暂停键两条路径）——
	# 面板关闭走 close_query_debug（清理 + 火键释放观察），再进入暂停
	if _query_panel_open:
		close_query_debug()
	_paused = true
	# 003-R2：暂停在状态切换入口显式清理——两车暂存 + 控制者待发 fire 边沿；
	# 不指望已停止物理回调的 actor 自己清掉（NOTIFICATION_PAUSED 仅作兜底）
	if actor_a != null:
		actor_a.pause_block(true)
	if actor_b != null:
		actor_b.pause_block(true)
	if controller != null and controller.has_method("reset_pending"):
		controller.reset_pending()
	get_tree().paused = true
	hud.show_pause(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open_vehicle_inspector() -> void:
	# 004-c：暂停菜单 -> 独立检视窗口（不恢复游戏；树仍 paused）
	if not _can_use_gameplay() or not _paused or _inspector_open:
		return
	_inspector_open = true
	hud.show_pause(false)
	var packed: PackedScene = load("res://scenes/inspection/vehicle_inspector.tscn")
	if packed == null:
		push_error("004-c: vehicle_inspector.tscn load failed")
		_inspector_open = false
		hud.show_pause(true)
		return
	_inspector = packed.instantiate()
	# 004-R1 组A：inspector 是全屏 Control——挂独立 CanvasLayer（与 HUD 同机制），
	# anchors/容器布局在 CanvasLayer 下才正确铺满视口（挂 Node3D 下锚点系统不生效）。
	_inspector_layer = CanvasLayer.new()
	_inspector_layer.layer = 20
	add_child(_inspector_layer)
	_inspector_layer.add_child(_inspector)
	_inspector.close_requested.connect(close_vehicle_inspector)
	# 载入默认历史研究布局（失败不阻塞窗口打开——空树可返回）
	LayoutCatalog.register_evidence(PackedStringArray([
		"EV-TM9759-IDENTITY", "EV-TM9759-SPECS", "EV-TM9759-ENGINE", "EV-TM9759-TRANS",
		"EV-TM9759-TURRET-FLOOR", "EV-TM9759-STOWAGE", "EV-TM9759-GEN",
		"EV-TM9759-RADIO", "EV-TM9759-TRAVERSE", "EV-FM1767-CREW"]))
	var l := LayoutCatalog.load_layout("us_m4a3_75w_vvss_1944")
	if l != null:
		_inspector.load_layout(l)

func close_vehicle_inspector() -> void:
	# 004-c：检视窗口 -> 暂停菜单（真实返回流程；游戏保持暂停）
	if not _inspector_open:
		return
	_inspector_open = false
	if is_instance_valid(_inspector):
		_inspector.queue_free()
	_inspector = null
	if is_instance_valid(_inspector_layer):
		_inspector_layer.queue_free()
	_inspector_layer = null
	if _can_use_gameplay():
		hud.show_pause(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open_query_debug() -> void:
	# 005-d：统一命中查询调试面板（GEOMETRY ONLY）。
	# 范围入口（不暂停）：打开时禁用控制器意图（不误触开火/驾驶/瞄准）并释放鼠标；
	# 关闭时恢复。面板所有查询纯几何，不消耗弹药/任务、不触碰 Gunner。
	if not _can_use_gameplay() or _paused or _inspector_open or _query_panel_open:
		return
	_query_panel_open = true
	controller.commands_enabled = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_query_panel_layer = CanvasLayer.new()
	_query_panel_layer.layer = 20
	add_child(_query_panel_layer)
	_query_panel = QueryDebugPanel.new()
	_query_panel.name = "QueryDebugPanel"
	_query_panel.main = self
	_query_panel.close_requested.connect(close_query_debug)
	_query_panel_layer.add_child(_query_panel)

func close_query_debug() -> void:
	# 005-d：关闭面板——恢复控制器意图与鼠标捕获（仅在游戏未暂停时重捕获）。
	# 005-R1-C：统一清理走 panel.cleanup()；恢复意图后要求观察到火键释放
	# （关闭用鼠标左键不得被当作一次开火边沿；面板打开期间火键按下也不补发）。
	if not _query_panel_open:
		return
	_query_panel_open = false
	controller.commands_enabled = true
	controller.require_fire_release()
	if is_instance_valid(_query_panel):
		_query_panel.cleanup()
		_query_panel.queue_free()
	_query_panel = null
	if is_instance_valid(_query_panel_layer):
		_query_panel_layer.queue_free()
	_query_panel_layer = null
	if not _paused and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_training() -> void:
	# 006：暂停菜单 -> 弹道训练场（切换按新局处理：先清理飞弹与临时视觉，
	# 不携带旧轮次命中；训练场返回靶场同理）
	if not _can_use_gameplay() or not _paused:
		return
	if projectiles != null:
		projectiles.cancel_all("cancelled_scene_exit")
	get_tree().paused = false
	_paused = false
	get_tree().change_scene_to_file("res://scenes/training/ballistics_range.tscn")

func _resume() -> void:
	if not _can_use_gameplay():
		return
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	# 003-R2：解除阻塞（暂存已在暂停时清空——不恢复旧请求）
	if actor_a != null:
		actor_a.pause_block(false)
	if actor_b != null:
		actor_b.pause_block(false)
	hud.show_pause(false)
	# 鼠标重捕获：仅无窗口模式跳过；autoshot 模式也执行以便窗口证据（002 T002-04）
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	gunner.resume_grace = GameConfig.RESUME_GRACE   # 恢复点击不得意外开炮

func _reset_all() -> void:
	# 兼容别名（002 测试沿用）；003 语义 = 整场重开
	reset_range()

func reset_range() -> void:
	# 003：整场重开——两车 + 靶板 + 试射目标全部复位
	# 003-R2：统一守卫——初始化失败后不得重置（空实体访问）
	if not _can_use_gameplay():
		return
	# 先停止接收旧输入（清两车暂存 + 控制者待发 fire 边沿），
	# 取消全部活动/待推进飞弹（不产生命中事件），
	# 推进任务轮次（gate 是轮次/进度的唯一来源，begin_round 清进度与去重集合），
	# 再复位实体与靶场
	actor_a.clear_commands()
	actor_b.clear_commands()
	if controller != null and controller.has_method("reset_pending"):
		controller.reset_pending()
	if projectiles != null:
		projectiles.cancel_all("cancelled_reset")
	if not _gate.begin_round(actor_a.entity_id, actor_a.life_id, actor_b.entity_id, actor_b.life_id, TRIAL_TARGET):
		push_error("003-R2: task gate begin_round rejected")
	actor_a.reset_vehicle()
	actor_b.reset_vehicle()
	for t in targets:
		t.reset()
	trial_hits = _gate.hits

func reset_vehicle(actor: VehicleActor) -> void:
	# 003：单车重置——不污染其他车/靶场/试射目标
	# 006：取消该车发出的飞弹（不取消其他车辆的飞弹）
	if actor != null:
		if projectiles != null:
			projectiles.cancel_by_shooter(actor.entity_id, actor.life_id, "cancelled_reset")
		actor.reset_vehicle()

func _notification(what: int) -> void:
	# 窗口失去焦点自动暂停，避免切回后车辆仍在移动
	# 003-R2：失焦通知与常规帧处理是独立入口——必须单独守卫：
	# 初始化失败（HUD 未创建/实体已清）后不得进入正常暂停流程访问空对象
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _can_use_gameplay() or _paused or _autoshot:
			return
		_pause()

func _on_b_hit(identity: Dictionary) -> void:
	# 003-R2：任务收分唯一来源 = _gate（轮次/射手/目标/双方生命周期/去重/完成上限
	# 全部由 gate 校验）；事件字典用独立副本传递，监听者不会改到其他接收者所见。
	# 轮次/生命周期在开火时刻冻结进事件（不在接收时补填）。
	if _aborted:
		return
	var res := _gate.accept_hit(identity.duplicate(true))
	if res.accepted:
		trial_hits = _gate.hits

func _on_projectile_finished(record: Dictionary) -> void:
	# 006：飞弹终止事件分发——只处理有效车辆撞击；世界撞击已在撞击瞬间由管理器
	# 直接反馈（靶板 register_hit），此处不保存活的 collider。
	# 目标已经消失时不重新找一辆同名新车冒充旧目标。
	if _aborted:
		return
	# 最近结果按 projectile_id 保存（HUD 展示；旧弹结果不串到新弹）
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
		"projectile_id": int(record.get("projectile_id", 0)),
		"shot_id": int(record.get("shot_id", 0)),
		"reason": reason,
		"reason_upper": reason_upper,
		"flight_time_s": float(record.get("flight_time_s", 0.0)),
		"travelled_m": float(record.get("travelled_m", 0.0)),
	}
	if reason != "impact_vehicle":
		return
	var target := find_vehicle(str(record.get("target_id", "")), int(record.get("target_life_id", 0)))
	if target == null:
		return
	var identity := {
		"round_id": int(record.get("round_id", -1)),
		"shooter_id": str(record.get("shooter_id", "")),
		"shooter_life_id": int(record.get("shooter_life_id", 0)),
		"shot_id": int(record.get("shot_id", 0)),
		"target_id": target.entity_id,
		"target_life_id": target.life_id,
	}
	target.register_hit(identity)   # 任务身份与去重由 TrialHitGate 继续执行

func projectile_exclude_rids(shooter_id: String, shooter_life_id: int) -> Array[RID]:
	# 006：管理器世界查询的自身排除——按发射者身份找实际车辆 RID（不按车型排除）
	var a := find_actor(shooter_id, shooter_life_id)
	if a == null or a.tank == null or not is_instance_valid(a.tank):
		return []
	return [a.tank.get_rid()]

func find_actor(entity_id: String, life_id: int) -> VehicleActor:
	# 006：按实体身份找实际 VehicleActor（临时查找，不持有 Node 引用）
	var tree := get_tree()
	if tree == null:
		return null
	return _find_actor_in(tree.root, entity_id, life_id)

func _find_actor_in(node: Node, entity_id: String, life_id: int) -> VehicleActor:
	for c in node.get_children():
		if c is VehicleActor and c.entity_id == entity_id and c.life_id == life_id:
			return c
		var r := _find_actor_in(c, entity_id, life_id)
		if r != null:
			return r
	return null

func find_vehicle(entity_id: String, life_id: int) -> TankVehicle:
	# 006：按实体身份找实际车辆实例（临时查找，不持有 Node 引用）
	var a := find_actor(entity_id, life_id)
	if a == null or a.tank == null or not is_instance_valid(a.tank):
		return null
	return a.tank

func _process(_delta: float) -> void:
	if _aborted:
		return   # 003-R2：启动失败短路——正常帧已停止（错误画面静态显示）
	var hits := []
	for t in targets:
		hits.append(t.hit_count)
	# 003-R1：提示来自实际状态（实体标识/配置内容层级），不写死 HUD 文字
	var control_text := "CONTROL: %s (PLAYER)" % actor_a.entity_id
	if actor_a.definition.content_tier == "test":
		control_text += " [TEST ONLY]"
	var result_text := ""
	if gunner.last_shot_result == "fired":
		result_text = "LAST SHOT: #%d IN FLIGHT" % gunner.shot_id
	elif gunner.last_shot_result != "":
		result_text = "LAST SHOT: BLOCKED (%s)" % gunner.blocked_reason.to_upper()
	var trial_text := "TRIAL: A HIT B %d/%d" % [trial_hits, TRIAL_TARGET]
	if trial_hits >= TRIAL_TARGET:
		trial_text = "TRIAL COMPLETE: A HIT B 3/3 (R to restart)"
	# 006：弹药/在飞/最近撞击（最近结果按 projectile_id 保存，不靠无身份字符串串接）
	var ammo_text := "AMMO: %d/%d" % [gunner.rounds_remaining, gunner.weapon.initial_rounds if gunner.weapon != null else 30]
	var proj_text := "PROJECTILES: %d" % (projectiles.active_count() if projectiles != null else 0)
	var impact_text := "LAST IMPACT: —"
	if not _last_impact.is_empty():
		impact_text = "LAST IMPACT: #%d %s / %.2f s / %.2f m" % [
			_last_impact.get("shot_id", 0),
			str(_last_impact.get("reason_upper", "")),
			float(_last_impact.get("flight_time_s", 0.0)),
			float(_last_impact.get("travelled_m", 0.0)),
		]
	hud.update_hud(tank.forward_speed, gunner.cooldown_left, gunner.blocked_reason, hits, cam_rig.sight, control_text, result_text, trial_text, ammo_text, proj_text, impact_text)
	hud.update_debug(Engine.get_frames_per_second(), tank.forward_speed, rad_to_deg(turret.global_rotation.y), rad_to_deg(turret.barrel_pivot.rotation.x), gunner.cooldown_left)
	_update_markers()
	if _autoshot:
		_autoshot_step()
	if _inspect_demo:
		_inspect_demo_step()
	if _query_demo:
		_query_demo_step()

func _inspect_demo_step() -> void:
	# 004-d：检视窗口可见证据模式（-- --inspect-demo）：真实窗口、有限帧、自动退出。
	# 走真实入口链（暂停菜单按钮信号 → open_vehicle_inspector），不绕过 UI。
	if _autoshot_wait > 0:
		_autoshot_wait -= 1
		return
	_shot_step += 1
	match _shot_step:
		40:
			_pause()
		50:
			_shot("inspect_1_pause_menu.png")   # 暂停菜单含 Vehicle Inspector 按钮
			hud.inspect_requested.emit()        # 真实信号链（HUD 按钮按下即发此信号）
		60:
			if not _inspector_open:
				_shot_errors += 1
				printerr("[004-d] FAIL: inspector did not open")
			_shot("inspect_2_appearance.png")   # 外观模式：低模轮廓+履带+炮管
			print("[004-d] inspector open=", _inspector_open, " paused=", get_tree().paused, " (应为 true)")
		70:
			var pv := _preview_model()
			if pv != null:
				pv.set_mode("armor")
			else:
				_shot_errors += 1
				printerr("[004-d] FAIL: preview model not found")
		75:
			_shot("inspect_3_armor.png")        # 装甲模式：状态着色+线框
		80:
			var pv2 := _preview_model()
			if pv2 != null:
				pv2.set_mode("interior")
		85:
			_shot("inspect_4_interior.png")     # 内构模式：模块+乘员
		90:
			# 选中面片（装甲详情面板内容：未知厚度不得显示 0mm）
			var pv3 := _preview_model()
			if pv3 != null:
				pv3.select_patch("hull_front_upper")
		95:
			_shot("inspect_5_details_selected.png")
			var pv4 := _preview_model()
			if pv4 != null:
				pv4.select_patch("")
		97:
			# 004-R2-A：真实滚轮缩远后相机高度（联合约束证据；不另写高度修正）
			var vp_container := _inspector.find_child("PreviewContainer", true, false) as Control
			if vp_container != null:
				var wpos := vp_container.get_global_rect().get_center()
				for i in 6:
					var evd := InputEventMouseButton.new()
					evd.position = wpos
					evd.global_position = wpos
					evd.button_index = MOUSE_BUTTON_WHEEL_DOWN
					evd.pressed = true
					Input.parse_input_event(evd)
					var evu := InputEventMouseButton.new()
					evu.position = wpos
					evu.global_position = wpos
					evu.button_index = MOUSE_BUTTON_WHEEL_DOWN
					evu.pressed = false
					Input.parse_input_event(evu)
		98:
			_shot("inspect_7_zoomed_out.png")
			var cam7 := _inspector._camera
			print("[004-d] zoomed-out camera y=", cam7.global_position.y, " (min 0.13)")
			if cam7.global_position.y < 0.13 - 0.001:
				_shot_errors += 1
				printerr("[004-d] FAIL: camera below ground after zoom-out")
		100:
			if _inspector != null:
				_inspector.close_requested.emit()   # Back/Esc 同一信号链
		105:
			if _inspector_open or not _paused:
				_shot_errors += 1
				printerr("[004-d] FAIL: return-to-pause flow broken (open=", _inspector_open, " paused=", get_tree().paused, ")")
			_shot("inspect_6_back_to_pause.png")   # 返回暂停菜单（游戏仍暂停）
			print("[004-d] back-to-pause: inspector_open=", _inspector_open, " paused=", get_tree().paused)
			print("[inspect-demo] done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			get_tree().quit(1 if (_shot_errors > 0 or _shots_saved < 7) else 0)

func _query_demo_step() -> void:
	# 005-d：查询调试面板可见证据模式（-- --query-demo）：真实窗口、有限帧、自动退出。
	# 走真实入口链（真实 F6 键 → open_query_debug；真实鼠标点击按钮 → run/add/clear/remove），
	# 不绕过 UI；自然收敛炮塔（同 autoshot 332 模式）。
	if _autoshot_wait > 0:
		_autoshot_wait -= 1
		return
	_shot_step += 1
	match _shot_step:
		20:
			# 相机意图指向 B（真实输入意图路径同 autoshot 330/331）
			var d_ab: Vector3 = actor_b.tank.global_position - actor_a.tank.global_position
			cam_rig.aim_yaw = atan2(-d_ab.x, -d_ab.z)
			_autoshot_wait = 2
		21:
			var b_center2: Vector3 = actor_b.tank.global_position + Vector3(0, 1.0, 0)
			var cam_pos2: Vector3 = cam_rig.cam.global_position
			var horiz2: float = Vector3(cam_pos2.x - b_center2.x, 0, cam_pos2.z - b_center2.z).length()
			cam_rig.aim_pitch = atan2(1.0 - cam_pos2.y, horiz2)
			_autoshot_wait = 2
		22:
			# 自然收敛（有限转速追赶，不清零、不 snap）
			if turret.aim_error_deg() > 0.5:
				_demo_poll += 1
				if _demo_poll > 900:
					_shot_errors += 1
					printerr("[query-demo] FAIL: natural aim timeout (err=%.2f°)" % turret.aim_error_deg())
					_demo_poll = 0
				_shot_step -= 1
			else:
				print("[query-demo] barrel locked: err=%.2f° polls=%d" % [turret.aim_error_deg(), _demo_poll])
				_demo_poll = 0
		40:
			_demo_s0 = gunner.shots_fired
			_demo_t0 = trial_hits
			_key_event(KEY_F6)   # 真实 F6 → open_query_debug
			_autoshot_wait = 2
		42:
			if not _query_panel_open:
				_shot_errors += 1
				printerr("[query-demo] FAIL: F6 did not open query panel")
			print("[query-demo] panel open: commands_enabled=", controller.commands_enabled)
			_shot("query_debug_1_panel_open.png")
			_query_panel_click("RunQueryButton")
		52:
			var qr: Dictionary = _query_panel.last_result()
			var evs: Array = _query_panel.last_events()
			if not qr.get("ok", false):
				_shot_errors += 1
				printerr("[query-demo] FAIL: run query not ok")
			if evs.is_empty():
				_shot_errors += 1
				printerr("[query-demo] FAIL: expected >=1 event, got ", evs.size())
			elif str(evs[0].get("entity_id", "")) != "B":
				_shot_errors += 1
				printerr("[query-demo] FAIL: first event entity != B: ", str(evs[0]))
			_shot("query_debug_2_barrel_events.png")
			print("[query-demo] run1: events=", evs.size(), " first_dist=", ("%.2f" % float(evs[0].get("distance_m", 0.0)) if evs.size() > 0 else "-"))
		60:
			# 测试墙：置于首个交点前 1.2m、垂直炮管（显式几何方盒 + LAYER_WORLD 物理体）
			var seg: Dictionary = _query_panel.probe_geometry()
			var fv: Vector3 = seg["from_world"]
			var tv: Vector3 = seg["to_world"]
			var ddir: Vector3 = (tv - fv).normalized()
			var evs2: Array = _query_panel.last_events()
			var first_dist: float = float(evs2[0].get("distance_m", 0.0)) if evs2.size() > 0 else 0.0
			if first_dist <= 1.5:
				_shot_errors += 1
				printerr("[query-demo] FAIL: first event too close for wall placement")
			var wall_pos: Vector3 = fv + ddir * (first_dist - 1.2)
			var wall_yaw: float = rad_to_deg(atan2(ddir.x, -ddir.z))
			_query_panel.set_wall_geometry(wall_pos, Vector3(0.4, 3.0, 3.0), wall_yaw)
			_query_panel_click("AddWallButton")
		62:
			if not _query_panel.has_wall():
				_shot_errors += 1
				printerr("[query-demo] FAIL: Add Test Wall did not add wall")
			_query_panel_click("RunQueryButton")
		72:
			var wall_evs: Array = []
			var armor_evs: Array = []
			for ev in _query_panel.last_events():
				if str(ev.get("kind", "")) == "world":
					wall_evs.append(ev)
				elif str(ev.get("kind", "")) == "armor":
					armor_evs.append(ev)
			if wall_evs.is_empty():
				_shot_errors += 1
				printerr("[query-demo] FAIL: world (test wall) contact missing")
			elif armor_evs.size() > 0 and float(wall_evs[0].get("distance_m", 0.0)) >= float(armor_evs[0].get("distance_m", 0.0)):
				_shot_errors += 1
				printerr("[query-demo] FAIL: wall not before B armor (world=%.2f armor=%.2f)" % [float(wall_evs[0].get("distance_m", 0.0)), float(armor_evs[0].get("distance_m", 0.0))])
			_shot("query_debug_3_test_wall_before_b.png")
			print("[query-demo] run2: world_enter=", ("%.2f" % float(wall_evs[0].get("distance_m", 0.0)) if wall_evs.size() > 0 else "-"), " armor_first=", ("%.2f" % float(armor_evs[0].get("distance_m", 0.0)) if armor_evs.size() > 0 else "-"))
			# 调试查询不得消耗弹药/任务（面板全程未触碰 Gunner/任务计数）
			if gunner.shots_fired != _demo_s0 or trial_hits != _demo_t0:
				_shot_errors += 1
				printerr("[query-demo] FAIL: debug queries consumed ammo/task (shots=%d->%d trial=%d->%d)" % [_demo_s0, gunner.shots_fired, _demo_t0, trial_hits])
		80:
			_query_panel_click("ClearButton")
		82:
			if _query_panel.last_events().size() != 0 or _query_panel.marker_count() != 0:
				_shot_errors += 1
				printerr("[query-demo] FAIL: Clear did not clear results/markers")
			_shot("query_debug_4_cleared.png")
		90:
			_query_panel_click("RemoveWallButton")   # 005-R1-C：移除走独立按钮（显式）
		92:
			if _query_panel.has_wall():
				_shot_errors += 1
				printerr("[query-demo] FAIL: Remove Test Wall did not remove wall")
			_shot("query_debug_5_wall_removed.png")
			print("[query-demo] ammo/task untouched: shots=", gunner.shots_fired, " trial=", trial_hits)
			_key_event(KEY_ESCAPE)   # 真实 Esc → close_query_debug
			_autoshot_wait = 2
		94:
			if _query_panel_open:
				_shot_errors += 1
				printerr("[query-demo] FAIL: Esc did not close query panel")
			print("[query-demo] panel closed: commands_enabled=", controller.commands_enabled)
			_shot("query_debug_6_panel_closed.png")
			print("[query-demo] done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			get_tree().quit(1 if (_shot_errors > 0 or _shots_saved < 6) else 0)

func _query_panel_click(button_name: String) -> void:
	# 005-d：真实鼠标事件点击面板按钮（GUI 事件管线；与 R1-B 继续按钮同一模式）
	if _query_panel == null:
		_shot_errors += 1
		printerr("[query-demo] FAIL: panel not open for button ", button_name)
		return
	var btn := _query_panel.find_child(button_name, true, false) as Button
	if btn == null:
		_shot_errors += 1
		printerr("[query-demo] FAIL: button not found: ", button_name)
		return
	var center: Vector2 = btn.get_global_rect().get_center()
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	press_ev.position = center
	press_ev.global_position = center
	Input.parse_input_event(press_ev)
	var rel_ev := InputEventMouseButton.new()
	rel_ev.button_index = MOUSE_BUTTON_LEFT
	rel_ev.pressed = false
	rel_ev.position = center
	rel_ev.global_position = center
	Input.parse_input_event(rel_ev)

func _preview_model() -> VehiclePreviewModel:
	if _inspector == null:
		return null
	return _inspector._viewport.find_child("PreviewModel", true, false) as VehiclePreviewModel

func _make_marker(sphere: bool, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if sphere:
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.24
		mesh = s
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.22, 0.22, 0.22)
		mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.layers = 1
	add_child(mi)
	return mi

func _in_front(cam_pos: Vector3, cam_fwd: Vector3, p: Vector3) -> bool:
	# 屏幕后方的投影标记隐藏（点积过滤），不跳到错误位置
	return cam_fwd.dot(p - cam_pos) > 0.5

func _update_markers() -> void:
	if _marker_desired == null:
		_marker_desired = _make_marker(true, Color(0.2, 0.9, 1.0))
		_marker_actual = _make_marker(false, Color(1.0, 0.55, 0.1))
	var cam_pos := cam_rig.cam.global_position
	var cam_fwd := -cam_rig.cam.global_transform.basis.z
	var d := cam_rig.intent_point()   # 002-R2：期望瞄点 = 输入意图射线命中点
	var a := gunner.actual_hit_point
	_marker_desired.visible = _in_front(cam_pos, cam_fwd, d)
	_marker_actual.visible = _in_front(cam_pos, cam_fwd, a)
	if _marker_desired.visible:
		_marker_desired.global_position = d
	if _marker_actual.visible:
		_marker_actual.global_position = a

func _autoshot_step() -> void:
	# 截图自检模式（仅 -- --autoshot 启动时）：有限帧、真实抓帧、自动退出。
	# 002 扩展：T002-04 窗口证据（持火跨越暂停/恢复、鼠标重捕获）；
	# 002-R2 扩展：真实鼠标事件验证俯仰响应（下压/水平/上抬）；
	# 003-R1 扩展：正常输入完整演示（自然瞄准→正常输入开火→自然装填→3/3→R 重开）。
	# match 分支不能 await——跨帧等待用 _autoshot_wait（纯等待后推进，不重跑当前步骤）。
	if _autoshot_wait > 0:
		_autoshot_wait -= 1
		return
	_shot_step += 1
	match _shot_step:
		40:
			_shot("autoshot_1_thirdperson.png")
			Input.action_press("aim")
		100:
			_shot("autoshot_2_sight.png")
			Input.action_release("aim")
			Input.action_press("move_forward")
		150:
			_shot("autoshot_3_moved.png")
			Input.action_release("move_forward")
			Input.action_press("fire")   # 持火跨越暂停（T002-04）
		160:
			_pause()
		170:
			_shot("autoshot_4_paused.png")
			print("[T002-04] paused: mouse_mode=", Input.mouse_mode, " (0=VISIBLE) shots=", gunner.shots_fired, " cooldown=", "%.2f" % gunner.cooldown_left)
		180:
			_resume()
			print("[T002-04] resumed: mouse_mode=", Input.mouse_mode, " (2=CAPTURED) grace=", "%.2f" % gunner.resume_grace)
		185:
			var ev_dn := InputEventMouseMotion.new()
			ev_dn.relative = Vector2(0, 60)   # 下压
			Input.parse_input_event(ev_dn)
		186:
			var ev_lv := InputEventMouseMotion.new()
			ev_lv.relative = Vector2(0, -60)   # 回水平
			Input.parse_input_event(ev_lv)
			call_deferred("_print_aim", "after mouse down")
		187:
			var ev_up := InputEventMouseMotion.new()
			ev_up.relative = Vector2(0, -60)   # 上抬
			Input.parse_input_event(ev_up)
			call_deferred("_print_aim", "after mouse level")
		188:
			call_deferred("_print_aim", "after mouse up")
		190:
			Input.action_release("fire")
			_shot("autoshot_5_resumed.png")
			print("[T002-04] after resume+hold: shots=", gunner.shots_fired, "（应与暂停期间一致，无补射）")
			for i in 3:
				_reset_all()   # T002-05 窗口证据：重置不得暂停或释放鼠标
			print("[T002-05] after 3 resets: mouse_mode=", Input.mouse_mode, " paused=", _paused, " (2=CAPTURED, false)")
		200:
			print("[autoshot] phase1 done: shots_saved=", _shots_saved, " errors=", _shot_errors)
		210:
			# 003 演示：重置后把相机转向 B（A 在 (0,0,8)，B 在 (8,0,0) → -45°），
			# 炮塔以有限转速收敛（35°/s × 45° ≈ 77 帧）
			_reset_all()
			cam_rig.aim_yaw = atan2(-8.0, 8.0)
			cam_rig.aim_pitch = 0.0
		290:
			_shot("autoshot_6_two_vehicles.png")   # 第三人称：两辆车同框（A 近景，B 在画面中央）
			print("[003] two_vehicles: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position), " A screen=", cam_rig.cam.unproject_position(actor_a.tank.global_position))
			Input.action_press("aim")
		300:
			_shot("autoshot_7_sight_sees_b.png")   # 炮镜：B 可见（cull_mask 只剔除 A 自身视觉层）
			print("[003] sight: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position), " sight=", cam_rig.sight, " cull_mask=", cam_rig.cam.cull_mask)
			Input.action_release("aim")
			# 试射目标：三次真实生产命中（try_fire 即 PlayerController 调用的同一生产路径）
			gunner.cooldown_left = 0.0
			gunner.resume_grace = 0.0
			gunner.try_fire()
			gunner.cooldown_left = 0.0
			gunner.resume_grace = 0.0
			gunner.try_fire()
			gunner.cooldown_left = 0.0
			gunner.resume_grace = 0.0
			gunner.try_fire()
		310:
			_shot("autoshot_8_trial_complete.png")   # 试射完成：TRIAL COMPLETE 3/3
			print("[003] trial_hits=", trial_hits, " b_hits=", actor_b.tank.hits_taken)
			print("[003-R1] NOTE: autoshot_8 为构造状态演示（清零冷却+直接 try_fire），证明真实命中函数推进 HUD；正常输入完整演示见 autoshot_9~13")
		320:
			print("[autoshot] phase1 done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			# 003-R1：正常输入完整演示——自然瞄准 → 正常输入开火 → 自然装填 → 3/3 → R 重开
			# （不清零冷却、不直接写任务计数、不绕过命令入口）
			_reset_all()
			cam_rig.aim_yaw = atan2(-8.0, 8.0)
			cam_rig.aim_pitch = 0.0
		330:
			# 相机对准 B（模拟玩家鼠标瞄准；B 在 (8,0,0)，A 在 (0,0,8)）——先偏航
			var d_ab: Vector3 = actor_b.tank.global_position - actor_a.tank.global_position
			cam_rig.aim_yaw = atan2(-d_ab.x, -d_ab.z)
			_autoshot_wait = 2   # 等相机轨道/look_at 更新
		331:
			# 相机位置随偏航更新后再算俯仰（瞄 B 中心）
			var b_center2: Vector3 = actor_b.tank.global_position + Vector3(0, 1.0, 0)
			var cam_pos2: Vector3 = cam_rig.cam.global_position
			var horiz2: float = Vector3(cam_pos2.x - b_center2.x, 0, cam_pos2.z - b_center2.z).length()
			cam_rig.aim_pitch = atan2(1.0 - cam_pos2.y, horiz2)
			_autoshot_wait = 2
		332:
			# 003-R2：自然瞄准——不 snap（snap 证明的是"程序预先对齐"），等待炮塔
			# 以有限转速真实追赶意图瞄点并稳定对准；有限超时（900 帧）判失败
			if turret.aim_error_deg() > 0.5:
				_demo_poll += 1
				if _demo_poll > 900:
					_shot_errors += 1
					print("[003-R2] FAIL: natural aim timeout (err=%.2f°)" % turret.aim_error_deg())
					_demo_poll = 0
				_shot_step -= 1   # 原地驻留，继续等待追赶
			else:
				print("[003-R2] natural aim locked: err=%.2f° polls=%d" % [turret.aim_error_deg(), _demo_poll])
				_demo_poll = 0
		333:
			Input.action_press("fire")   # 正常输入开火（第 1 发：Input 边沿 → 命令入口 → 生产命中）
			_autoshot_wait = 2   # 给控制器/物理帧时间消费开火
		334:
			Input.action_release("fire")
			print("[003-R1] shot1: trial_hits=", trial_hits, " cooldown=", "%.2f" % gunner.cooldown_left)
		335:
			if gunner.cooldown_left > 0.0:
				_shot_step -= 1   # 自然装填原地等待（不清零冷却；不重跑 334 的打印）
		336:
			Input.action_press("fire")   # 第 2 发
			_autoshot_wait = 2
		337:
			Input.action_release("fire")
			print("[003-R1] shot2: trial_hits=", trial_hits)
		338:
			if gunner.cooldown_left > 0.0:
				_shot_step -= 1
		339:
			Input.action_press("fire")   # 第 3 发
			_autoshot_wait = 2
		340:
			Input.action_release("fire")
			print("[003-R1] shot3: trial_hits=", trial_hits)
		341:
			if gunner.cooldown_left > 0.0:
				_shot_step -= 1
		342:
			_shot("autoshot_9_trial_normal_complete.png")   # 正常输入/自然装填完成 3/3
			print("[003-R1] normal trial: trial_hits=", trial_hits, " b_hits=", actor_b.tank.hits_taken, " shots_fired=", gunner.shots_fired)
			if trial_hits < TRIAL_TARGET:
				_shot_errors += 1
				print("[003-R1] FAIL: normal-input trial did not reach 3/3")
			_key_event(KEY_R)   # 真实 R 事件 → 整场重开
		343:
			pass   # 等待 R 事件在输入阶段冲刷
		344:
			pass
		345:
			_shot("autoshot_10_trial_restarted.png")   # R 重开后计数归零
			print("[003-R1] after R: trial_hits=", trial_hits, " round=", _gate.round_id)
			if trial_hits != 0:
				_shot_errors += 1
				print("[003-R1] FAIL: R restart did not reset trial")
			cam_rig.aim_yaw = atan2(-8.0, 8.0)
			cam_rig.aim_pitch = 0.0
		346:
			_shot("autoshot_11_two_vehicles_r1.png")   # 两车同框（正常任务演示后）
			print("[003-R1] two_vehicles_r1: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position))
			Input.action_press("aim")
		347:
			pass   # 等炮镜切换
		348:
			_shot("autoshot_12_sight_sees_b_r1.png")   # 炮镜见 B（正常任务演示后）
			print("[003-R1] sight_r1: B screen=", cam_rig.cam.unproject_position(actor_b.tank.global_position), " sight=", cam_rig.sight, " cull_mask=", cam_rig.cam.cull_mask)
			Input.action_release("aim")
		349:
			pass
		350:
			_shot("autoshot_13_hud_r1.png")   # HUD：CONTROL: A (PLAYER) [TEST ONLY] / TRIAL 0/3
			print("[003-R1] hud: control_text 来自实际状态（entity_id + content_tier）")
			print("[autoshot] done: shots_saved=", _shots_saved, " errors=", _shot_errors)
			get_tree().quit(1 if (_shot_errors > 0 or _shots_saved < 13) else 0)   # 必需截图失败 → 自检非零

func _key_event(k: Key) -> void:
	# 003-R1：真实按键事件（按下+释放）经 Input.parse_input_event 走完整输入管线
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = k
	ev2.physical_keycode = k
	ev2.pressed = false
	Input.parse_input_event(ev2)

func _print_aim(label: String) -> void:
	# 002-R2：帧末（相机 _process 之后）打印意图俯仰与相机前向俯仰的匹配对
	print("[R2-A] ", label, ": aim_pitch=", "%.2f" % rad_to_deg(cam_rig.aim_pitch), " cam_fwd_pitch=", "%.2f" % rad_to_deg(asin(-cam_rig.cam.global_transform.basis.z.y)))

func _shot(rel: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("[autoshot] FAILED to capture ", rel)
		_shot_errors += 1
		return
	var path := ProjectSettings.globalize_path("res://" + _shot_dir + "/" + rel)
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(path)
	if err == OK:
		print("[autoshot] saved ", path)
		_shots_saved += 1
	else:
		print("[autoshot] FAILED (err=", err, ") to save ", path)
		_shot_errors += 1