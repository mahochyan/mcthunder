extends RefCounted
## TEST ONLY game constants; no named real ammunition or explosive parameters.
static func profile() -> Dictionary:
	return {"version":"wt013-directional-spall-v1","count":6,"cone_deg":25.0,"range_m":3.0,
		"budget_fraction":0.3,"max_total_mm":30.0,"min_residual_mm":5.0,
		"provenance":"game_rule","reason":"TEST ONLY bounded directional response",
		"fragment_impact_profile":{"version":"wt012-full-caliber-v1","family":"fragment","normalization_deg":0.0,
			"overmatch_ratio":0.0,"ricochet_deg":75.0,"material_coefficients":{"rolled":1.0,"cast":0.95},
			"provenance":"game_rule","reason":"TEST ONLY independent fragment response"}}
