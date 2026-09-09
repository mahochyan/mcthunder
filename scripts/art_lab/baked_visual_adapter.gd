class_name BakedVisualAdapter
extends RefCounted
## ART-001 单车烘焙试产——仅测试模式使用：
## bind() 隐藏程序装配视觉（Skin_*/Cosmetic_*/TrackMotion/RecoilVisual/程序炮管），
## 按部件清单把烘焙低模叶网格挂到各部件下的候选容器，所有新增节点归容器所有，
## restore() 移除全部容器并完整还原旧视觉状态。碰撞/射击/履带物理逻辑完全不动。

const BAKED_SCENE := "res://assets/art001/m4a3_pilot/m4a3_1k.glb"
## 部件 → 必需叶网格名单（每个都必须在对应部件下恰好出现一次；防漏件/错件/重复）
const PART_MESHES := {
	"hull": ["LOW_hull_Shell", "LOW_hull_Hatches", "LOW_wheels", "LOW_tracks"],
	"turret": ["LOW_turret_Shell", "LOW_turret_Cupola"],
	"barrel": ["LOW_gun_Tube", "LOW_barrel_Shell"],
}

var _hidden: Array[Dictionary] = []            # [{"node": Node, "visible": bool}]
var _spawned_roots: Array[Node3D] = []         # 各部件候选容器（所有新增网格的归属）
var _recoil_old: Node3D = null                 # 原 recoil_visual 引用（还原时接回）
var _track_motion: Node = null                 # 动态履带节点（绑定期间停更新）
var _track_was_processing := false
var _bound := false

## 候选网格实例清单（遍历全部候选容器，供材质变体切换）
func mesh_instances() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for container in _spawned_roots:
		if is_instance_valid(container):
			_collect(container, out)
	return out

## bind(actor, whitelist=null)：whitelist 供反例测试注入缺失名单；缺省用 PART_MESHES
func bind(actor: VehicleActor, whitelist: Dictionary = {}) -> Dictionary:
	if _bound:
		return {"ok": false, "error": "already bound"}   # 先检查，未动任何状态
	var wl := PART_MESHES if whitelist.is_empty() else whitelist
	# 1. 验证资源与部件覆盖——每个必需网格在对应部件下恰好一次；全部通过前不动原车
	var scene := load(BAKED_SCENE) as PackedScene
	if scene == null:
		return {"ok": false, "error": "missing baked scene " + BAKED_SCENE}
	var source := scene.instantiate() as Node3D
	if source == null:
		return {"ok": false, "error": "cannot instantiate baked scene"}
	var part_meshes := {}
	for part in wl:
		var authored: Node = source if str(source.name) == part else source.find_child(part, true, false)
		var list: Array[MeshInstance3D] = []
		if authored != null:
			# 部件下实际存在的全部网格名（精确集合：少件/错件/重复/多件都拒绝）
			var actual := {}
			for ch in authored.get_children():
				if ch is MeshInstance3D:
					actual[str(ch.name)] = true
			for wanted in wl[part]:
				if not actual.has(str(wanted)):
					source.free()
					return {"ok": false, "error": "whitelist mesh %s missing in part %s" % [str(wanted), str(part)]}
				list.append(authored.find_child(str(wanted), true, false) as MeshInstance3D)
			for extra in actual:
				if not (extra in wl[part]):
					source.free()
					return {"ok": false, "error": "part %s has unlisted mesh %s (whitelist incomplete)" % [str(part), extra]}
		if list.is_empty():
			source.free()
			return {"ok": false, "error": "missing baked meshes for part " + str(part)}
		part_meshes[part] = list
	# 2. 保存旧视觉状态并隐藏（程序装甲/细节/动态履带/后坐炮身/程序炮管）
	for parent in [actor.tank, actor.turret, actor.turret.barrel_pivot]:
		for child in parent.get_children():
			var n := str(child.name)
			var is_old: bool = n.begins_with("Skin_") or n.begins_with("Cosmetic") \
				or child is M4TrackMotion or child == actor.turret.recoil_visual \
				or child == actor.turret.barrel_mesh
			if is_old and child is Node3D:
				_hidden.append({"node": child, "visible": (child as Node3D).visible})
				(child as Node3D).visible = false
	# 动态履带：隐藏并暂停其专用更新（不影响车辆驾驶/炮塔回调），还原时恢复
	for child in actor.tank.get_children():
		if child is M4TrackMotion:
			_track_motion = child
			_track_was_processing = (child as Node).is_processing()
			(child as Node).set_process(false)
	# 3. 建部件候选容器并只导入对应叶网格（局部恒等：GLB 子件已按源约定）
	var added := 0
	for part in wl:
		var parent2: Node3D = actor.tank if part == "hull" \
			else (actor.turret if part == "turret" else actor.turret.barrel_pivot)
		var container := Node3D.new()
		container.name = "BakedPilotVisual_%s" % part
		parent2.add_child(container)
		_spawned_roots.append(container)
		# 后坐接线（只对炮管）：独立后坐子节点只装 LOW_gun_Tube，
		# 炮盾 LOW_barrel_Shell 留在俯仰容器不随后坐；还原先接回旧引用
		var recoil_root: Node3D = null
		if part == "barrel":
			recoil_root = Node3D.new()
			recoil_root.name = "BakedPilotGunRecoil"
			container.add_child(recoil_root)
		for src_mesh in part_meshes[part]:
			var dup := (src_mesh as MeshInstance3D).duplicate() as MeshInstance3D
			if part == "barrel" and str(src_mesh.name) == "LOW_gun_Tube":
				recoil_root.add_child(dup)
			else:
				container.add_child(dup)
			_set_layers(dup, actor.tank.visual_layer)
			added += 1
		if part == "barrel":
			_recoil_old = actor.turret.recoil_visual
			actor.turret.recoil_visual = recoil_root
	source.free()
	_bound = true
	return {"ok": true, "hidden": _hidden.size(), "added": added, "parts": _spawned_roots.size()}

