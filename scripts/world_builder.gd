class_name WorldBuilder
extends Node3D
## 靶场搭建（职责：静态世界）。地面 / 围墙 / 可碰撞箱子 / 三块静态靶板 / 光照天空。
## 全部用 Godot 基础几何体与脚本搭建，无外部模型。1 单位 = 1 米。

const GROUND_HALF := 30.0
const WALL_H := 3.0
const WALL_T := 1.0
const BOARD_POS: Array[Vector3] = [Vector3(-12, 0, -20), Vector3(0, 0, -22), Vector3(12, 0, -20)]
const BOX_POS: Array[Vector3] = [
	Vector3(-8, 0.6, 2), Vector3(9, 0.6, -6), Vector3(-16, 0.6, -10),
	Vector3(15, 0.6, 6), Vector3(-3, 0.6, -14), Vector3(6, 0.6, 14),
]
const TANK_SPAWN := Vector3(0, 0, 8)

var targets: Array = []

func build() -> void:
	_ground()
	_walls()
	for p in BOX_POS:
		build_box(p, Vector3(1.2, 1.2, 1.2), Color(0.65, 0.52, 0.35))
	for p in BOARD_POS:
		targets.append(_target(p))
	_light_and_sky()

func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(GROUND_HALF * 2.0, 0.5, GROUND_HALF * 2.0)
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.4, 0.3)
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	body.position = Vector3(0, -0.25, 0)
	add_child(body)

func _walls() -> void:
	var half := GROUND_HALF - WALL_T * 0.5
	build_wall(Vector3(0, WALL_H * 0.5, -half), Vector3(GROUND_HALF * 2.0, WALL_H, WALL_T))
	build_wall(Vector3(0, WALL_H * 0.5, half), Vector3(GROUND_HALF * 2.0, WALL_H, WALL_T))
	build_wall(Vector3(-half, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, GROUND_HALF * 2.0))
	build_wall(Vector3(half, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, GROUND_HALF * 2.0))

func build_wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	return _block(pos, size, Color(0.58, 0.58, 0.6))

func build_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	return _block(pos, size, color)

func _block(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	body.position = pos
	add_child(body)
	return body

func _target(pos: Vector3) -> TargetBoard:
	var board := TargetBoard.new()
	board.position = pos
	add_child(board)
	return board

func _light_and_sky() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)