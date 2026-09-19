extends SceneTree
## VILLAGE ARRIVAL DIAGNOSTIC (WT-EXPANSION-02, after the user's bounded-fix ruling).
##
## WHY THIS EXISTS: the first fix attempt gated movement on the mobility capability instead of on "a repair is
## pending". The village match came out BIT-IDENTICAL, so that reading was wrong and the commit was reverted. The
## unreached-route line prints `hop=(inf, inf, inf)` for the two stranded actors at the moment of failure, so the
## next question is asked of the NAVIGATOR rather than guessed from phases:
##   Q1 is the objective plannable from where the actor strands, with the blocked-edge memory CLEARED?
##   Q2 is it plannable WITH that memory?
##   Q3 does a finite escape hop exist at all?
## Q1 yes + Q2 no means the actor is stranded by remembered traffic blocks (a driver defect worth fixing).
## Q1 no means the pocket itself is disconnected from the objective (a map/topology finding, not a driver defect).
##
## Usage: godot --headless --path <tree> --fixed-fps 60 -s res://tests/probe_village_route.gd

var approached := {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene: Node = load("res://scenes/maps/map_hill_village.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 190: await physics_frame
	if not scene.team_ready:
		print("[route] the village match did not start")
		quit(1); return
	for sample in 24:
		for i in 300: await physics_frame
		for actor in scene.combat_actors():
			if not (actor.controller is AITankController): continue
			var p: Vector3 = actor.tank.global_position
			if absf(p.z) < 45: approached[actor.entity_id] = true
		if sample % 4 == 3:
			_report(scene,"t=%.1fs"%scene.director.state.elapsed,true)
	print("[route] ===== final =====")
	_report(scene,"final",true)
	var missing: Array = []
	for actor in scene.combat_actors():
		if actor.controller is AITankController and not approached.has(actor.entity_id): missing.append(actor.entity_id)
	print("[route] approached=%s missing=%s" % [str(approached.keys()),str(missing)])
	scene.free()
	quit(0)

func _report(scene: Node, tag: String, verbose: bool) -> void:
	for actor in scene.combat_actors():
		if not (actor.controller is AITankController): continue
		var ai: AITankController = actor.controller
		var p: Vector3 = actor.tank.global_position
		var reached: bool = approached.has(actor.entity_id)
		if reached and not verbose: continue
		var drv: AIPathDriver = ai.driver
		var nav: DriveNavigator = drv.navigator
		var width: float = actor.definition.drive_collision_size.x
		var blocked_count := 0
		for key in drv._blocked_edges.keys(): blocked_count += 1
		var clean: Dictionary = nav.request_path(p,ai.patrol_goal,width,{}) if nav != null else {"ok":false,"reason":"no_navigator"}
		var remembered: Dictionary = nav.request_path(p,ai.patrol_goal,width,drv._blocked_edges) if nav != null else {"ok":false,"reason":"no_navigator"}
		# PATH LENGTH is the datum that separates the two live explanations: if the clean route is much shorter than
		# the remembered one, the block MEMORY is what forces the detour; if both are long, the road network does.
		var clean_len := 0
		var remembered_len := 0
		if clean.get("ok",false): clean_len = (clean.get("points",PackedVector3Array()) as PackedVector3Array).size()
		if remembered.get("ok",false): remembered_len = (remembered.get("points",PackedVector3Array()) as PackedVector3Array).size()
		var hop: Vector3 = drv.escape_goal(ai._last_hop,ai._task_hops)
		# The driver's ACTUAL goal matters: the first version of this probe printed only the distance to patrol_goal and
		# then guessed, while the actor may legitimately be driving to a retreat point or a hop instead.
		var row: Dictionary = scene.director.state.roster.get(actor.entity_id,{})
		var to_goal := p.distance_to(drv.goal) if drv.goal.is_finite() else -1.0
		var goal_kind := "none"
		if drv.goal.is_finite():
			if drv.goal.distance_to(ai.patrol_goal) < 1.0: goal_kind = "objective"
			elif drv.goal.distance_to(ai.retreat_goal) < 1.0: goal_kind = "retreat"
			else: goal_kind = "hop"
		print("[route] %s %s ai=%s drv=%s wp=%d/%d dist_wp=%.1f next=(%.0f,%.0f) attempts=%d blocked_edges=%d clean_len=%d remembered_len=%d goal=%s d=%.1f hops=%d obj_blocked=%s ammo=%d deaths=%d dist_obj=%.1f z=%.1f approached=%s" % [
			tag,actor.entity_id,ai.phase,drv.phase,drv.waypoint,drv.path.size(),
			(p.distance_to(drv.path[drv.waypoint]) if drv.waypoint < drv.path.size() else -1.0),
			(drv.path[drv.waypoint].x if drv.waypoint < drv.path.size() else 0.0),(drv.path[drv.waypoint].z if drv.waypoint < drv.path.size() else 0.0),
			drv.attempts,blocked_count,clean_len,remembered_len,
			goal_kind,to_goal,ai._task_hops.size(),str(ai.objective_blocked),
			actor.gunner.rounds_remaining,int(row.get("deaths",-1)),
			p.distance_to(ai.patrol_goal),p.z,str(reached)])
