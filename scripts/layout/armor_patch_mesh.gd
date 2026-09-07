class_name ArmorPatchMesh
extends RefCounted

# 004-a（GPT 参考实现）：单块装甲面片的几何校验与渲染网格。
# 数据三角形约定：(b - a).cross(c - a) 与 outward_normal_local 同向；
# Godot 渲染正面为顺时针绕序，故 build_surface 提交时反转索引——
# 不反转历史外法线去迁就渲染。
# Compatibility 渲染器不支持 Viewport Debug Draw 线框模式，
# 因此 build_wire 用实际线段网格实现。

const AREA_EPS := 0.00000001
const PLANE_EPS_M := 0.0001


static func validate_geometry(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		outward_normal: Vector3
	) -> PackedStringArray:

	var errors := PackedStringArray()

	if vertices.size() < 3:
		errors.append("vertices: at least three are required")
		return errors

	for vertex in vertices:
		if not vertex.is_finite():
			errors.append("vertices: non-finite coordinate")
			return errors

	if indices.is_empty() or indices.size() % 3 != 0:
		errors.append("triangles: index count must be a positive multiple of 3")
		return errors

	for index in indices:
		if index < 0 or index >= vertices.size():
			errors.append("triangles: index out of bounds")
			return errors

	if not outward_normal.is_finite():
		errors.append("normal: non-finite")
		return errors

	if absf(outward_normal.length() - 1.0) > 0.0001:
		errors.append("normal: must be unit length")
		return errors

	var n := outward_normal
	var origin := vertices[0]

	for vertex in vertices:
		if absf(n.dot(vertex - origin)) > PLANE_EPS_M:
			errors.append("vertices: patch is not planar")
			return errors

	for start in range(0, indices.size(), 3):
		var a := vertices[indices[start]]
		var b := vertices[indices[start + 1]]
		var c := vertices[indices[start + 2]]
		var cross := (b - a).cross(c - a)

		if cross.length() <= AREA_EPS:
			errors.append("triangles: degenerate triangle")
		elif cross.normalized().dot(n) < 0.999:
			errors.append("triangles: winding disagrees with outward normal")

	return errors


static func build_surface(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		outward_normal: Vector3
	) -> ArrayMesh:

	var errors := validate_geometry(vertices, indices, outward_normal)
	if not errors.is_empty():
		push_error("ArmorPatchMesh: " + "; ".join(errors))
		return null

	var render_indices := PackedInt32Array()
	for start in range(0, indices.size(), 3):
		render_indices.append(indices[start])
		render_indices.append(indices[start + 2])
		render_indices.append(indices[start + 1])

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for index in range(normals.size()):
		normals[index] = outward_normal

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices.duplicate()
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = render_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build_wire(
		vertices: PackedVector3Array,
		indices: PackedInt32Array,
		outward_normal: Vector3
	) -> ArrayMesh:

	var errors := validate_geometry(vertices, indices, outward_normal)
	if not errors.is_empty():
		push_error("ArmorPatchMesh wire: " + "; ".join(errors))
		return null

	var seen: Dictionary = {}
	var line_indices := PackedInt32Array()

	for start in range(0, indices.size(), 3):
		for offset in range(3):
			var a := indices[start + offset]
			var b := indices[start + ((offset + 1) % 3)]
			var lo := mini(a, b)
			var hi := maxi(a, b)
			var key := "%d:%d" % [lo, hi]

			if seen.has(key):
				continue

			seen[key] = true
			line_indices.append(a)
			line_indices.append(b)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices.duplicate()
	arrays[Mesh.ARRAY_INDEX] = line_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


# --- T004-04：面片焊接 ---
# 各面片顶点独立存储（同坐标不同索引）；封闭性检查前按坐标焊接为单一网格。
# 返回 {"vertices": PackedVector3Array, "triangles": PackedInt32Array}；
# 面片顶点 <3 时返回空字典（调用方按失败处理）。

static func weld_patches(patches: Array) -> Dictionary:
	var vertices := PackedVector3Array()
	var triangles := PackedInt32Array()
	var coord_to_index: Dictionary = {}

	for patch in patches:
		if patch == null:
			continue
		if patch.vertices_local_m.size() < 3:
			return {"vertices": PackedVector3Array(), "triangles": PackedInt32Array()}

		# 本面片顶点 -> 全局索引映射（按面片顶点顺序）
		var local_map := PackedInt32Array()
		for vtx in patch.vertices_local_m:
			var key := "%.4f|%.4f|%.4f" % [vtx.x, vtx.y, vtx.z]
			if coord_to_index.has(key):
				local_map.append(int(coord_to_index[key]))
			else:
				vertices.append(vtx)
				coord_to_index[key] = vertices.size() - 1
				local_map.append(vertices.size() - 1)
		for idx in patch.triangles:
			if idx < 0 or idx >= local_map.size():
				return {"vertices": PackedVector3Array(), "triangles": PackedInt32Array()}
			triangles.append(local_map[idx])

	return {"vertices": vertices, "triangles": triangles}