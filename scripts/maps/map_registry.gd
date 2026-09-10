class_name MapRegistry
extends RefCounted
## Stable saved IDs are separate from each authored graph's versioned identity.
const IDS := ["hill_village","industrial_edge"]
static var ENTRIES := {
	"hill_village":{"title":LocalizationService.text("ui_a5241c461e94"),"scene":"res://scenes/maps/map_hill_village.tscn","description":LocalizationService.text("ui_ad53bae36b53")},
	"industrial_edge":{"title":LocalizationService.text("ui_4bbb95fad40b"),"scene":"res://scenes/maps/map_industrial_edge.tscn","description":LocalizationService.text("ui_23fc8314090d")}}
static func contains(id: String) -> bool: return ENTRIES.has(id)
static func scene_path(id: String) -> String: return str(ENTRIES.get(id,{}).get("scene",""))
static func definition(id: String) -> MapDefinition:
	if id == "hill_village": return VillageDefinition.create()
	if id == "industrial_edge": return IndustrialDefinition.create()
	return null
