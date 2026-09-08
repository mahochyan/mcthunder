class_name ResearchGraph
extends RefCounted
## Small game economy. Never changes historical vehicle or shell performance.
const STARTER := "us_m4a3_75w_vvss_1944"
const NODES := {
	"us_m4a3_75w_vvss_1944":{"cost":0,"requires":[]},
	"us_m24_m6_t85e1_1951":{"cost":80,"requires":[STARTER]},
	"us_m36_m4a1_1945":{"cost":120,"requires":[STARTER]},
	"us_m26_m3_1945":{"cost":180,"requires":["us_m36_m4a1_1945"]}}

static func availability(id: String, profile: Dictionary) -> Dictionary:
	if not NODES.has(id): return {"ok":false,"reason":"车型不在研发图中"}
	if id in profile.unlocked: return {"ok":false,"reason":"已研发","unlocked":true}
	for parent in NODES[id].requires:
		if parent not in profile.unlocked: return {"ok":false,"reason":"需要先研发 M36" if parent != STARTER else "需要先研发 M4"}
	var cost: int = NODES[id].cost
	if profile.research_points < cost: return {"ok":false,"reason":"需要%d研发点（现有%d）"%[cost,profile.research_points]}
	return {"ok":true,"cost":cost,"reason":"研发需要%d点"%cost}

static func unlock(store: ProfileStore, id: String) -> Dictionary:
	var next := store.snapshot()
	var checked := availability(id,next)
	if not checked.ok: return checked
	next.research_points -= checked.cost
	next.unlocked.append(id)
	var committed := store.commit(next)
	return {"ok":true,"reason":"已研发，花费%d点"%checked.cost} if committed.ok else committed
