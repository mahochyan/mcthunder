extends RefCounted
## TEST ONLY authored single-use tile. Not Kontakt-1/5 or a named vehicle's protection.
static func profile() -> Dictionary:
	return {"version":"wt012-reactive-v1","provenance":"game_rule","reason":"TEST ONLY independent ERA thresholds and budget reductions",
		"max_trigger_angle_deg":80.0,"channels":{"kinetic":{"trigger_min_mm":1.0,"reduction_mm":10.0},
		"chemical":{"trigger_min_mm":5.0,"reduction_mm":100.0},"fragment":{"trigger_min_mm":0.0,"reduction_mm":0.0}}}
