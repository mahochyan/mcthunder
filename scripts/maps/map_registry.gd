class_name MapRegistry
extends RefCounted
## Stable saved IDs are separate from each authored graph's versioned identity.
const IDS := ["hill_village","industrial_edge"]
const ENTRIES := {
	"hill_village":{"title":"丘陵村落","scene":"res://scenes/maps/map_hill_village.tscn","description":"坡地观察 · 村庄掩体 · 长距离绕侧"},
	"industrial_edge":{"title":"工业边缘","scene":"res://scenes/maps/map_industrial_edge.tscn","description":"仓库街角 · 货运广场 · 外环绕行"}}
static func contains(id: String) -> bool: return ENTRIES.has(id)
static func scene_path(id: String) -> String: return str(ENTRIES.get(id,{}).get("scene",""))
static func definition(id: String) -> MapDefinition:
	if id == "hill_village": return VillageDefinition.create()
	if id == "industrial_edge": return IndustrialDefinition.create()
	return null
