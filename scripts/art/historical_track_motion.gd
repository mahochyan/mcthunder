class_name HistoricalTrackMotion
extends Node3D
## Read actual displacement and yaw only. Independent left/right UV scrolling;
## no per-link meshes and no writes to driving, damage, or replay state.
var tank: TankVehicle
var tracks: Array[Dictionary] = []
var _position := Vector3.ZERO
var _yaw := 0.0
var _generation := 0
var _center_x := 1.0
var _repeat_metres := 1.0

func setup(parent: TankVehicle, packet: Dictionary) -> void:
	tank=parent; name="HistoricalTrackMotion"; parent.add_child(self); process_mode=Node.PROCESS_MODE_PAUSABLE
	_position=tank.global_position; _yaw=tank.global_rotation.y
	_generation=tank.state_generation
	_center_x=HistoricalEvidenceGate.value(packet,"dimensions.width_m")*0.5-float(packet.geometry.track_width)*0.5
	_repeat_metres=HistoricalEvidenceGate.value(packet,"dimensions.reference_length_m")*0.804/4.0
	for side in [-1,1]:
		var mesh:=tank.get_node_or_null("Cosmetic_track_left" if side<0 else "Cosmetic_track_right") as MeshInstance3D
		if mesh==null: continue
		var material:=ShaderMaterial.new(); material.shader=load("res://assets/shaders/vehicle_tracks.gdshader")
		material.set_shader_parameter("atlas",load(VehicleAtlas.TEXTURE_PATH))
		mesh.material_override=material
		tracks.append({"side":side,"material":material,"phase":0.0})

func _process(_delta: float) -> void:
	if not is_instance_valid(tank) or get_tree().paused: return
	if _generation!=tank.state_generation:
		_generation=tank.state_generation; _position=tank.global_position; _yaw=tank.global_rotation.y
		for row in tracks:
			row.phase=0.0; row.material.set_shader_parameter("travel",0.0)
		return
	var displacement:=tank.global_position-_position
	var yaw_delta:=wrapf(tank.global_rotation.y-_yaw,-PI,PI)
	_position=tank.global_position; _yaw=tank.global_rotation.y
	# Reset/teleport does not spin a texture through the entire map distance.
	if displacement.length_squared()>4.0: return
	var distance:=displacement.dot(-tank.global_basis.z)
	for row in tracks:
		row.phase=fposmod(float(row.phase)+(distance+float(row.side)*yaw_delta*_center_x)/_repeat_metres,1.0)
		row.material.set_shader_parameter("travel",row.phase)
