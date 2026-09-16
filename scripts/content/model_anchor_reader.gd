class_name ModelAnchorReader
extends RefCounted
## WT-040-R1 (user ruling 2/3): read the AUTHORED attachment anchors out of the model that is going to be
## bound, so that placement and model agree BY CONSTRUCTION rather than by tolerance.
##
## Why this exists: the module and crew drafts used to derive their positions from measured boxes, which is
## a different derivation from the anchors the delivered model actually carries. The binding validator then
## correctly reported "actual anchor differs from layout local transform" and "wrong moving parent" for
## almost every internal item. The model that ships is the truth about where its own parts are, so the
## placement is taken from it, and the measured derivation stays as a labelled fallback for any id the
## model does not anchor.
##
## Every value returned here comes from the artefact: nothing is estimated, and a missing anchor is
## reported as missing rather than filled in.

const DEFAULT_MODEL := ""

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false,"reason":"asset_missing","path":path,"anchors":{},"roles":{},"by_name":{}}
	var probe: Dictionary = ModelBindingProbe.probe(path)
	if not probe.get("ok",false):
		return {"ok":false,"reason":str(probe.get("reason","probe_failed")),"path":path,"anchors":{},"roles":{},"by_name":{}}
	var parent := {}
	var origin := {}
	var by_path := {}
	for row in probe.get("nodes",[]):
		var p := str(row.get("path",""))
		by_path[p] = str(row.get("name",""))
		parent[p] = str(row.get("parent",""))
		var o: Array = row.get("origin",[0.0,0.0,0.0])
		origin[p] = Vector3(float(o[0]),float(o[1]),float(o[2]))
	# Accumulated position from the scene root: the pivots carry translations and no rotation of interest,
	# so summing the local origins along the chain puts every anchor in one comparable space.
	var acc := func(p: String) -> Vector3:
		var total := Vector3.ZERO
		var cur := p
		var guard := 0
		while not cur.is_empty() and cur != "." and origin.has(cur) and guard < 128:
			total += origin[cur]
			cur = str(parent.get(cur,""))
			guard += 1
		return total
	var roles := {"hull":"","turret":"","barrel":""}
	for p in by_path.keys():
		match str(by_path[p]):
			"TurretPivot": roles["turret"] = p
			"GunPivot": roles["barrel"] = p
		if str(parent.get(p,"")) == ".": roles["hull"] = p
	var anchors := {}
	for p in by_path.keys():
		var nm := str(by_path[p])
		if nm.begins_with("Attachment_"):
			anchors[nm] = {"path":p, "parent":str(parent.get(p,"")), "position":acc.call(p)}
	return {"ok":true,"path":path,"sha256":str(probe.get("sha256","")),
		"node_count":int(probe.get("node_count",0)),"anchors":anchors,"roles":roles,"by_name":by_path}

## Position of an anchor expressed relative to the part that owns it, which is the space the layout uses.
static func part_relative(path: String, anchor_name: String, part: String) -> Dictionary:
	var info := read(path)
	if not info.get("ok",false): return {"ok":false,"reason":str(info.get("reason","unreadable")),"position":Vector3.ZERO,"part_node":""}
	var anchors: Dictionary = info["anchors"]
	if not anchors.has(anchor_name):
		return {"ok":false,"reason":"anchor_absent","position":Vector3.ZERO,"part_node":"","anchor":anchor_name}
	var roles: Dictionary = info["roles"]
	var part_node := str(roles.get(part,roles.get("hull","")))
	var anchor_pos: Vector3 = anchors[anchor_name]["position"]
	var part_pos := Vector3.ZERO
	if not part_node.is_empty():
		# the part node's accumulated position is recomputed the same way, from the same artefact
		part_pos = _accumulated(path, part_node)
	return {"ok":true,"position":anchor_pos-part_pos,"anchor":anchor_name,"part":part,
		"part_node":part_node,"anchor_parent":str(anchors[anchor_name]["parent"]),
		"anchor_position":anchor_pos,"part_position":part_pos}

static func _accumulated(path: String, node_path: String) -> Vector3:
	if node_path.is_empty(): return Vector3.ZERO
	var probe: Dictionary = ModelBindingProbe.probe(path)
	if not probe.get("ok",false): return Vector3.ZERO
	var parent := {}
	var origin := {}
	for row in probe.get("nodes",[]):
		var p := str(row.get("path",""))
		parent[p] = str(row.get("parent",""))
		var o: Array = row.get("origin",[0.0,0.0,0.0])
		origin[p] = Vector3(float(o[0]),float(o[1]),float(o[2]))
	var total := Vector3.ZERO
	var cur := node_path
	var guard := 0
	while not cur.is_empty() and cur != "." and origin.has(cur) and guard < 128:
		total += origin[cur]
		cur = str(parent.get(cur,""))
		guard += 1
	return total
