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
## to arena coordinates instead of the river's objectives. Override with the map's OWN contested
## points: the three authored capture centres A/B/C for the first three slots of each team, and the
## central crossing from the map's authored driving stops for the fourth. Both teams therefore aim
## at the same contested ground, which is what a capture match needs.
func objective_goal(team: int, index: int) -> Vector3:
	var captures: Array[Dictionary] = RiverJunctionDefinition.capture_definitions()
	if index >= 0 and index < captures.size():
		return captures[index].center
	# Fourth slot: the map's CENTRAL crossing. Identify it by position, not by title text - a
	# substring match on the title ("0 m") also matched the "-520 m" lane and sent the slot to the
	# wrong bank.
	for stop in RiverJunctionDefinition.driving_stops(trial_team_size):
		var xz: Vector2 = stop.xz
		if absf(xz.x) < 1.0:
			return RiverJunctionDefinition.point(xz)
	return Vector3.ZERO

## Team size is chosen by the caller (the recorder uses 4 per team for the first closure the user
## asked for); 10v10/16v16 berths are NOT a capacity claim until they are measured on their own.
func set_trial_team_size(value: int) -> void:
	trial_team_size = value
	definition = RiverTeamDefinition.create(trial_team_size)
