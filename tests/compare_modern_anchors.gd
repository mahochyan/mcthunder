extends SceneTree
## WT-040-R1: compare the model's OWN attachment anchor origins against the draft positions the layout
## carries. The binding validator requires them to agree within a small tolerance, so this decides whether
## the difference is a coordinate convention or genuinely different data - and therefore whether the layout
## must be re-derived FROM the anchors rather than the tolerance widened.
const CASES := [
	{"id":"ussr_t_80b","glb":"res://assets/vehicles/adapters/../modern_bound/ussr_t_80b.glb"},
	{"id":"germ_leopard_2a4","glb":"res://assets/vehicles/modern_bound/germ_leopard_2a4.glb"},
]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var mods := _read("res://logs/WT-040-R1/modern_modules_draft.json")
	var crew := _read("res://logs/WT-040-R1/modern_crew_draft.json")
	for case in CASES:
		var id := str(case.id)
		var report: Dictionary = ModelBindingProbe.probe(str(case.glb))
		var origin := {}
		var parent := {}
		for row in report.get("nodes",[]):
			origin[str(row.get("name",""))] = row.get("origin",[])
			parent[str(row.get("name",""))] = str(row.get("parent",""))
		print("[anchors] === ",id," nodes=",report.get("node_count",0))
		var row_mod: Dictionary = {}
		for r in mods.get("rows",[]):
			if str(r.get("id","")) == id: row_mod = r
		for m in row_mod.get("modules",[]):
			var mid := str(m.get("id",""))
			var anchor := str(m.get("anchor","Attachment_"+mid)) if m.has("anchor") else "Attachment_"+mid
			print("    module %-14s draft_pos=%s   anchor=%-28s origin=%s parent=%s" % [mid,str(m.get("position","?")),anchor,str(origin.get(anchor,"MISSING")),str(parent.get(anchor,"-"))])
		var row_crew: Dictionary = {}
		for r in crew.get("rows",[]):
			if str(r.get("id","")) == id: row_crew = r
		for st in row_crew.get("crew",[]):
			var cid := str(st.get("id",""))
			var anchor := "Attachment_"+cid
			print("    crew   %-14s draft_pos=%s   anchor=%-28s origin=%s parent=%s" % [cid,str(st.get("position","?")),anchor,str(origin.get(anchor,"MISSING")),str(parent.get(anchor,"-"))])
	print("MODERN_ANCHOR_COMPARISON_DONE")
	quit(0)
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}