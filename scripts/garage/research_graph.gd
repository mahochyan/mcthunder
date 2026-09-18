class_name ResearchGraph
extends RefCounted
## The current build exposes every admitted vehicle immediately. The graph remains
## the canonical set/order for saves and UI, but no node consumes research points.
const STARTER := "us_m4a3_75w_vvss_1944"
const NODES := {
	"us_m4a3_75w_vvss_1944":{"cost":0,"requires":[]},
	"us_m24_m6_t85e1_1951":{"cost":80,"requires":[STARTER]},
	"us_m36_m4a1_1945":{"cost":120,"requires":[STARTER]},
	"us_m26_m3_1945":{"cost":180,"requires":["us_m36_m4a1_1945"]}}

static func all_ids() -> Array:
	return NODES.keys().duplicate()

static func valid_legacy_unlocks(value: Variant) -> bool:
	if not value is Array or STARTER not in value: return false
	var unique := {}
	for id in value:
		if not id is String or not NODES.has(id) or unique.has(id): return false
		unique[id] = true
	for id in value:
		for parent in NODES[id].requires:
			if parent not in value: return false
	return true

static func availability(id: String, _profile: Dictionary) -> Dictionary:
	if not NODES.has(id): return {"ok":false,"reason":LocalizationService.text("ui_a8f7ab7d3821")}
	return {"ok":false,"reason":"已解锁 · 可加入编队","unlocked":true,"cost":0}

static func unlock(store: ProfileStore, id: String) -> Dictionary:
	return availability(id,store.snapshot())
