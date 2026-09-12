extends RefCounted
## TEST ONLY game response, no named historical ammunition or penetrator dimensions.
static func profile() -> Dictionary:
	return {"version":"wt012-long-rod-v1","family":"APFSDS","ricochet_deg":82.0,
		"angle_resistance_curve":[[0.0,1.0],[30.0,1.2],[60.0,1.6],[90.0,4.0]],
		"material_coefficients":{"rolled":1.0,"cast":0.95},"provenance":"game_rule",
		"reason":"TEST ONLY authored angle response, not 3BM42/DM23 data or rod engineering"}
