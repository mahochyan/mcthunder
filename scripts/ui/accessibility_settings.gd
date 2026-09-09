class_name AccessibilitySettings
extends RefCounted
static var ui_scale := 1.0
static var reduce_flashes := false
static var stable_camera := true
static var replay_enabled := true
static var high_contrast := false
static var audio_volume := 0.8
static var fx_level := 2 # 0 off, 1 reduced, 2 normal. Display only.
static var shake_strength := 0.6
static func apply(root: Node) -> void:
	if root is Control and root.has_meta("hud_font_size"):
		root.add_theme_font_size_override("font_size",roundi(float(root.get_meta("hud_font_size"))*ui_scale))
	for child in root.get_children(): apply(child)
static func apply_vehicle(vehicle: VehicleActor) -> void:
	vehicle.turret.flash_enabled = not reduce_flashes and fx_level>0
	if reduce_flashes and is_instance_valid(vehicle.turret._flash): vehicle.turret._flash.visible = false
	vehicle.cam_rig.shake_enabled = not stable_camera
	if stable_camera:
		vehicle.cam_rig.cam.h_offset = 0
		vehicle.cam_rig.cam.v_offset = 0
