extends RefCounted
## TEST ONLY independent game constants; no T-80B/Leopard armor composition claim.
static func profile() -> Dictionary:
	return {"version":"wt012-passive-composite-v1","provenance":"game_rule","reason":"TEST ONLY passive composite channels",
		"coefficients":{"kinetic":0.5,"chemical":2.0,"fragment":1.5}}

static func sheet(id: String, z: float, material: String = "composite") -> Dictionary:
	return {"id":id,"part":"hull","vertices_m":[[-0.8,0.8,z],[0.8,0.8,z],[0.8,1.6,z],[-0.8,1.6,z]],"normal":[0,0,1],
		"thickness_mm":20,"material":material,"response_profile":profile() if material=="composite" else {},"reason":"TEST ONLY finite attached sheet in local metres"}
