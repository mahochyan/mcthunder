class_name ModuleVolumeDefinition
extends Resource

# 004-a：内部空间占用（有向方盒：位置 + 旋转 + 长宽高）。
# 一个方盒代表什么、包住哪部分、为何此尺寸——由依据记录说明。
# 防火隔板/地板等结构件不自动变成装甲；防护属性未知就标 unknown。

@export var id: String = ""
@export var kind: String = ""                 # engine / transmission / driveshaft / breech / turret_drive / fuel / ammo / radio / track 等
@export var part_id: String = ""              # 所属运动部件（hull/turret/gun）
@export var local_box_transform: Transform3D = Transform3D.IDENTITY
@export var size_m: Vector3 = Vector3.ZERO
@export var enclosure_id: String = ""         # 所属封闭腔体（如战斗舱/动力舱）
@export var external: bool = false            # 外部体积（如左右履带）不按内部模块校验
@export var geometry_status: String = "unknown" # verified / estimated / unknown
@export var evidence_keys: PackedStringArray = []