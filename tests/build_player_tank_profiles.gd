extends SceneTree
## WT-040-R1: make the default fixture carry its four profiles EXPLICITLY, so the data travels in the file
## instead of relying on a script-level default.
##
## Measured evidence: in this source tree load_defaults() is ok=true with all four profiles non-null, while in
## the EXPORTED package the same call reports exactly "loading_profile: missing, fire_control_profile: missing,
## optics_profile: missing, drive_profile: missing". The four exist only as `@export ... = X.new()` defaults and
## the .tres does not mention them at all. This tool assigns FRESH instances (a distinct object is serialised
## even when its values equal the defaults) and lets Godot itself write the file, which is far safer than
## hand-editing a .tres. Nothing is masked: the validator still reports a genuinely missing profile.
const VEHICLE := "res://configs/player_tank_vehicle.tres"

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var v: Variant = load(VEHICLE)
	if v == null:
		print("[profiles] FAILED to load ", VEHICLE); quit(1); return
	print("[profiles] before: validate=", v.validate().ok, " errors=", v.validate().errors)
	var lp := LoadingProfile.new()
	var fc := FireControlProfile.new()
	var op := OpticsProfile.new()
	var dp := DriveProfile.new()
	v.loading_profile = lp
	v.fire_control_profile = fc
	v.optics_profile = op
	v.drive_profile = dp
	print("[profiles] assigned fresh instances: loading=", v.loading_profile != null,
		" fire_control=", v.fire_control_profile != null, " optics=", v.optics_profile != null, " drive=", v.drive_profile != null)
	var err := ResourceSaver.save(v, VEHICLE)
	print("[profiles] ResourceSaver.save error=", err)
	var back: Variant = load(VEHICLE)
	if back == null:
		print("[profiles] FAILED to reload after save"); quit(1); return
	print("[profiles] after reload: validate=", back.validate().ok, " errors=", back.validate().errors)
	print("[profiles] non-null: loading=", back.loading_profile != null, " fire_control=", back.fire_control_profile != null,
		" optics=", back.optics_profile != null, " drive=", back.drive_profile != null)
	# The real caller, so the verdict is the game's own.
	var defs := VehicleDefs.new()
	var lr: Dictionary = defs.load_defaults()
	print("[profiles] load_defaults ok=", lr.get("ok",false), " errors=", lr.get("errors",[]))
	print("PLAYER_TANK_PROFILES_DONE")
	quit(0 if lr.get("ok",false) else 1)