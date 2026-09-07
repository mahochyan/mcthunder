class_name LayoutPartDefinition
extends Resource

# 004-a：布局运动层级部件（hull/turret/gun 层级、bind 变换与关节类型）。
# bind_local = 零姿态下相对父部件的刚体变换；joint_kind = fixed/yaw/pitch。
# 炮手随炮塔偏航不随主炮俯仰；炮闩跟随火炮俯仰。

@export var id: String = ""
@export var parent_id: String = ""            # 根部件为空
@export var bind_local: Transform3D = Transform3D.IDENTITY
@export var joint_kind: String = "fixed"      # fixed / yaw / pitch
@export var min_angle_deg: float = 0.0
@export var max_angle_deg: float = 0.0
@export var evidence_keys: PackedStringArray = []