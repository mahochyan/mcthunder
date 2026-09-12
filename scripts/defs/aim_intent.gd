class_name AimIntent
extends RefCounted
## Observation input only. Origins, contacts and range results belong to authority.
const VERSION := 1
const MODES := ["chase", "sight", "binocular", "free"]
var active := false
var yaw := 0.0
var pitch := 0.0
var mode := "chase"

func snapshot() -> Dictionary:
	return {"version":VERSION,"active":active,"yaw":yaw,"pitch":pitch,"mode":mode}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=5: return false
	if not VehicleCommandCodec.integer(value.get("version")) or value.version!=VERSION: return false
	if not value.get("active") is bool or value.get("mode") not in MODES: return false
	for key in ["yaw","pitch"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])): return false
	return absf(float(value.yaw))<=PI+0.000001 and float(value.pitch)>=deg_to_rad(GameConfig.CAM_PITCH_MIN)-0.000001 and float(value.pitch)<=deg_to_rad(GameConfig.CAM_PITCH_MAX)+0.000001

static func from_snapshot(value: Dictionary) -> AimIntent:
	var result := AimIntent.new()
	if not valid_snapshot(value): return result
	result.active=value.active; result.yaw=value.yaw; result.pitch=value.pitch; result.mode=value.mode
	return result

func copy() -> AimIntent:
	return from_snapshot(snapshot())

func direction() -> Vector3:
	return Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
