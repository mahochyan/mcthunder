extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var defs := VehicleDefs.new(); defs.load_defaults()
	print("[p] === 车辆宽度与速度 ===")
	for id in VehicleCatalog.IDS:
		var d = defs.definition(id)
		print("[p] ",id," width=",d.drive_collision_size.x," len=",d.drive_collision_size.z," fwd=",d.forward_max_speed," rev=",d.reverse_max_speed)
	var map := VillageDefinition.create()
	var graph = map.graph
	print("[p] graph nodes=",graph.nodes.size()," edges=",graph.edges.size())
	var keys = graph.nodes.keys()
	print("[p] 前 6 个节点: ")
	for i in min(6,keys.size()):
		var n = graph.nodes[keys[i]]
		print("[p]   ",keys[i]," pos=",n.position," width=",n.get("width",-1))
	# 找最窄边
	var narrow := []
	for e in graph.edges:
		var w = e.get("width",-1.0)
		if w > 0 and w < 6.0: narrow.append({"a":e.get("a",""),"b":e.get("b",""),"width":w})
	narrow.sort_custom(func(x,y): return float(x.width) < float(y.width))
	print("[p] 最窄 8 条边:")
	for i in min(8,narrow.size()): print("[p]   ",narrow[i])
	# 出生点
	print("[p] spawns[1][2]=",map.spawns[1][2].origin," spawns[1][0]=",map.spawns[1][0].origin)
	var nav := DriveNavigator.new(); nav.configure(graph)
	var d0 = defs.definition("us_m26_m3_1945")
	var r = nav.request_path(map.spawns[1][2].origin, TeamArena.goal(1,2), d0.drive_collision_size.x, {})
	print("[p] M26 从 slot2 到 goal(1,2): ok=",r.get("ok",false)," reason=",r.get("reason","")," points=",r.get("path",[]).size() if r.get("path") else 0)
	var r2 = nav.request_path(map.spawns[1][0].origin, TeamArena.goal(1,0), d0.drive_collision_size.x, {})
	print("[p] M26 从 slot0 到 goal(1,0): ok=",r2.get("ok",false)," reason=",r2.get("reason",""))
	quit(0)
