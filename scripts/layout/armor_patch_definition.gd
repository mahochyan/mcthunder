class_name ArmorPatchDefinition
extends Resource

# 004-a：一块有限装甲面片（外表面 + 厚度属性 + 依据状态）。
# 不是整车碰撞盒；车体各面/炮塔各区独立 ID 与有限边界。
# 未知厚度：has_thickness=false + thickness_status="unknown"，
# 不允许 thickness_mm=0 冒充无防护。
# 数据三角形 (b-a)×(c-a) 与 outward_normal_local 同向。

@export var id: String = ""
@export var plate_group_id: String = ""
@export var part_id: String = ""

@export var vertices_local_m: PackedVector3Array = PackedVector3Array()
@export var triangles: PackedInt32Array = PackedInt32Array()
@export var outward_normal_local: Vector3 = Vector3.ZERO

@export var has_thickness: bool = false
@export var thickness_mm: float = 0.0
@export var material_kind: String = "unknown"   # rolled / cast / unknown
@export var geometry_status: String = "unknown" # verified / estimated / unknown
@export var thickness_status: String = "unknown" # verified / estimated / unknown
@export var evidence_keys: PackedStringArray = []