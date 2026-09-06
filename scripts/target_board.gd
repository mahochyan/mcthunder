class_name TargetBoard
extends StaticBody3D
## 静态靶板（职责：命中计数 + 短暂变色反馈）。碰撞层 WORLD；被射中由 Gunner 调 register_hit。

const BASE_COLOR := Color(0.85, 0.22, 0.18)
const FLASH_COLOR := Color(1.0, 0.92, 0.3)
const FLASH_TIME := 0.25

var hit_count := 0
var _flash_left := 0.0
var _board_mesh: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	collision_layer = GameConfig.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.8, 0.4)
	cs.shape = shape
	cs.position = Vector3(0, 1.4, 0)
	add_child(cs)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.08
	pm.height = 0.9
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.3, 0.3, 0.3)
	pm.material = pmat
	pole.mesh = pm
	pole.position = Vector3(0, 0.45, 0)
	add_child(pole)
	_board_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 2.0, 0.15)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = BASE_COLOR
	bm.material = _mat
	_board_mesh.mesh = bm
	_board_mesh.position = Vector3(0, 1.9, 0)
	add_child(_board_mesh)

func register_hit() -> void:
	hit_count += 1
	_flash_left = FLASH_TIME

func reset() -> void:
	hit_count = 0
	_flash_left = 0.0
	_mat.albedo_color = BASE_COLOR

func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_mat.albedo_color = FLASH_COLOR if _flash_left > 0.0 else BASE_COLOR