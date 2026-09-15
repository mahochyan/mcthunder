class_name MapRegistry
extends RefCounted
## Stable saved IDs are separate from each authored graph's versioned identity.
const IDS := ["hill_village","industrial_edge"]
static var ENTRIES := {
	"hill_village":{"title":LocalizationService.text("ui_a5241c461e94"),"scene":"res://scenes/maps/map_hill_village.tscn","description":LocalizationService.text("ui_ad53bae36b53")},
	"industrial_edge":{"title":LocalizationService.text("ui_4bbb95fad40b"),"scene":"res://scenes/maps/map_industrial_edge.tscn","description":LocalizationService.text("ui_23fc8314090d")},
	# WT-040-R1 (user directive 2026-09-15): the river as a TEAM match scene, reachable by path so an
	# engineering AI match can be run and measured on the authored river geometry. It is deliberately
	# NOT listed in IDS: RiverJunctionDefinition still declares the layout design_preview /
	# combat_admitted=false, so it is not offered to the player as an admitted combat map until that
	# is decided. Adding it to IDS is the one-line change that would expose it in the garage list.
	"river_junction_team":{"title":"River Junction (engineering AI match)","scene":"res://scenes/maps/map_river_team.tscn","description":"Authored river junction layout; AI team match for measurement, not yet combat-admitted"}}
static func contains(id: String) -> bool: return ENTRIES.has(id)
static func scene_path(id: String) -> String: return str(ENTRIES.get(id,{}).get("scene",""))
static func definition(id: String) -> MapDefinition:
	if id == "hill_village": return VillageDefinition.create()
	if id == "industrial_edge": return IndustrialDefinition.create()
	if id == "river_junction_team": return RiverTeamDefinition.create()
	return null
