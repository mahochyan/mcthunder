class_name InputFocusRouter
extends RefCounted
var mode := ""
var _life := -1
func route(next_mode: String, vehicle: VehicleActor, controller: PlayerController) -> void:
	if vehicle == null or controller == null: return
	var changed := mode != next_mode or vehicle.life_id != _life
	mode = next_mode
	_life = vehicle.life_id
	var playing := mode == "playing"
	controller.commands_enabled = playing
	if changed:
		controller.reset_pending()
		controller.require_fire_release()
		vehicle.clear_commands()
	if DisplayServer.get_name() != "headless":
		var desired := Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != desired: Input.mouse_mode = desired
