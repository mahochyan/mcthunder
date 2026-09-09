class_name WorldProps
extends RefCounted
## Deterministic, conservative placement outside every authored road envelope.
static func placements(map: MapDefinition) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var nav := DriveNavigator.new(); nav.configure(map.graph)
	for x in [145,110,85,20]:
		for z in [150,110,75,35]:
			if out.size()>=16: break
			var p := Vector3(x,0,z)
			if not clear(map,nav,p) or not clear(map,nav,-p): continue
			for sign in [-1,1]:
				var at: Vector3 = p*sign
				if map.id=="hill_village_018": at.y=VillageDefinition.height(at.x,at.z)-0.1
				out.append({"position":at,"kind":"tree" if out.size()%4<2 else "rock"})
	return out

static func clear(map: MapDefinition, nav: DriveNavigator, p: Vector3) -> bool:
	var at := Vector2(p.x,p.z)
	if not map.bounds.grow(-6).has_point(at): return false
	for edge in map.graph.edges:
		var a: Vector3=nav.nodes[edge.a]; var b: Vector3=nav.nodes[edge.b]
		var nearest := Geometry2D.get_closest_point_to_segment(at,Vector2(a.x,a.z),Vector2(b.x,b.z))
		if nearest.distance_to(at)<float(edge.width)/2+map.max_vehicle_size.x/2+4: return false
	for obstacle in map.obstacles:
		var center: Vector3=obstacle.position; var size: Vector3=obstacle.size
		if Rect2(center.x-size.x/2,center.z-size.z/2,size.x,size.z).grow(5).has_point(at): return false
	for row in SpecialStructures.placements(map):
		if (p-row.position).length()<15: return false
	for supply in map.supply_reservations:
		if (p-supply).length()<20: return false
	return true

static func build(parent: Node3D, map: MapDefinition) -> void:
	for row in placements(map):
		if row.kind=="tree": WorldArtKit.tree(parent,row.position)
		else: WorldArtKit.rocks(parent,row.position)
