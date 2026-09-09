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
static var mouse_sensitivity := 1.0
static var invert_y := false
static var mechanical_volume := 1.0
static var effects_volume := 1.0
static var subtitles_enabled := true

static func snapshot() -> Dictionary:
	return {"ui_scale":ui_scale,"reduce_flashes":reduce_flashes,"stable_camera":stable_camera,"replay_enabled":replay_enabled,"high_contrast":high_contrast,"audio_volume":audio_volume,"fx_level":fx_level,"shake_strength":shake_strength,"mouse_sensitivity":mouse_sensitivity,"invert_y":invert_y,"mechanical_volume":mechanical_volume,"effects_volume":effects_volume,"subtitles_enabled":subtitles_enabled}

static func restore(values: Dictionary) -> void:
	for key in ["reduce_flashes","stable_camera","replay_enabled","high_contrast","invert_y","subtitles_enabled"]:
		if values.get(key) is bool:
			match key:
				"reduce_flashes": reduce_flashes = values[key]
				"stable_camera": stable_camera = values[key]
				"replay_enabled": replay_enabled = values[key]
				"high_contrast": high_contrast = values[key]
				"invert_y": invert_y = values[key]
				"subtitles_enabled": subtitles_enabled = values[key]
	for key in ["ui_scale","audio_volume","fx_level","shake_strength","mouse_sensitivity","mechanical_volume","effects_volume"]:
		if not (values.get(key) is int or values.get(key) is float): continue
		var value := float(values[key])
		if not is_finite(value): continue
		match key:
			"ui_scale": ui_scale = clampf(value,1,1.25)
			"audio_volume": audio_volume = clampf(value,0,1)
			"fx_level": fx_level = clampi(int(value),0,2)
			"shake_strength": shake_strength = clampf(value,0,1)
			"mouse_sensitivity": mouse_sensitivity = clampf(value,0.1,3)
			"mechanical_volume": mechanical_volume = clampf(value,0,1)
			"effects_volume": effects_volume = clampf(value,0,1)
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
