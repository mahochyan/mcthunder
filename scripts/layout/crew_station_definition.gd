class_name CrewStationDefinition
extends Resource

# 004-a：乘员岗位（空间方盒近似；不实现生命值/技能/失能）。
# M4A3 五岗位：commander / gunner / loader / driver / assistant_driver_bow_gunner，
# 不建四人通用模板。岗位与相对位置依据乘员手册。

@export var id: String = ""
@export var role: String = ""                 # commander / gunner / loader / driver / assistant_driver_bow_gunner
@export var part_id: String = ""              # 所属运动部件（炮手/装填手/车长挂 turret）
@export var local_box_transform: Transform3D = Transform3D.IDENTITY
@export var size_m: Vector3 = Vector3.ZERO
@export var position_status: String = "unknown" # verified / estimated / unknown
@export var volume_status: String = "unknown"   # verified / estimated / unknown
@export var evidence_keys: PackedStringArray = []