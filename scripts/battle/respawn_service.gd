class_name RespawnService
extends RefCounted
var spawn_provider: Callable

func step(state: TeamMatchState) -> int:
	var spawned := 0
	if state.phase != "playing" or not spawn_provider.is_valid(): return 0
	for id in state.roster:
		var row: Dictionary = state.roster[id]
		if state.phase != "playing": break
		if row.respawn_at < 0 or state.elapsed+1e-8 < float(row.respawn_at) or row.request_sent: continue
		if state.tickets[row.team] <= 0: row.waiting_reason = "no_tickets"; continue
		if row.player and not row.respawn_requested: row.waiting_reason = "choose_vehicle"; continue
		row.request_sent = true
		var vehicle: VehicleActor = spawn_provider.call(id)
		row.request_sent = false
		if state.phase != "playing":
			if is_instance_valid(vehicle): vehicle.queue_free()
			break
		if vehicle == null: row.waiting_reason = "spawn_blocked"; continue
		if state.register_spawn(id,vehicle): spawned += 1
	return spawned

static func find_safe(space: PhysicsDirectSpaceState3D, candidates: Array[Transform3D], size: Vector3, occupied: Array[Vector3]) -> Dictionary:
	if space == null or not size.is_finite() or size.x<=0 or size.y<=0 or size.z<=0: return {"ok":false,"reason":"invalid_spawn_query"}
	var shape := BoxShape3D.new()
	shape.size = size+Vector3(0.3,0,0.3)
	for candidate in candidates:
		if not candidate.is_finite(): continue
		var reserved := false
		for point in occupied:
			var d := point-candidate.origin
			d.y = 0
			if d.length() < size.z+0.6: reserved = true; break
		if reserved: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(candidate.basis,candidate.origin+Vector3.UP*(size.y/2+0.15))
		query.collision_mask = GameConfig.LAYER_WORLD|GameConfig.LAYER_VEHICLE
		if space.intersect_shape(query,1).is_empty(): return {"ok":true,"transform":candidate}
	return {"ok":false,"reason":"spawn_blocked"}
