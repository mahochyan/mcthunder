class_name InputFocusRouter
extends RefCounted
## Owns the pointer mode while a match runs, and nothing else - commands_enabled and lifecycle resets stay here
## because they are the same focus decision, but no combat rule is touched.
##
## WT-UI mouse fix: a capture request must never win while the window is in the background. Before this, every
## frame of a running match set MOUSE_MODE_CAPTURED unconditionally, and nothing released it on focus loss, so
## alt-tabbing left the pointer locked to a window the player was not looking at. The decision is now a pure
## function of "is the match playing" and "does the window have focus", and every direct capture site goes through
## capture_mouse() so the same rule holds in every range.
var mode := ""
var _life := -1
var _window_focused := true

## The pointer mode this state actually wants. Kept pure so it can be asserted without a window.
func desired_mode() -> int:
	if mode == "playing" and _window_focused: return Input.MOUSE_MODE_CAPTURED
	return Input.MOUSE_MODE_VISIBLE

## Called by the window's owner on NOTIFICATION_APPLICATION_FOCUS_OUT / _IN.
func window_focus(focused: bool) -> void:
	_window_focused = focused
	_apply_mode()

func _apply_mode() -> void:
	if DisplayServer.get_name() == "headless": return
	var desired := desired_mode()
	if Input.mouse_mode != desired: Input.mouse_mode = desired

## Any scene that wants to capture the pointer calls this instead of writing Input.mouse_mode itself.
static func capture_mouse(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless" or tree == null: return
	if tree.root != null and not tree.root.has_focus(): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	_apply_mode()
