class_name OpticsProfile
extends Resource
## Design optics; FOV is vertical degrees, offsets are metres in the named frame.
@export var sight_fovs := PackedFloat32Array([30.0])
@export var sight_offset := Vector3(0,0.45,0.35) # BarrelPivot local.
@export var binocular_fov := 12.0
@export var binocular_offset := Vector3(0,3.0,0) # HullFrame local.
## Explicit gameplay estimates, not historical rangefinder specifications.
@export var rangefinder_min_m := 10.0
@export var rangefinder_max_m := 2000.0
@export var rangefinder_resolution_m := 25.0
@export var measurement_time_s := 2.0
@export var measurement_valid_s := 20.0
@export var zeroing_step_m := 100.0
@export var zeroing_max_m := 2000.0
func validate() -> Array[String]:
	var errors: Array[String]=[]
	for key in ["rangefinder_min_m","rangefinder_max_m","rangefinder_resolution_m","measurement_time_s","measurement_valid_s","zeroing_step_m","zeroing_max_m"]:
		if not is_finite(float(get(key))) or float(get(key))<=0 or float(get(key))>10000: errors.append("optics_profile."+key+": expected finite positive bounded value")
	if rangefinder_min_m>=rangefinder_max_m or rangefinder_resolution_m>rangefinder_max_m or zeroing_step_m>zeroing_max_m: errors.append("optics_profile.range: inconsistent limits")
	if sight_fovs.is_empty() or sight_fovs.size()>4: errors.append("optics_profile.sight_fovs: expected 1..4 steps")
	var previous := 71.0
	for fov in sight_fovs:
		if not is_finite(fov) or fov<5 or fov>70 or fov>=previous: errors.append("optics_profile.sight_fovs: expected descending finite FOVs in [5,70]")
		previous=fov
	if not is_finite(binocular_fov) or binocular_fov<5 or binocular_fov>40: errors.append("optics_profile.binocular_fov: expected [5,40]")
	for offset in [sight_offset,binocular_offset]:
		if not offset.is_finite() or offset.length()>5: errors.append("optics_profile.offset: invalid local optical position")
	return errors
static func magnification(fov: float) -> float:
	return tan(deg_to_rad(GameConfig.MAIN_FOV*0.5))/tan(deg_to_rad(fov*0.5))
