class_name AssetBudgetReport
extends RefCounted
const VEHICLE_TRIANGLE_BUDGET := 25000
const VEHICLE_DRAW_SURFACE_BUDGET := 45
static func inspect(root: Node) -> Dictionary:
	var report:={"triangles":0,"mesh_nodes":0,"draw_surfaces":0,"visible_draw_surfaces":0,"material_count":0}
	var materials:={}
	_walk(root,report,materials)
	report.material_count=materials.size()
	return report
static func _walk(node: Node, report: Dictionary, materials: Dictionary) -> void:
	if node.is_queued_for_deletion(): return
	var mesh: Mesh
	var instances:=1
	if node is MeshInstance3D: mesh=node.mesh
	elif node is MultiMeshInstance3D and node.multimesh!=null:
		mesh=node.multimesh.mesh; instances=node.multimesh.instance_count
	if mesh!=null:
		report.mesh_nodes+=1
		for i in mesh.get_surface_count():
			var arrays:=mesh.surface_get_arrays(i)
			var indices: Variant=arrays[Mesh.ARRAY_INDEX]
			var amount: int=indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			if not mesh is ArrayMesh or mesh.surface_get_primitive_type(i)==Mesh.PRIMITIVE_TRIANGLES: report.triangles+=amount/3*instances
			report.draw_surfaces+=1
			if node.is_visible_in_tree(): report.visible_draw_surfaces+=1
			var material: Material=node.material_override if node.material_override!=null else mesh.surface_get_material(i)
			if material!=null: materials[material.get_instance_id()]=true
	for child in node.get_children(): _walk(child,report,materials)
