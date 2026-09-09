class_name BakeComparison
extends RefCounted
## ART-001 A/B/C 材质变体：同一几何、同一 UV。
## A=纯色；B=BaseColor+ORM（无法线）；C=B+高模切线法线。B 与 C 仅法线开关不同。

const DIR := "res://assets/art001/m4a3_pilot/"

static func material_for(variant: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if variant == "A":
		m.albedo_color = Color(0.384, 0.427, 0.286)
		m.roughness = 0.78
		m.metallic = 0.1
		return m
	var orm := load(DIR + "orm.png") as Texture2D
	m.albedo_texture = load(DIR + "basecolor.png")
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if variant == "C":
		m.normal_enabled = true
		m.normal_texture = load(DIR + "normal_gl.png")
		m.normal_scale = 1.0
	return m

## 对一批网格实例应用变体；返回应用材质（供断言：C 的 normal_enabled=true）
static func set_variant(mesh_instances: Array, variant: String) -> StandardMaterial3D:
	var m := material_for(variant)
	for mi in mesh_instances:
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).material_override = m
	return m