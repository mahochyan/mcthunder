class_name VehicleCommandCodec
extends RefCounted
## Data-only contract; authenticated ownership belongs to the future transport.
## WT-EXPANSION-01 item B step 4: the secondary fire intent is part of the command contract because the local player's
## command travels THIS codec, not only the mailbox: VehicleActor.collect_simulation_command() polls the controller and
## re-encodes the result before consuming it, so a field the codec does not carry is silently dropped on the only path a
## player's trigger press takes. Found by writing the input-path acceptance leg, not by assuming.
## VERSION stays 3 (adding fields without a bump): the field-count check below already makes the body shape exact, and
## the shipped protocol triple 6/1/3 is asserted by tests/run_network_authority_checks.gd. Bumping to 4 was the
## alternative and is recorded as not taken; there are no deployed peers produced by an older build of this protocol.
const VERSION := 3
const FLAGS := ["has_aim_point","clear_aim","aim_held","hold_aim","fire_requested","repair_requested","extinguish_requested","replace_crew_requested","cancel_recovery_requested","range_requested","apply_range_requested","cycle_shell_requested","secondary_fire_requested"]
static func integer(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and absf(float(v))<=9007199254740991 and float(v)==floor(float(v))
static func encode(cmd: VehicleCommand, actor: VehicleActor, sequence: int, input_tick: int) -> Dictionary:
	return {"version":VERSION,"entity_id":actor.entity_id,"life_id":actor.life_id,"generation":actor.state.generation,"control_epoch":actor.control_epoch,"sequence":sequence,"input_tick":input_tick,"command":encode_body(cmd)}
static func encode_body(cmd: VehicleCommand) -> Dictionary:
	var body := {"throttle":cmd.throttle,"steer":cmd.steer,"select_shell":cmd.select_shell,"aim_world_point":[cmd.aim_world_point.x,cmd.aim_world_point.y,cmd.aim_world_point.z],"aim_intent":cmd.aim_intent.snapshot() if cmd.aim_intent!=null else {},"zeroing_steps":cmd.zeroing_steps,"secondary_fire_index":cmd.secondary_fire_index}
	for key in FLAGS: body[key] = cmd.get(key)
	return body
static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()!=8: return {"ok":false,"reason":"invalid_envelope"}
	for key in ["version","life_id","generation","control_epoch","sequence","input_tick"]:
		if not integer(value.get(key)) or int(value[key])<0: return {"ok":false,"reason":"invalid_"+key}
	if value.version!=VERSION: return {"ok":false,"reason":"unsupported_version"}
	if not value.get("entity_id") is String or value.entity_id.is_empty() or value.entity_id.length()>128: return {"ok":false,"reason":"invalid_entity"}
	if not value.get("command") is Dictionary: return {"ok":false,"reason":"invalid_command"}
	var body: Dictionary = value.command
	if body.size()!=FLAGS.size()+7: return {"ok":false,"reason":"invalid_fields"}
	if not AimIntent.valid_snapshot(body.get("aim_intent")): return {"ok":false,"reason":"invalid_optical_intent"}
	if not integer(body.get("zeroing_steps")) or absf(float(body.zeroing_steps))>20: return {"ok":false,"reason":"invalid_zeroing_steps"}
	if not integer(body.get("secondary_fire_index")) or int(body.secondary_fire_index)<0 or int(body.secondary_fire_index)>7: return {"ok":false,"reason":"invalid_secondary_fire_index"}
	if body.aim_intent.active and body.get("has_aim_point",false): return {"ok":false,"reason":"ambiguous_optical_intent"}
	for key in ["throttle","steer"]:
		var v: Variant = body.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or absf(float(v))>1: return {"ok":false,"reason":"invalid_"+key}
	for key in FLAGS:
		if not body.get(key) is bool: return {"ok":false,"reason":"invalid_"+key}
	if body.has_aim_point and body.clear_aim: return {"ok":false,"reason":"ambiguous_aim"}
	if not integer(body.get("select_shell")) or int(body.select_shell)<-1 or int(body.select_shell)>7: return {"ok":false,"reason":"invalid_shell"}
	var point: Variant = body.get("aim_world_point")
	if not point is Array or point.size()!=3: return {"ok":false,"reason":"invalid_aim"}
	for coordinate in point:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate))>1000000: return {"ok":false,"reason":"invalid_aim"}
	var cmd := VehicleCommand.new()
	cmd.throttle = body.throttle; cmd.steer = body.steer; cmd.select_shell = int(body.select_shell)
	cmd.aim_world_point = Vector3(point[0],point[1],point[2])
	cmd.aim_intent=AimIntent.from_snapshot(body.aim_intent); cmd.zeroing_steps=int(body.zeroing_steps)
	cmd.secondary_fire_index=int(body.secondary_fire_index)
	for key in FLAGS: cmd.set(key,body[key])
	return {"ok":true,"command":cmd}
