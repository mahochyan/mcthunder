class_name VillageRange
extends TeamRange
var definition := VillageDefinition.create()
var terrain: StaticBody3D
var graybox := false
func _build_world() -> void: terrain = VillageWorld.build(self,definition,graybox)
func navigation_graph() -> Dictionary: return definition.graph.duplicate(true)
func spawn_candidates(team: int) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	poses.assign(definition.spawns[team])
	return poses
func minimap_metadata() -> Dictionary: return definition.minimap()
func supply_positions(team: int) -> Array[Vector3]:
	return [definition.supply_reservations[team-1]] if team in [1,2] else []
