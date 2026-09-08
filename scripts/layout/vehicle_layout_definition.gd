class_name VehicleLayoutDefinition
extends Resource

# 004-a：整车结构布局定义（schema_version=1 是布局 schema，
# 不重置现有 VehicleDefinition 的版本）。
# 纯结构数据——姿态/选中/可见状态不得写回共享加载的定义。

@export var schema_version: int = 1
@export var id: String = ""
@export var historical_identity_id: String = ""
@export_enum("test", "research", "production") var content_tier: String = "test"
@export var display_name: String = ""
@export var recovery_enabled: bool = false # Explicit opt-in; legacy/008 fixtures preserve their rules.

@export var parts: Array[LayoutPartDefinition] = []
@export var armor_patches: Array[ArmorPatchDefinition] = []
@export var modules: Array[ModuleVolumeDefinition] = []
@export var crew_stations: Array[CrewStationDefinition] = []

@export var source_catalog_id: String = ""
@export var field_evidence_id: String = ""
@export var declared_openings: Array[Dictionary] = []   # 真实结构开口（炮塔环/炮口等，非"例外"兜底）
@export var allowed_overlaps: Array[Dictionary] = []    # 确认的有意重叠：具体对象对 + 原因
