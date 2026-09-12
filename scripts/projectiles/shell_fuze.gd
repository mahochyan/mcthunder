class_name ShellFuze
extends RefCounted
## Configurable game rule. Empty policy preserves legacy inside-distance rounds.
const VERSION := "wt013-delay-v1"

static func validate(policy: Variant, effect: String) -> Array[String]:
	var errors: Array[String] = []
	if not policy is Dictionary: return ["fuze: expected dictionary"]
	if policy.is_empty(): return errors
	if effect != "internal_burst": errors.append("fuze: requires internal_burst shell")
	if policy.get("mode") != "penetration_delay": errors.append("fuze: unsupported mode")
	for key in ["arming_thickness_mm", "delay_s"]:
		var value: Variant = policy.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0:
			errors.append("fuze."+key+": positive finite value required")
	if policy.get("provenance") != "game_rule": errors.append("fuze: design provenance required")
	if not policy.get("reason") is String or str(policy.get("reason", "")).strip_edges().is_empty():
		errors.append("fuze: design explanation required")
	return errors

static func arm(st: ProjectileState, event: Dictionary, result: Dictionary) -> void:
	# Game trigger is one inward penetrated plate's geometric LOS; separated thin
	# plates do not accumulate an arming thickness, and material resistance is not LOS.
	if st.fuze_policy.is_empty() or st.fuze_due_age_s >= 0.0: return
	# Only a successful inward perforation arms. Ricochet, unknown armor,
	# blocked rounds and backfaces cannot borrow an earlier target's trigger.
	if result.get("result") != "penetrated" or result.get("backface", true): return
	if float(result.get("path_thickness_mm", result.get("effective_mm", 0.0))) < float(st.fuze_policy.arming_thickness_mm): return
	st.fuze_armed_age_s = st.age_s
	st.fuze_due_age_s = st.age_s + float(st.fuze_policy.delay_s)
	st.burst_target = event.duplicate(true)

static func due(st: ProjectileState) -> bool:
	return st.fuze_due_age_s >= 0.0 and st.age_s >= st.fuze_due_age_s - 1e-9
