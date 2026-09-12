extends RefCounted
## TEST ONLY authored values, not 3BK18M/DM12 or engineering measurements.
static func profile() -> Dictionary:
	return {"version":"wt013-chemical-jet-v1","penetration_mm":100.0,"range_m":3.0,"path_loss_mm_per_m":10.0,
		"provenance":"game_rule","reason":"TEST ONLY constant launch budget with bounded terminal path loss"}
static func impact() -> Dictionary:
	return {"version":"wt012-chemical-v1","family":"HEAT","material_coefficients":{"rolled":1.0,"cast":0.95},
		"provenance":"game_rule","reason":"TEST ONLY independent chemical material response"}
