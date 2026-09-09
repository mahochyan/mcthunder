class_name WorldCollisionRules
extends RefCounted
## One policy for physics, projectile rays and AI LOS. Low grass never conceals a tank.
static func classify(kind: String) -> Dictionary:
	if kind in ["terrain","building","stone_wall","solid_fence","boundary","tree","rock"]:
		return {"known":true,"solid":true,"blocks_shell":true,"blocks_los":true}
	if kind in ["low_grass","road","sign","supply_reservation"]:
		return {"known":true,"solid":false,"blocks_shell":false,"blocks_los":false}
	return {"known":false,"solid":true,"blocks_shell":true,"blocks_los":true}

static func tag(node: Node, kind: String) -> void:
	node.set_meta("world_kind",kind)
