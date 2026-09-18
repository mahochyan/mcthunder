class_name SpallProfile
extends RefCounted
## Bounded authored game rules. No claim of measured fragment/penetrator physics.
const VERSION := "wt013-directional-spall-v1"
## MCT-COMBAT-DEEPEN-01 CD06 design point one: the post-penetration profile is EXTENDED to the internal burst rather than
## duplicated. An internal burst carries its own version and the same declared field set - channel, direction distribution,
## range, sample weights and budget - and it reaches the very same consumption path the long rod already uses, because the
## manager's spall emitter only requires that a profile be declared and that the contact be a front-facing penetration. The
## long-rod version is untouched, so every existing long-rod profile and every undeclared round behave exactly as before.
const VERSION_INTERNAL_BURST := "cd006-internal-burst-v1"
const MAX_EVENTS := 4
const MAX_COUNT := 8

static func expected_version(effect: String) -> String:
	if effect=="long_rod": return VERSION
	if effect=="internal_burst": return VERSION_INTERNAL_BURST
	return ""

static func validate(value: Variant, effect: String) -> Array[String]:
	var errors: Array[String]=[]
	if not value is Dictionary: return ["post_penetration_profile: dictionary required"]
	if value.is_empty(): return errors
	var wanted := expected_version(effect)
	if wanted.is_empty() or value.get("version")!=wanted: errors.append("post_penetration_profile: unsupported effect/version")
	if value.get("provenance")!="game_rule" or not value.get("reason") is String or str(value.get("reason","")).strip_edges().is_empty(): errors.append("post_penetration_profile: game-rule explanation required")
	for field in ["count","cone_deg","range_m","budget_fraction","max_total_mm","min_residual_mm"]:
		if not _number(value.get(field)): errors.append("post_penetration_profile: finite "+field+" required")
	if not errors.is_empty(): return errors
	if int(value.count)!=value.count or value.count<1 or value.count>MAX_COUNT: errors.append("post_penetration_profile: invalid count")
	if value.cone_deg<=0 or value.cone_deg>60 or value.range_m<=0 or value.range_m>5: errors.append("post_penetration_profile: invalid cone/range")
	if value.budget_fraction<=0 or value.budget_fraction>=1 or value.max_total_mm<=0 or value.max_total_mm>100 or value.min_residual_mm<=0: errors.append("post_penetration_profile: invalid budget split")
	var impact: Variant=value.get("fragment_impact_profile")
	if not impact is Dictionary or impact.is_empty(): errors.append("post_penetration_profile: separate fragment material response required")
	else: errors.append_array(ArmorImpactProfile.validate(impact,"kinetic",true))
	return errors

static func allocation(profile: Dictionary, residual: float) -> float:
	return minf(residual*float(profile.budget_fraction),float(profile.max_total_mm)) if residual>=float(profile.min_residual_mm) else 0.0

static func directions(profile: Dictionary, forward: Vector3, seed_value: int, batch_index: int) -> Array[Vector3]:
	var output: Array[Vector3]=[]
	var direction := forward.normalized()
	var tangent := direction.cross(Vector3.UP if absf(direction.y)<0.9 else Vector3.RIGHT).normalized()
	var bitangent := direction.cross(tangent).normalized()
	var rng := RandomNumberGenerator.new(); rng.seed=seed_value
	# Advancing a bounded number of draws avoids integer hash overflow across platforms.
	for unused in batch_index*MAX_COUNT: rng.randf()
	for index in int(profile.count):
		var cosine := lerpf(1.0,cos(deg_to_rad(float(profile.cone_deg))),(float(index)+0.5)/float(profile.count))
		var radius := sqrt(maxf(0,1-cosine*cosine)); var azimuth := rng.randf()*TAU
		output.append((direction*cosine+(tangent*cos(azimuth)+bitangent*sin(azimuth))*radius).normalized())
	return output

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
