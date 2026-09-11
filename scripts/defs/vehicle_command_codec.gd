class_name VehicleCommandCodec
extends RefCounted
## Data-only contract; authenticated ownership belongs to the future transport.
const VERSION := 1
const FLAGS := ["has_aim_point","clear_aim","aim_held","fire_requested","repair_requested","extinguish_requested","replace_crew_requested","cancel_recovery_requested"]
static func integer(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and absf(float(v))<=9007199254740991 and float(v)==floor(float(v))
static func encode(cmd: VehicleCommand, actor: VehicleActor, sequence: int, input_tick: int) -> Dictionary:
	var body := {"throttle":cmd.throttle,"steer":cmd.steer,"select_shell":cmd.select_shell,"aim_world_point":[cmd.aim_world_point.x,cmd.aim_world_point.y,cmd.aim_world_point.z]}
	for key in FLAGS: body[key] = cmd.get(key)
	return {"version":VERSION,"entity_id":actor.entity_id,"life_id":actor.life_id,"generation":actor.state.generation,"control_epoch":actor.control_epoch,"sequence":sequence,"input_tick":input_tick,"command":body}
static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()!=8: return {"ok":false,"reason":"invalid_envelope"}
	for key in ["version","life_id","generation","control_epoch","sequence","input_tick"]:
		if not integer(value.get(key)) or int(value[key])<0: return {"ok":false,"reason":"invalid_"+key}
	if value.version!=VERSION: return {"ok":false,"reason":"unsupported_version"}
	if not value.get("entity_id") is String or value.entity_id.is_empty() or value.entity_id.length()>128: return {"ok":false,"reason":"invalid_entity"}
	if not value.get("command") is Dictionary: return {"ok":false,"reason":"invalid_command"}
	var body: Dictionary = value.command
	if body.size()!=FLAGS.size()+4: return {"ok":false,"reason":"invalid_fields"}
	for key in ["throttle","steer"]:
		var v: Variant = body.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or absf(float(v))>1: return {"ok":false,"reason":"invalid_"+key}
	for key in FLAGS:
		if not body.get(key) is bool: return {"ok":false,"reason":"invalid_"+key}
	if body.has_aim_point and body.clear_aim: return {"ok":false,"reason":"ambiguous_aim"}
	if not integer(body.get("select_shell")) or int(body.select_shell) not in [-1,0,1]: return {"ok":false,"reason":"invalid_shell"}
	var point: Variant = body.get("aim_world_point")
	if not point is Array or point.size()!=3: return {"ok":false,"reason":"invalid_aim"}
	for coordinate in point:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate))>1000000: return {"ok":false,"reason":"invalid_aim"}
	var cmd := VehicleCommand.new()
	cmd.throttle = body.throttle; cmd.steer = body.steer; cmd.select_shell = int(body.select_shell)
	cmd.aim_world_point = Vector3(point[0],point[1],point[2])
	for key in FLAGS: cmd.set(key,body[key])
	return {"ok":true,"command":cmd}
