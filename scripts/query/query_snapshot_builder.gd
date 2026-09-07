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
	if vehicle == null or not is_instance_valid(vehicle):
		return {}
	var transforms := {}
	transforms[PART_HULL] = vehicle.global_transform
	if vehicle.turret_rig != null and is_instance_valid(vehicle.turret_rig):
		transforms[PART_TURRET] = vehicle.turret_rig.global_transform
		if vehicle.turret_rig.barrel_pivot != null and is_instance_valid(vehicle.turret_rig.barrel_pivot):
			transforms[PART_BARREL] = vehicle.turret_rig.barrel_pivot.global_transform
	return {
		"entity_id": vehicle.entity_id,
		"life_id": vehicle.life_id,
		"definition_id": vehicle.defs.id if vehicle.defs != null else "",
		"layout_id": layout.id,
		"layout_revision": layout.schema_version,
		"part_world_transforms": transforms,
		"layout": layout,
	}


static func build_identity_snapshot(
		entity_id: String,
		life_id: int,
		definition_id: String,
		layout: VehicleLayoutDefinition,
		part_world_transforms: Dictionary
	) -> Dictionary:
	# 纯数据快照（测试/调试面板用，不依赖场景树节点）。
	return {
		"entity_id": entity_id,
		"life_id": life_id,
		"definition_id": definition_id,
		"layout_id": layout.id,
		"layout_revision": layout.schema_version,
		"part_world_transforms": part_world_transforms,
		"layout": layout,
	}