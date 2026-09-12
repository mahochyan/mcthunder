class_name OpticsProfile
extends Resource
## Design optics; FOV is vertical degrees, offsets are metres in the named frame.
@export var sight_fovs := PackedFloat32Array([30.0])
@export var sight_offset := Vector3(0,0.45,0.35) # BarrelPivot local.
@export var binocular_fov := 12.0
@export var binocular_offset := Vector3(0,3.0,0) # HullFrame local.
func validate() -> Array[String]:
	var errors: Array[String]=[]
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
