class_name BallisticsProfile
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD004 design point 1: a VERSIONED ballistics profile - units, muzzle velocity, gravity, an optional
## empirical drag / velocity-decay term and a lifetime / distance cap.
##
## The sub-order is explicit that the FIRST version chooses ONE calibratable approximation rather than several air models at
## once, and that legacy configurations must use v1 EXPLICITLY without their curve being silently changed. So:
##   * "v1_vacuum" is the flight the project already had - gravity only, no drag - and any declaration that does not name a
##     profile resolves here with source "legacy_v1_vacuum", so existing behaviour is preserved by construction and can be
##     compared against (the T01 zero-drag analytic baseline is that comparison).
##   * "eng_quadratic_v1" adds exactly one term, a = -k*|v|*v, with k a PROJECT DESIGN value awaiting human calibration.
##
## Every number here is a game design initial value. Nothing may be labelled validated_history until real measurements
## exist, and the retention table below is a design curve, not measured history.

## Bumped when any number or the model changes, so a recorded table can name the profile it was produced with.
const VERSION := "cd004-ballistics-v1"

## Units, declared once rather than assumed: distance m, time s, speed m/s, acceleration m/s^2, drag coefficient per metre.
const UNITS := {
	"distance": "m", "time": "s", "speed": "m_per_s", "acceleration": "m_per_s2", "drag_k": "per_m",
}

const PROFILE_VACUUM := "v1_vacuum"
const PROFILE_QUADRATIC := "eng_quadratic_v1"

const PROFILES := {
	PROFILE_VACUUM: {
		"version": VERSION,
		"drag_model": "none",
		"drag_k_per_m": 0.0,
		"provenance": "design",
		"note": "Gravity only, no drag: the flight the project already had. Legacy declarations resolve here and their curve is not silently changed.",
	},
	PROFILE_QUADRATIC: {
		"version": VERSION,
		"drag_model": "quadratic_speed",
		"drag_k_per_m": 2.2e-5,
		"provenance": "design",
		"note": "One calibratable approximation, not several air models. k is a game design initial value awaiting calibration.",
	},
}

## The frozen engineering curve this profile is DECLARED against (design point 1 + case CD04-T02): the fraction of muzzle
## speed remaining at each range, and the tolerance the simulation must hold against its own declaration. Project design.
const RETENTION_TABLE := {
	PROFILE_QUADRATIC: {
		"declared_retention": [[200.0, 0.972], [500.0, 0.932], [1000.0, 0.871], [1500.0, 0.814]],
		"tolerance": 0.010,
	},
}

## The declaration a shell (or any caller) may carry. Explicit only: this never guesses a profile from the shell's effect
## policy or caliber, because a silent guess is how one curve gets changed while nobody notices.
static func declaration_of(shell) -> Dictionary:
	if shell == null:
		return {}
	if shell is Dictionary:
		var row: Dictionary = shell.get("ballistics_profile", {})
		return row if row is Dictionary else {}
	var named: Variant = shell.get("ballistics_profile")
	if named == null:
		return {}
	if named is Dictionary:
		return named
	var name := str(named)
	return {"profile": name} if not name.is_empty() else {}

## Resolve the profile a shot must fly with. An empty declaration is the LEGACY case and resolves to v1 vacuum with a
## distinct source, so a recorded run can always say which curve produced it.
static func resolve(shell) -> Dictionary:
	var declaration := declaration_of(shell)
	if declaration.is_empty():
		var legacy: Dictionary = PROFILES[PROFILE_VACUUM].duplicate(true)
		legacy["profile"] = PROFILE_VACUUM
		legacy["source"] = "legacy_v1_vacuum"
		return legacy
	var name := str(declaration.get("profile", ""))
	if not PROFILES.has(name):
		return {}
	var resolved: Dictionary = PROFILES[name].duplicate(true)
	resolved["profile"] = name
	resolved["source"] = "project_engineering_profile"
	# A declaration may narrow the lifetime / distance cap; it may never invent a different drag model in this version.
	for key in ["drag_k_per_m"]:
		if declaration.has(key):
			resolved[key] = float(declaration[key])
	if declaration.has("max_age_s"):
		resolved["max_age_s"] = float(declaration["max_age_s"])
	if declaration.has("max_distance_m"):
		resolved["max_distance_m"] = float(declaration["max_distance_m"])
	return resolved

## Validate a declaration by NAME so a refusal says what was wrong instead of silently falling back to a different curve.
static func validate(shell) -> Dictionary:
	var declaration := declaration_of(shell)
	if declaration.is_empty():
		return {"ok": true, "reason": "legacy_v1_vacuum", "profile": PROFILE_VACUUM}
	var name := str(declaration.get("profile", ""))
	if name.is_empty():
		if declaration.has("drag_k_per_m") and float(declaration["drag_k_per_m"]) < 0.0:
			return {"ok": false, "reason": "invalid_ballistics_drag_k"}
		return {"ok": true, "reason": "legacy_v1_vacuum", "profile": PROFILE_VACUUM}
	if not PROFILES.has(name):
		return {"ok": false, "reason": "unknown_ballistics_profile", "profile": name}
	if declaration.has("drag_k_per_m") and float(declaration["drag_k_per_m"]) < 0.0:
		return {"ok": false, "reason": "invalid_ballistics_drag_k", "profile": name}
	if declaration.has("max_age_s") and float(declaration["max_age_s"]) <= 0.0:
		return {"ok": false, "reason": "invalid_ballistics_max_age", "profile": name}
	if declaration.has("max_distance_m") and float(declaration["max_distance_m"]) <= 0.0:
		return {"ok": false, "reason": "invalid_ballistics_max_distance", "profile": name}
	return {"ok": true, "reason": "explicit_profile", "profile": name}

## The declared retention curve for a profile, or an empty dictionary when that profile declares none (vacuum).
static func retention_curve(profile_name: String) -> Dictionary:
	var row: Variant = RETENTION_TABLE.get(profile_name, {})
	return row if row is Dictionary else {}

## Speed decay per metre under this profile at a given speed, as an acceleration. The single approximation: a = -k*|v|*v.
static func drag_acceleration(profile: Dictionary, velocity: Vector3) -> Vector3:
	if str(profile.get("drag_model", "none")) == "none":
		return Vector3.ZERO
	var k := float(profile.get("drag_k_per_m", 0.0))
	if k <= 0.0 or not velocity.is_finite():
		return Vector3.ZERO
	var speed := velocity.length()
	if speed <= 0.0:
		return Vector3.ZERO
	return -velocity * (k * speed)

## Whether this profile may be described as measured history. Always false for the design values above, and it is a function
## so a caller cannot accidentally label a design curve as validated.
static func is_validated_history(profile: Dictionary) -> bool:
	return str(profile.get("provenance", "design")) == "validated_history"
