extends SceneTree
## WT-040-R1 probe: report the river navigation graph's SIZE against DriveNavigator's hard caps
## (nodes <= 1024, edges <= 4096). Written because two additive attempts failed with 0/8 routable and
## the navigator's validate() fails the WHOLE graph on a capacity breach, so the count is decisive.
func _init() -> void:
	for team_size in [4,10,16]:
		var graph: Dictionary = RiverJunctionNavigation.new().build(team_size)
		var n: int = (graph.get("nodes",[]) as Array).size()
		var e: int = (graph.get("edges",[]) as Array).size()
		var verdict: String = "OK" if n <= 1024 and e <= 4096 else "OVER CAP"
		print("[graph-size] team_size=%d nodes=%d/1024 edges=%d/4096 headroom_nodes=%d -> %s"
			% [team_size,n,e,1024-n,verdict])
		var probe: DriveNavigator = DriveNavigator.new()
		var ok: Dictionary = probe.configure(graph)
		print("[graph-size]   configure() = %s" % JSON.stringify(ok))
	quit(0)
