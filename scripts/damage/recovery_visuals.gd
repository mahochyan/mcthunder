class_name RecoveryVisuals
extends Node3D
## Read-only fire/wreck feedback. No damage or lifecycle writes.
var actor: VehicleActor
var _flames: Array[MeshInstance3D] = []
var _original: Array[Dictionary] = []
var _was_destroyed := false
var _time := 0.0

func setup(vehicle: VehicleActor) -> void:
	actor = vehicle
	refresh_materials()
	for i in 7:
		var flame := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22,0.4,0.22)
		flame.mesh = box
		flame.layers = vehicle.tank.visual_layer
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("#ff942e") if i%2 == 0 else Color("#edcc50")
		flame.material_override = mat
		vehicle.tank.add_child(flame)
		_flames.append(flame)

func refresh_materials() -> void:
	_original.clear()
	for mesh in actor.tank.find_children("*","GeometryInstance3D",true,false):
		if not mesh.is_queued_for_deletion() and not (mesh is MeshInstance3D and mesh in _flames):
			_original.append({"mesh":mesh,"material":mesh.material_override})

func _process(delta: float) -> void:
	if not is_instance_valid(actor): return
	if not get_tree().paused: _time += delta
	for i in _flames.size():
		var flame := _flames[i]
		flame.visible = not actor.state.fires.is_empty() and not actor.state.destroyed
		var origin: Vector3 = actor.state._damage_layout.modules[0].local_box_transform.origin if actor.state._damage_layout != null else Vector3(0,0.9,0.9)
		flame.position = origin+Vector3((i%3-1)*0.25,0.4+fmod(_time*0.9+i*0.24,1.5),(i/3)*0.12)
	if actor.state.destroyed != _was_destroyed:
		_was_destroyed = actor.state.destroyed
		for row in _original:
			if not is_instance_valid(row.mesh): continue
			if not _was_destroyed:
				row.mesh.material_override = row.material
			else:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color("#34383c")
				row.mesh.material_override = mat
