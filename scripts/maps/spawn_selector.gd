class_name SpawnSelector
extends RefCounted
static func evaluate(space: PhysicsDirectSpaceState3D, candidates: Array[Transform3D], size: Vector3, occupied: Array[Vector3]) -> Dictionary:
	return RespawnService.find_safe(space,candidates,size,occupied)

static func opposing_spawn_sightlines(space: PhysicsDirectSpaceState3D, map: MapDefinition) -> Dictionary:
	var exposed: Array = []
	var tested := 0
	for a: Transform3D in map.spawns[1]:
		for b: Transform3D in map.spawns[2]:
			for height_m in [1.4,2.4,3.5]:
				tested += 1
				var ray := PhysicsRayQueryParameters3D.create(a.origin+Vector3.UP*height_m,b.origin+Vector3.UP*height_m,GameConfig.LAYER_WORLD)
				if space.intersect_ray(ray).is_empty(): exposed.append([a.origin,b.origin,height_m])
	return {"ok":exposed.is_empty(),"tested":tested,"exposed":exposed}
