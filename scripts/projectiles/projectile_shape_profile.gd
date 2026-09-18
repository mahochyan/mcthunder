class_name ProjectileShapeProfile
extends RefCounted
## WT-CD-003 design point 1 and 2 / CD03: the BORE diameter and the projectile's EFFECTIVE shape are separate facts. An
## APFSDS round must not pass its bore calibre off as its core, so the armour rule consumes the effective section while
## the bore stays what the barrel is. Where no measured shape exists the profile is an independent PROJECT engineering
## estimate and says so; a shell with no profile is refused explicitly rather than silently falling back to the v1 line
## rule, which stays available as its own explicit legacy entry.
##
## Everything here is project design data, not a decoded external value: no measured core section is available, so each
## profile carries provenance "design" and is marked NOT_COMPARED. The sampling declaration is part of the profile: 3A
## approximates the section with a bounded ring of rays, so the number of rays and the resulting error bound travel with
## the data instead of being assumed to be exact.

const VERSION := "cd003-shape-v1"
const PROVENANCE_DESIGN := "design"
const PROVENANCE_ESTIMATED := "estimated"
const PROVENANCE_VERIFIED := "verified"
const PROVENANCE_LEVELS := [PROVENANCE_DESIGN,PROVENANCE_ESTIMATED,PROVENANCE_VERIFIED]

## kind: "long_rod" (APFSDS/APDS), "full_caliber" (AP/APHE), "chemical" (HEAT/HESH).
## core_diameter_m / core_length_m are the EFFECTIVE section and length; they are deliberately not derived from the bore.
## rays: how many rays 3A uses to sample the section at each query step; the error bound is computed from that, not claimed.
const PROFILES := {
	"apfsds": {"kind":"long_rod","bore_caliber_mm":125.0,"core_diameter_m":0.030,"core_length_m":0.600,"rays":7,
		"provenance":"design","note":"project engineering estimate for a long rod; no measured core section on file, NOT_COMPARED"},
	"apds": {"kind":"long_rod","bore_caliber_mm":105.0,"core_diameter_m":0.040,"core_length_m":0.300,"rays":7,
		"provenance":"design","note":"project engineering estimate for a sub-calibre core, NOT_COMPARED"},
	"ap": {"kind":"full_caliber","bore_caliber_mm":88.0,"core_diameter_m":0.088,"core_length_m":0.240,"rays":5,
		"provenance":"design","note":"full calibre round: the effective section IS the bore, stated rather than assumed, NOT_COMPARED"},
	"chemical": {"kind":"chemical","bore_caliber_mm":120.0,"core_diameter_m":0.120,"core_length_m":0.200,"rays":5,
		"provenance":"design","note":"project engineering estimate for a chemical round, NOT_COMPARED"},
}

## Independent geometric error bound of the ring sampling: a regular ring of n rays on a section of radius r leaves at most
## r*(1-cos(pi/n)) of the section unsampled between neighbouring rays. Returned in metres with the ray count that
## produced it, so a caller can state its own accuracy instead of assuming the approximation is exact.
static func sampling_error_bound_m(section_radius_m: float, rays: int) -> float:
	if rays < 3 or not is_finite(section_radius_m) or section_radius_m <= 0.0:
		return INF
	return section_radius_m*(1.0-cos(PI/float(rays)))

## The full declared sampling plan for a profile: ray count, the ring plus centre pattern, the section radius, and the
## resulting bound. This is what 3A must consume and what the phase-3 record has to state.
static func sampling_plan(profile: Dictionary) -> Dictionary:
	var radius := float(profile.get("core_diameter_m",0.0))*0.5
	var rays := int(profile.get("rays",0))
	var bound := sampling_error_bound_m(radius,rays)
	return {"version":VERSION,"rays":rays,"pattern":"centre_plus_ring","section_radius_m":radius,
		"error_bound_m":bound,"error_bound_mm":bound*1000.0 if is_finite(bound) else INF,
		"exact":false,"note":"bounded ring approximation; the bound is computed from the ray count, never asserted as zero"}

static func validate(profile: Dictionary) -> Array:
	var errors: Array = []
	if not profile.has("kind") or not (str(profile.kind) in ["long_rod","full_caliber","chemical"]):
		errors.append("kind: expected long_rod / full_caliber / chemical")
	for key in ["bore_caliber_mm","core_diameter_m","core_length_m"]:
		if not profile.has(key) or not is_finite(float(profile.get(key,-1.0))) or float(profile.get(key,-1.0)) <= 0.0:
			errors.append(key+": a positive number is required")
	if profile.has("core_diameter_m") and profile.has("bore_caliber_mm"):
		if float(profile.core_diameter_m) > float(profile.bore_caliber_mm)/1000.0 + 1e-9:
			errors.append("core_diameter_m: the effective section cannot exceed the bore")
	if not profile.has("rays") or int(profile.get("rays",0)) < 3:
		errors.append("rays: at least three rays are required for a bounded section")
	if not str(profile.get("provenance","")) in PROVENANCE_LEVELS:
		errors.append("provenance: expected one of "+str(PROVENANCE_LEVELS))
	if not profile.has("note"):
		errors.append("note: a provenance note is required so the value is not mistaken for a measured fact")
	return errors

## Resolve a shell to its profile. The shell may carry an explicit profile; otherwise it is matched by kind. A shell with
## neither is REFUSED - the v1 line rule is a separate, explicit legacy entry and is never reached by falling through here.
static func resolve(shell: Dictionary) -> Dictionary:
	if shell.has("shape_profile"):
		var explicit: Dictionary = shell.get("shape_profile",{})
		var errors := validate(explicit)
		if not errors.is_empty(): return {"ok":false,"reason":"invalid_shape_profile","errors":errors}
		return {"ok":true,"profile":explicit.duplicate(true),"sampling":sampling_plan(explicit),"source":"explicit"}
	# Only an EXPLICIT declaration resolves here. Deriving the kind from effect_policy was my first attempt and it would have
	# silently given every legacy long rod round a section, which is exactly the silent change the sub-order forbids: a round
	# that declares nothing stays a legacy line round, visibly.
	var kind := str(shell.get("shape_kind",""))
	var key := ""
	match kind:
		"long_rod": key = "apfsds"
		"full_caliber": key = "ap"
		"chemical": key = "chemical"
	if key.is_empty() or not PROFILES.has(key):
		return {"ok":false,"reason":"no_shape_profile",
			"detail":"this shell declares neither an explicit shape_profile nor a kind with a project profile; the v1 line rule is a separate legacy entry and is not entered by fallback"}
	return {"ok":true,"profile":(PROFILES[key] as Dictionary).duplicate(true),
		"sampling":sampling_plan(PROFILES[key]),"source":"project_engineering_profile"}

## Does this profile differ from the bore? True for every sub-calibre round, which is exactly the case the sub-order
## forbids conflating.
static func is_sub_calibre(profile: Dictionary) -> bool:
	return float(profile.get("core_diameter_m",0.0))*1000.0 < float(profile.get("bore_caliber_mm",0.0))-1e-9
