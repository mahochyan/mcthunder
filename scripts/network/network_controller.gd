class_name NetworkController
extends Node
## Transport authenticates the owner; the actor validates the command envelope.
var cam_rig: CameraRig
var gunner: Gunner
var vehicle: VehicleActor
var held: VehicleCommand
var identity: Dictionary = {}
func is_local_controller() -> bool: return false
func receive(envelope: Variant) -> Dictionary:
	var result := vehicle.submit_command_envelope(envelope)
	if not result.ok: return result
	var command: VehicleCommand = VehicleCommandCodec.decode(envelope).command
	held = VehicleCommand.new()
	held.throttle=command.throttle; held.steer=command.steer
	held.has_aim_point=command.has_aim_point; held.aim_world_point=command.aim_world_point
	held.clear_aim=command.clear_aim; held.aim_held=command.aim_held
	held.hold_aim=command.hold_aim
	identity={"life":vehicle.life_id,"generation":vehicle.state.generation,"epoch":vehicle.control_epoch,"tick":int(envelope.input_tick)}
	return result
func poll() -> VehicleCommand:
	# Only continuous inputs may persist between packets. Edges were queued once
	# by receive(); returning null avoids synthesizing a competing input sequence.
	if held!=null and identity.life==vehicle.life_id and identity.generation==vehicle.state.generation and identity.epoch==vehicle.control_epoch and Engine.get_physics_frames()-identity.tick<=GameConfig.COMMAND_MAX_AGE_TICKS:
		vehicle.submit_command(held)
	else: reset_pending()
	return null
func reset_pending() -> void: held=null; identity.clear()
func on_detached() -> void: reset_pending()
