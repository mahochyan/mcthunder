class_name StructureCollapse
extends Node3D
## Eight short-lived visual pieces. Structural collision was already committed.
var _age:=0.0
var _parts: Array[Dictionary]=[]
func start(size: Vector3, style: String) -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	for i in 8:
		var piece:=MeshInstance3D.new(); var mesh:=BoxMesh.new()
		mesh.size=Vector3(size.x/4,0.12,size.z/2) if style=="wood" else Vector3(0.45,0.35,0.3)
		piece.mesh=mesh; piece.material_override=ArtPalette.material("wood_dark" if style=="wood" else "brick")
		var origin:=Vector3((i%4-1.5)*size.x/4,size.y-0.1,(i/4-0.5)*size.z/2)
		piece.position=origin; add_child(piece)
		_parts.append({"node":piece,"origin":origin,"speed":Vector3(sin(i*2.4)*0.5,0.7,cos(i*2.4)*0.5)})
func _process(delta: float) -> void:
	_age+=delta
	if _age>=1.2: queue_free(); return
	for i in _parts.size():
		var row: Dictionary=_parts[i]
		row.node.position=row.origin+row.speed*_age+Vector3.DOWN*4.9*_age*_age
		row.node.position.y=maxf(0.08,row.node.position.y)
		row.node.rotation=Vector3(sin(i)*0.25,0,i*0.05)*_age
