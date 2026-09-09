class_name StructureDust
extends Node3D
## Bounded, non-colliding impact dust; parent lifespan owns cleanup, pause freezes it.
var _age := 0.0
var _puffs: Array[MeshInstance3D] = []

func start(point: Vector3, style: String) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position = point
	var mesh := SphereMesh.new(); mesh.radial_segments = 6; mesh.rings = 3; mesh.radius = 0.2; mesh.height = 0.4
	for i in 6:
		var puff := MeshInstance3D.new(); puff.mesh = mesh
		puff.material_override = ArtPalette.material("earth" if style=="wood" else "mortar")
		add_child(puff); _puffs.append(puff)

func _process(delta: float) -> void:
	_age += delta
	if _age >= 1.5: queue_free(); return
	for i in _puffs.size():
		_puffs[i].position = Vector3(sin(i*2.4),0.5+i*0.08,cos(i*2.4))*_age
		_puffs[i].scale = Vector3.ONE*(1.0+_age*2.0)*minf(1.0,(1.5-_age)*3.0)
