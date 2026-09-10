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
	if not NODES.has(id): return {"ok":false,"reason":LocalizationService.text("ui_a8f7ab7d3821")}
	if id in profile.unlocked: return {"ok":false,"reason":LocalizationService.text("ui_7bf4de603d1f"),"unlocked":true}
	for parent in NODES[id].requires:
		if parent not in profile.unlocked: return {"ok":false,"reason":LocalizationService.text("ui_b574af07e8e6") if parent != STARTER else LocalizationService.text("ui_eccaba37ca76")}
	var cost: int = NODES[id].cost
	if profile.research_points < cost: return {"ok":false,"reason":LocalizationService.text("ui_6ee5274dd5cb")%[cost,profile.research_points]}
	return {"ok":true,"cost":cost,"reason":LocalizationService.text("ui_96e563db1fd5")%cost}

static func unlock(store: ProfileStore, id: String) -> Dictionary:
	var next := store.snapshot()
	var checked := availability(id,next)
	if not checked.ok: return checked
	next.research_points -= checked.cost
	next.unlocked.append(id)
	var committed := store.commit(next)
	return {"ok":true,"reason":LocalizationService.text("ui_caa1489b81ba")%checked.cost} if committed.ok else committed
