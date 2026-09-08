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

func build(parent: Node3D, layer: int) -> void:
	parent.add_child(self)
	tank = parent as TankVehicle
	for side in [-1,1]:
		for pad in [false,true]:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.30,0.022,0.07) if pad else Vector3(0.43,0.075,0.11)
			var material := StandardMaterial3D.new()
			material.albedo_color = M4VoxelDetails.RUBBER if pad else M4VoxelDetails.STEEL
			material.roughness = 0.9
			mesh.material = material
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = SHOES
			var node := MultiMeshInstance3D.new()
			node.name = "Cosmetic_TrackShoes"
			node.layers = layer
			node.multimesh = multimesh
			add_child(node)
			assemblies.append({"mesh":multimesh,"side":side,"pad":pad})
	update_shoes()

func _process(delta: float) -> void:
	if tank == null or not is_instance_valid(tank) or get_tree().paused: return
	if absf(tank.forward_speed) < 0.001: return
	phase = fposmod(phase-tank.forward_speed*delta,PERIMETER)
	update_shoes()

func update_shoes() -> void:
	for assembly in assemblies:
		for i in SHOES:
			var distance := fposmod(i*PERIMETER/SHOES+phase,PERIMETER)
			var p: Vector3
			var tangent: Vector3
			if distance < STRAIGHT:
				p = Vector3(assembly.side*1.2,0.04,-2.15+distance)
				tangent = Vector3.BACK
			elif distance < STRAIGHT+PI*RADIUS:
				var a := (distance-STRAIGHT)/RADIUS-PI/2
				p = Vector3(assembly.side*1.2,0.56+sin(a)*RADIUS,2.15+cos(a)*RADIUS)
				tangent = Vector3(0,cos(a),-sin(a))
			elif distance < STRAIGHT*2+PI*RADIUS:
				p = Vector3(assembly.side*1.2,1.08,2.15-(distance-STRAIGHT-PI*RADIUS))
				tangent = Vector3.FORWARD
			else:
				var a := (distance-STRAIGHT*2-PI*RADIUS)/RADIUS+PI/2
				p = Vector3(assembly.side*1.2,0.56+sin(a)*RADIUS,-2.15+cos(a)*RADIUS)
				tangent = Vector3(0,cos(a),-sin(a))
			var normal := tangent.cross(Vector3.RIGHT)
			if assembly.pad: p -= normal*0.048
			assembly.mesh.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,normal,tangent),p))
