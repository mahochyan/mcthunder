class_name RiverTeamRange
extends VillageRange
## WT-040-R1 (user directive 2026-09-15): the river as a TEAM match scene.
##
## VillageRange extends TeamRange, which owns the whole match machinery the user asked the river to
## join: the roster (A is human unless ai_only is set), per-slot AI spawns through
## director.respawns.spawn_provider, tickets, the match clock, respawn/re-entry and the objective
## goal. This scene only supplies what is map-specific: the river MapDefinition, the river world,
## the river's own navigation graph and its spawn candidates.
##
## It is an ENGINEERING match scene: RiverJunctionDefinition still declares the layout as
## design_preview / combat_admitted=false, and this class neither hides nor flips that. It lets a
## real AI match be run on the authored geometry and measured; admitting the river as a combat map
## remains a design decision for the user.
var trial_team_size := RiverTeamDefinition.DEFAULT_TEAM_SIZE

func _init() -> void:
	definition = RiverTeamDefinition.create(trial_team_size)

func _build_world() -> void:
	var builder := RiverJunctionWorld.new()
	builder.build(self)

## The river's own graph, so routes follow the authored roads and bridges rather than the arena's.
func navigation_graph() -> Dictionary:
	return definition.graph.duplicate(true)

func spawn_candidates(team: int) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	poses.assign(definition.spawns[team])
	return poses

## Resupply behind each deployment area, as the single-car river range already does.
func supply_positions(team: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for row in RiverJunctionDefinition.supply_points(trial_team_size):
		if int(row.team) == team:
			out.append(RiverJunctionDefinition.point(row.xz))
	return out

## WT-040-R1: TeamRange.objective_goal() returns TeamArena.goal(), i.e. the LEGACY arena's eight
## small-map approach points (GOALS around x +-8, z +-6..9). Inheriting that made the first full
## river run spend 155 seconds with both teams alive and no engagement, because the AI was driving
## to arena coordinates instead of the river's objectives.
##
## The first version of this override aimed at the capture CENTRES and the map's central crossing
## stop. A route probe then showed that only 2 of 8 actors could find a path at all (ok=false, zero
## nodes) for the A, B and central points, while the C point routed with 65/75 nodes - i.e. the
## chosen task points were not usable vehicle points on the navigation graph. This version therefore
## keeps the map's own authored intent (A/B/C entrances from driving_stops, central crossing at lane
## zero), but SNAPS each one to the nearest node that actually exists in the map's navigation graph,
## which is the only change made: the first failing link (path) is fixed and nothing else - no speed
## change, no map change, no teleport, no cooldown change, no fabricated hits.
func objective_goal(team: int, index: int) -> Vector3:
	var wanted: Vector3 = _wanted_task_point(index)
	return _snap_to_graph(wanted)

## The map's authored task points, in the order the slots take them.
func _wanted_task_point(index: int) -> Vector3:
	var stops: Array[Dictionary] = RiverJunctionDefinition.driving_stops(trial_team_size)
	if index >= 0 and index < 3:
		# The first three slots take the map's own A / B / C entrances, which sit on the roads.
		var entrance := 0
		for stop in stops:
			var xz: Vector2 = stop.xz
			# Entrances are the three stops that are neither a deployment area nor a lane crossing:
			# deployment areas sit on the extreme z, crossings on the three authored lanes at z=90.
			if absf(xz.y) < 400.0 and absf(xz.y) > 150.0:
				if entrance == index:
					return RiverJunctionDefinition.point(xz)
				entrance += 1
	# Fourth slot: the central crossing, identified by position rather than title text.
	for stop in stops:
		var xz2: Vector2 = stop.xz
		if absf(xz2.x) < 1.0:
			return RiverJunctionDefinition.point(xz2)
	return Vector3.ZERO

## Snap a wanted point to the nearest node of the map's OWN navigation graph. The graph is produced
## by RiverJunctionNavigation.build(), so its nodes are the points the navigator can actually route
## between; aiming anywhere else made request_path fail outright.
func _snap_to_graph(wanted: Vector3) -> Vector3:
	var nodes: Variant = definition.graph.get("nodes", [])
	if not nodes is Array or nodes.is_empty():
		return wanted
	var best: Vector3 = wanted
	var best_d := INF
	for node in nodes:
		if not node is Dictionary: continue
		var pos: Variant = node.get("position", null)
		if not pos is Array or pos.size() < 3: continue
		var candidate := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		var d := candidate.distance_to(wanted)
		if d < best_d:
			best_d = d
			best = candidate
	return best

## Team size is chosen by the caller (the recorder uses 4 per team for the first closure the user
## asked for); 10v10/16v16 berths are NOT a capacity claim until they are measured on their own.
func set_trial_team_size(value: int) -> void:
	trial_team_size = value
	definition = RiverTeamDefinition.create(trial_team_size)
