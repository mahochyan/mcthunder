class_name M4TrackMotion
extends Node3D
## Cosmetic only. Read actual body speed; never writes motion or damage state.
const STRAIGHT := 4.3
const RADIUS := 0.52
const PERIMETER := STRAIGHT*2+TAU*RADIUS
const SHOES := 100
var phase := 0.0
var assemblies: Array[Dictionary] = []
var tank: TankVehicle
var straight := STRAIGHT
var perimeter := PERIMETER
var track_center_x := 1.2

func build(parent: Node3D, layer: int, dimensions: Dictionary = {}) -> void:
	straight = float(dimensions.get("straight",STRAIGHT))
	perimeter = straight*2+TAU*RADIUS
	track_center_x = float(dimensions.get("center_x",1.2))
	var width: float = dimensions.get("width",0.43)
	parent.add_child(self)
	tank = parent as TankVehicle
	for side in [-1,1]:
		for pad in [false,true]:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(width*0.30/0.43,0.022,0.07) if pad else Vector3(width,0.075,0.11)
			mesh.material = ArtPalette.material("rubber" if pad else "steel")
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = SHOES
			var node := MultiMeshInstance3D.new()
			node.name = "Cosmetic_TrackShoes_%s_%s"%[str(side),"Pad" if pad else "Shoe"]
			node.layers = layer
			node.multimesh = multimesh
			if pad:
				node.visibility_range_end = 100.0
				node.visibility_range_end_margin = 10.0
			add_child(node)
			assemblies.append({"mesh":multimesh,"side":side,"pad":pad})
	update_shoes()

func _process(delta: float) -> void:
	if tank == null or not is_instance_valid(tank) or get_tree().paused: return
	if absf(tank.forward_speed) < 0.001: return
	phase = fposmod(phase-tank.forward_speed*delta,perimeter)
	update_shoes()

func update_shoes() -> void:
	for assembly in assemblies:
		for i in SHOES:
			var distance := fposmod(i*perimeter/SHOES+phase,perimeter)
			var p: Vector3
			var tangent: Vector3
			if distance < straight:
				p = Vector3(assembly.side*track_center_x,0.04,-straight*0.5+distance)
				tangent = Vector3.BACK
			elif distance < straight+PI*RADIUS:
				var a := (distance-straight)/RADIUS-PI/2
				p = Vector3(assembly.side*track_center_x,0.56+sin(a)*RADIUS,straight*0.5+cos(a)*RADIUS)
				tangent = Vector3(0,cos(a),-sin(a))
			elif distance < straight*2+PI*RADIUS:
				p = Vector3(assembly.side*track_center_x,1.08,straight*0.5-(distance-straight-PI*RADIUS))
				tangent = Vector3.FORWARD
			else:
				var a := (distance-straight*2-PI*RADIUS)/RADIUS+PI/2
				p = Vector3(assembly.side*track_center_x,0.56+sin(a)*RADIUS,-straight*0.5+cos(a)*RADIUS)
				tangent = Vector3(0,cos(a),-sin(a))
			var normal := tangent.cross(Vector3.RIGHT)
			if assembly.pad: p -= normal*0.048
			assembly.mesh.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,normal,tangent),p))
