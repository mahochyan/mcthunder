class_name RiverTeamDefinition
extends RefCounted
## WT-040-R1 (user directive 2026-09-15): "put the river into a real team match".
##
## Why this file has to exist: RiverJunctionRange extends BallisticsRange and keeps its own
## single-car capture director, and RiverJunctionDefinition exposes layout helpers as statics only -
## it never produced a MapDefinition, so the shared TeamRange match machinery (AI rosters, tickets,
## respawns, director clock) had nothing to consume. The map therefore had driving, roads and the
## three-point rule but could not be a team battle.
##
## Every value below comes from RiverJunctionDefinition's own authored data: bounds and crossings
## from layout(), the route graph from route_graph(), spawn rows from spawns(), supply from
## supply_points(), objectives from capture_definitions(). Nothing is invented here.
##
## NOTE, deliberately not hidden: layout() also returns "status":"design_preview" and
## "combat_admitted":false. This definition does NOT flip that flag. It exists so an engineering
## AI match can be measured on the authored river geometry, and any claim that the river is an
## ADMITTED combat map still needs the author's/user's decision - see the report that cites this.
const DEFAULT_TEAM_SIZE := 16

## WT-040-R1 ② (user ruling 2026-09-16): the engineering team entry is REGISTERED explicitly instead
## of being inferred. Match size decides how many vehicles deploy; layout version decides which
## authored geometry they deploy onto. The first engineering target is 4v4 ON THE 16v16 LAYOUT: that
## is a legal development configuration, and it is stated here rather than reached by passing 4 and
## letting the definition substitute a layout. The 10v10/16v16 goals remain, but no capacity claim
## is made for them yet.
const ENGINEERING_MATCH := {
	"match_size": 4,
	"layout_version": 16,
	"objective_ids": ["A","B","C"],
	"supply_ids": ["supply1","supply2"],
	"status": "engineering_candidate",
	"combat_admitted": false,
	"note": "4v4 vehicles on the authored 16v16 layout; engineering entry only, admission unchanged",
}

static func create(match_size: int = -1, layout_version: int = -1) -> MapDefinition:
	var ms := match_size if match_size > 0 else int(ENGINEERING_MATCH.match_size)
	var lv := layout_version if layout_version in RiverJunctionDefinition.LAYOUT_VERSIONS else int(ENGINEERING_MATCH.layout_version)
	var layout := RiverJunctionDefinition.layout(lv)
	var map := MapDefinition.new()
	map.id = "river_junction_team_%dv%d_on_layout%d" % [ms, ms, lv]
	map.title = "River Junction (engineering AI match, %dv%d on the %dv%d layout)" % [ms, ms, lv, lv]
	map.bounds = layout.bounds
	map.max_vehicle_size = Vector3(4.2, 2.4, 8.5)

	# Route graph: the MAP'S OWN navigation builder. RiverJunctionDefinition.route_graph() is the
	# strategic design graph (Vector2 nodes, [a,b] edges, scope "strategic_design_only") and is NOT
	# the shape the shared machinery consumes - using it made the first run fail inside
	# MapDefinition.minimap. RiverJunctionNavigation.build() already emits the expected shape,
	# {"schema_version", "nodes":[{"id","position":[x,y,z]}], "edges":...}, with the real terrain
	# height applied to every node, so the AI drives the authored roads and bridges.
	# WT-040-R1 ②: the builder now takes BOTH, because the spawn-derived columns depend on the match
	# size while the roads, rows and deployment depth come from the layout version.
	map.graph = RiverJunctionNavigation.new().build(lv, ms)

	# Spawn rows: the authored poses for this match size on this layout version.
	var spawns: Dictionary = {}
	for team in [1, 2]:
		var poses: Array[Transform3D] = []
		poses.assign(RiverJunctionDefinition.spawns(ms, team, lv))
		spawns[team] = poses
	map.spawns = spawns

	# Resupply sits behind each deployment area, as on the other maps.
	for row in RiverJunctionDefinition.supply_points(ms, lv):
		map.supply_reservations.append(RiverJunctionDefinition.point(row.xz))

	# Hard cover, converted from the map's own rows ({"id","xz","footprint","height"}) into the
	# shape the validator and minimap expect ({"kind","position","size"}). The KIND is a mapping
	# decision, not authored data: the river publishes hard cover without a collision kind, so it is
	# mapped to the known solid/shell-blocking/LOS-blocking kind "stone_wall" and is listed as
	# needs-author in the report rather than passed off as the map's own classification.
	var obstacles: Array[Dictionary] = []
	for entry in RiverJunctionDefinition.hard_cover():
		var xz: Vector2 = entry.xz
		var footprint: Vector2 = entry.footprint
		var height: float = float(entry.get("height", 4.0))
		obstacles.append({
			"id": str(entry.id),
			"kind": "stone_wall",
			"position": RiverJunctionDefinition.point(xz, height * 0.5),
			"size": Vector3(footprint.x, height, footprint.y),
		})
	map.obstacles = obstacles
	return map

## The three capture points, exposed for the match director exactly as authored.
static func capture_points() -> Array[Dictionary]:
	return RiverJunctionDefinition.capture_definitions()