func restore(actor: VehicleActor) -> Dictionary:
	# 先接回旧后坐引用，再释放候选容器
	if _recoil_old != null and is_instance_valid(_recoil_old):
		actor.turret.recoil_visual = _recoil_old
	_recoil_old = null
	var removed := 0
	for container in _spawned_roots:
		if is_instance_valid(container):
			container.get_parent().remove_child(container)
			container.free()
			removed += 1
	_spawned_roots.clear()
	var restored := 0
	for rec in _hidden:
		var node: Node = rec["node"]
		if is_instance_valid(node):
			(node as Node3D).visible = bool(rec["visible"])
			restored += 1
	_hidden.clear()
	if _track_motion != null and is_instance_valid(_track_motion):
		(_track_motion as Node).set_process(_track_was_processing)
	_track_motion = null
	_bound = false
	return {"ok": true, "removed_containers": removed, "restored": restored}

## 候选三角数（仅候选容器；整车审计另见 audit_no_leftover）
func candidate_tri_count() -> int:
	var total := 0
	for mi in mesh_instances():
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.size() > 0:
				total += idx.size() / 3
			elif arrays[Mesh.ARRAY_VERTEX] != null:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total

## 整车可见几何独立审计：actor 下不允许残留任何可见的旧外观
## （Skin_*/Cosmetic*/TrackMotion/程序炮管/旧后坐炮身）。返回残留可见节点名清单。
static func audit_no_leftover(actor: VehicleActor) -> Array[String]:
	var leftovers: Array[String] = []
	for parent in [actor.tank, actor.turret, actor.turret.barrel_pivot]:
		for child in parent.get_children():
			var n := str(child.name)
			var is_old: bool = n.begins_with("Skin_") or n.begins_with("Cosmetic") \
				or child is M4TrackMotion or child == actor.turret.barrel_mesh
			if is_old and child is Node3D and (child as Node3D).visible:
				leftovers.append(str(parent.name) + "/" + n)
	if actor.turret.recoil_visual != null and actor.turret.recoil_visual.visible \
			and not str(actor.turret.recoil_visual.name).begins_with("BakedPilot"):
		leftovers.append("recoil_visual visible: " + str(actor.turret.recoil_visual.name))
	return leftovers

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect(c, out)

## 对齐校验（绑定态 + 真实部件变换 + 可施加姿态）：候选容器内 Shell 网格顶点
## 世界位置 vs 同部件布局角点世界位置。施加炮塔偏航/火炮俯仰后审计，完成复原姿态。
static func audit_alignment(adapter: BakedVisualAdapter, actor: VehicleActor,
		patches: Array, tolerance_m: float, turret_yaw: float = 0.0,
		gun_pitch: float = 0.0) -> Dictionary:
	if patches.is_empty():
		return {"ok": false, "error": "no armor patches"}
	var part_patches := {"hull": [], "turret": [], "barrel": []}
	for patch2 in patches:
		var pid := str(patch2.part_id)
		if part_patches.has(pid):
			part_patches[pid].append(patch2)
	# 施加姿态
	var yaw0 := actor.turret.rotation.y
	var pitch0 := actor.turret.barrel_pivot.rotation.x
	actor.turret.rotation.y = turret_yaw
	actor.turret.barrel_pivot.rotation.x = gun_pitch
	# 姿态下的部件节点世界变换（角点为部件局部 → 世界）
	var corners_by_part := {"hull": [], "turret": [], "barrel": []}
	for pid in part_patches:
		for patch2 in part_patches[pid]:
			for v2 in patch2.vertices_local_m:
				var corner := Vector3(float(v2[0]), float(v2[1]), float(v2[2]))
				if pid == "hull":
					corners_by_part["hull"].append(actor.tank.global_transform * corner)
				elif pid == "turret":
					corners_by_part["turret"].append(actor.turret.global_transform * corner)
				elif pid == "barrel":
					corners_by_part["barrel"].append(actor.turret.barrel_pivot.global_transform * corner)
	# 遍历候选容器内的 Shell 网格
	var worst := 0.0
	var checked := 0
	var ok := true
	var empty_parts := []
	for container in adapter._spawned_roots:
		if not is_instance_valid(container):
			continue
		var part := str(container.name).trim_prefix("BakedPilotVisual_")
		var corners: Array = corners_by_part.get(part, [])
		if corners.is_empty():
			empty_parts.append(part)
			ok = false
			continue
		for mi in adapter.mesh_instances():
			if not str(mi.name).contains("Shell") or not container.is_ancestor_of(mi):
				continue
			var arrays := (mi as MeshInstance3D).mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for mv in verts:
				var world_v: Vector3 = (mi as MeshInstance3D).global_transform * mv
				var best := INF
				for corner in corners:
					best = min(best, (corner as Vector3).distance_to(world_v))
				checked += 1
				if best > worst:
					worst = best
				if best > tolerance_m:
					ok = false
	# 复原姿态
	actor.turret.rotation.y = yaw0
	actor.turret.barrel_pivot.rotation.x = pitch0
	var result := {"ok": ok, "checked": checked, "worst_m": worst,
		"turret_yaw": turret_yaw, "gun_pitch": gun_pitch}
	if not empty_parts.is_empty():
		result["error"] = "no patches for parts " + str(empty_parts)
	return result

func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer
	for child in node.get_children():
		_set_layers(child, layer)