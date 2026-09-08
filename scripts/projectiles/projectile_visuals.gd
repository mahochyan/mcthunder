class_name ProjectileVisuals
extends Node3D
## 006-R1-C：飞弹可见显示层——由 ProjectileState 驱动的可见弹体 + 短尾迹。
## 职责边界：只读模拟状态（sync_projectiles 传入快照/状态列表），
## 不写回炮弹位置、不参与命中判定或计分；本层整体禁用时弹道与计分结果不变。
## 接口：sync_projectiles(states) / present_terminal(record) / clear_all()。
## 尾迹只使用已经模拟过的位置（状态列表里的 previous/position），
## 不向目标方向预画任何线段。

const TRAIL_LEN := 12          # 尾迹点数（每步一个已模拟位置）
const DOT_RADIUS := 0.22

var _vis: Dictionary = {}      # projectile_id -> Node3D（弹体，携带尾迹元数据）
var _trail_mesh: ImmediateMesh
var _trail_mi: MeshInstance3D
var _dot_mesh: SphereMesh
var _fx: Array = []            # 终止接触效果 [{node, left}]

func _ready() -> void:
	_trail_mesh = ImmediateMesh.new()
	_trail_mi = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mi.mesh = _trail_mesh
	_trail_mi.material_override = mat
	_trail_mi.top_level = true
	add_child(_trail_mi)
	_dot_mesh = SphereMesh.new()
	_dot_mesh.radius = DOT_RADIUS
	_dot_mesh.height = DOT_RADIUS * 2.0
	_dot_mesh.radial_segments = 8
	_dot_mesh.rings = 4

func sync_projectiles(states: Array) -> void:
	# 每帧由装配方调用：states = 管理器 active_states()（唯一实例列表）。
	# 创建/更新对应视觉对象；已消失的 id 不在此删除（由 present_terminal 终结显示）。
	var seen: Dictionary = {}
	for st in states:
		if st == null:
			continue
		var pid := int(st.projectile_id)
		seen[pid] = true
		var node: Node3D = _vis.get(pid)
		if node == null:
			node = _make_dot(pid)
			_vis[pid] = node
		node.global_position = st.position_world
		var trail: Array = node.get_meta("trail", [])
		trail.append(st.position_world)
		while trail.size() > TRAIL_LEN:
			trail.pop_front()
		node.set_meta("trail", trail)
	_rebuild_trails()
	# 终止接触效果衰减
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Dictionary = _fx[i]
		fx["left"] = float(fx["left"]) - get_process_delta_time()
		var n: Node3D = fx["node"]
		var s: float = maxf(0.2, float(fx["left"]) / 0.25)
		n.scale = Vector3(s, s, s)
		if float(fx["left"]) <= 0.0:
			n.queue_free()
			_fx.remove_at(i)

func present_terminal(record: Dictionary) -> void:
	# 在真实终止位置结束该发显示：移除飞弹，留一个短暂接触标记（0.25s 收缩消失）。
	var pid := int(record.get("projectile_id", 0))
	var node: Node3D = _vis.get(pid)
	if node != null:
		node.queue_free()
		_vis.erase(pid)
	_rebuild_trails()
	var p: Vector3 = record.get("impact_point", Vector3.ZERO)
	if p == Vector3.ZERO:
		return
	var fx := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = DOT_RADIUS * 1.6
	m.height = DOT_RADIUS * 3.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.2, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx.mesh = m
	fx.material_override = mat
	fx.top_level = true
	add_child(fx)
	fx.global_position = p
	_fx.append({"node": fx, "left": 0.25})

func clear_all() -> void:
	# 重开/切场景/销毁：清空全部视觉与接触效果（不产生命中事件）
	for pid in _vis.keys():
		var node: Node3D = _vis[pid]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_vis.clear()
	for fx in _fx:
		var n: Node3D = fx["node"]
		if n != null and is_instance_valid(n):
			n.queue_free()
	_fx.clear()
	_trail_mesh.clear_surfaces()

func visual_count() -> int:
	# 测试/验证用：当前在飞视觉对象数量
	return _vis.size()

func _make_dot(pid: int) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = "Proj_%d" % pid
	node.mesh = _dot_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.35)
	node.material_override = mat
	node.top_level = true
	add_child(node)
	return node

func _rebuild_trails() -> void:
	_trail_mesh.clear_surfaces()
	for pid in _vis.keys():
		var node: Node3D = _vis[pid]
		var trail: Array = node.get_meta("trail", [])
		if trail.size() < 2:
			continue
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in trail:
			_trail_mesh.surface_add_vertex(Vector3(p))
		_trail_mesh.surface_end()
