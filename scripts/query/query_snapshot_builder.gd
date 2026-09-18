class_name QuerySnapshotBuilder
extends RefCounted
## 005：把布局与当前部件姿态组成一份查询快照。
## 快照中的变换在一次查询期间保持不变；不持有可能已被释放的 Node 引用
## （只读 global_transform 与 Resource 引用，不保存 Node 指针）。
## 部件变换只乘一次：从节点读 global_transform（已含父链），不再乘 bind_local。

const PART_HULL := "hull"
const PART_TURRET := "turret"
const PART_BARREL := "barrel"


static func build_from_vehicle(vehicle: TankVehicle, layout: VehicleLayoutDefinition) -> Dictionary:
	# 返回实体快照；vehicle 为 null 或缺少节点时返回空字典（调用方跳过）。
	# 部件变换只读一次；缺失的布局部件登记到 missing_parts（服务据此明确失败，
	# 不用单位变换伪装）。非有限变换同样登记。
	if vehicle == null or not is_instance_valid(vehicle):
		return {}
	var transforms := {}
	var missing: Array = []
	transforms[PART_HULL] = vehicle.hull_frame.global_transform
	transforms["drive"] = vehicle.global_transform
	transforms[TrackAssembly.LEFT] = vehicle.track_left_frame.global_transform
	transforms[TrackAssembly.RIGHT] = vehicle.track_right_frame.global_transform
	if vehicle.turret_rig != null and is_instance_valid(vehicle.turret_rig):
		transforms[PART_TURRET] = vehicle.turret_rig.global_transform
		if vehicle.turret_rig.barrel_pivot != null and is_instance_valid(vehicle.turret_rig.barrel_pivot):
			transforms[PART_BARREL] = vehicle.turret_rig.barrel_pivot.global_transform
		else:
			missing.append(PART_BARREL)
	else:
		missing.append(PART_TURRET)
		missing.append(PART_BARREL)
	for part in layout.parts:
		if part == null:
			continue
		var t: Transform3D = transforms.get(part.id, Transform3D.IDENTITY)
		if not transforms.has(part.id):
			missing.append(part.id)
		elif not t.is_finite():
			missing.append(part.id)
			transforms.erase(part.id)
	# 副本语义：调用方改动该字典不影响快照；不持有 Node 引用
	var out := {
		"entity_id": vehicle.entity_id,
		"life_id": vehicle.life_id,
		"target_generation":vehicle.state_generation,
		"definition_id": vehicle.defs.id if vehicle.defs != null else "",
		"layout_id": layout.id,
		"layout_revision": layout.schema_version,
		"part_world_transforms": transforms.duplicate(true),
		"missing_parts": missing.duplicate(),
		"layout": layout,
	}
	# WT-CD-001 design points 2 and 5 / CD01-T06: the query snapshot carries the dynamic ammunition occupancy and the
	# revision it was taken from, so the narrow phase can leave an exhausted contents volume out and a commit can refuse
	# a stale request. A dynamic inventory result is never cached under the fixed layout id, and when the occupancy
	# cannot be read the snapshot simply omits it - absence means unknown, never an empty rack.
	var host := vehicle.get_parent()
	if host is VehicleActor and host.gunner != null:
		out["ammo_contents"] = host.gunner.inventory.occupancy_snapshot()
		out["occupancy_revision"] = host.gunner.inventory.occupancy_revision
	else:
		out["occupancy_revision"] = -1
	# The proposed contract CombatQuerySnapshotV2 also names the tick and the motion fraction, so a snapshot states when
	# its facts were taken. The tick is read from the engine rather than passed in, so a caller cannot supply a stale one,
	# and the fraction is the current pose (a swept range stays a property of the request, not of the snapshot).
	out["physics_tick"] = Engine.get_physics_frames()
	out["motion_fraction"] = Vector2.ONE
	return out


static func build_identity_snapshot(
		entity_id: String,
		life_id: int,
		definition_id: String,
		layout: VehicleLayoutDefinition,
		part_world_transforms: Dictionary
	) -> Dictionary:
	# 纯数据快照（测试/调试面板用，不依赖场景树节点）。
	# 变换字典深拷贝：之后调用方修改原字典不影响旧快照（固定姿态语义）。
	var missing: Array = []
	for t in part_world_transforms.values():
		if t is Transform3D and not t.is_finite():
			missing.append("non_finite")
	return {
		"entity_id": entity_id,
		"life_id": life_id,
		"definition_id": definition_id,
		"layout_id": layout.id,
		"layout_revision": layout.schema_version,
		"part_world_transforms": part_world_transforms.duplicate(true),
		"missing_parts": missing.duplicate(),
		"layout": layout,
	}
