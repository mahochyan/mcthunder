class_name ArmorResolver
extends RefCounted
## 007 纯决策；所有参数是集中、版本化的游戏规则。
## 不改节点/预算/车辆，不把 UNKNOWN 当作 0，不从相机读取方向。

static func resolve(contact: Dictionary, direction: Vector3, budget: Dictionary) -> Dictionary:
	var out := {
		"result": "invalid", "continue_flight": false, "rules_version": GameConfig.ARMOR_RULES_VERSION,
		"angle_deg": 0.0, "effective_mm": 0.0, "before_mm": 0.0, "after_mm": 0.0,
		"scale": float(budget.get("scale", 1.0)), "consumed_mm": float(budget.get("consumed_mm", 0.0)),
		"ricochets": int(budget.get("ricochets", 0)), "direction": direction, "speed_scale": 1.0,
		"backface": false,
	}
	var base := float(budget.get("base_mm", -1.0))
	var scale := float(out.scale)
	var consumed := float(out.consumed_mm)
	var normal: Vector3 = contact.get("normal_world", Vector3.ZERO)
	if not direction.is_finite() or direction.length_squared() < 1e-12 \
			or not normal.is_finite() or absf(normal.length() - 1.0) > 0.001 \
			or not is_finite(base) or base < 0.0 or not is_finite(scale) or scale < 0.0 \
			or not is_finite(consumed) or consumed < 0.0 or int(out.ricochets) < 0:
		return out
	var before := maxf(0.0, scale * base - consumed)
	out.before_mm = before
	out.after_mm = before
	if not contact.get("has_thickness", false) or str(contact.get("thickness_status", "unknown")) == "unknown":
		out.result = "unknown_armor"
		return out
	var thickness := float(contact.get("thickness_mm", -1.0))
	if not is_finite(thickness) or thickness < 0.0 or not contact.get("normal_known", true):
		return out
	var d := direction.normalized()
	var signed_dot := d.dot(normal)
	var cos_angle := clampf(absf(signed_dot), 0.0, 1.0)
	out.backface = signed_dot > 0.0
	out.angle_deg = rad_to_deg(acos(cos_angle))
	if cos_angle <= GameConfig.ARMOR_GRAZING_COS:
		out.result = "grazing_unresolved"
		return out
	if float(out.angle_deg) >= GameConfig.ARMOR_RICOCHET_DEG - 1e-5:
		if int(out.ricochets) >= GameConfig.ARMOR_MAX_RICOCHETS:
			out.result = "ricochet_limit"
			return out
		out.result = "ricochet"
		out.continue_flight = true
		out.direction = (d - 2.0 * signed_dot * normal).normalized()
		out.speed_scale = GameConfig.ARMOR_RICOCHET_SPEED_SCALE
		out.scale = scale * GameConfig.ARMOR_RICOCHET_BUDGET_SCALE
		out.consumed_mm = consumed * GameConfig.ARMOR_RICOCHET_BUDGET_SCALE
		out.after_mm = before * GameConfig.ARMOR_RICOCHET_BUDGET_SCALE
		out.ricochets = int(out.ricochets) + 1
		return out
	var cost := thickness / cos_angle
	out.effective_mm = cost
	if before > cost + 1e-5:
		out.result = "penetrated"
		out.continue_flight = true
		out.consumed_mm = consumed + cost
		out.after_mm = before - cost
	elif absf(before - cost) <= 1e-5:
		out.result = "perforated_stop"
		out.consumed_mm = consumed + before
		out.after_mm = 0.0
	else:
		out.result = "stopped"
		out.consumed_mm = consumed + before
		out.after_mm = 0.0
	return out
