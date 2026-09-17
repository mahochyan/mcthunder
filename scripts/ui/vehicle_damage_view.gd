class_name VehicleDamageView
extends RefCounted
## Owner-only, read-only geometry/status adapter. Never queries opponents.
const COLORS := {"intact":Color("8ba9ad"),"light":Color("ecd36b"),"heavy":Color("ef984e"),"critical":Color("ed584b"),"disabled":Color("171d24"),"unknown":Color("6d7381"),"vacant":Color("555d69"),"crew":Color("88cabb")}
const BOX_FACES := [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]

static func condition(fraction: float) -> String:
	if not is_finite(fraction) or fraction < 0: return "unknown"
	if fraction <= 0: return "disabled"
	if fraction < .34: return "critical"
	if fraction < .67: return "heavy"
	if fraction < 1.0: return "light"
	return "intact"

static func box_points(pose: Transform3D, size: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in 8:
		points.append(pose*(Vector3(1 if i&1 else -1,1 if i&2 else -1,1 if i&4 else -1)*size*.5))
	return points

static func sample(actor: VehicleActor) -> Dictionary:
	if not is_instance_valid(actor) or actor.damage_layout_override==null: return {}
	var layout := actor.damage_layout_override
	var inverse := actor.tank.hull_frame.global_transform.affine_inverse()
	var poses := {}
	for part in layout.parts:
		var node := DamageTrainingLayout.part_node(actor,part.id)
		if node!=null: poses[part.id]=inverse*node.global_transform
	var shell: Array=[]
	for patch in layout.armor_patches:
		if not poses.has(patch.part_id): continue
		var polygon := PackedVector3Array()
		for point in patch.vertices_local_m: polygon.append(poses[patch.part_id]*point)
		shell.append(polygon)
	var items: Array=[]
	for module in layout.modules:
		if not poses.has(module.part_id): continue
		var state: Dictionary=actor.state.module_states.get(module.id,{})
		var fraction := -1.0
		if not state.is_empty(): fraction=clampf(float(state.integrity)/maxf(.001,float(state.max_integrity)),0,1)
		var pose: Transform3D=poses[module.part_id]*module.local_box_transform
		items.append({"id":module.id,"kind":module.kind,"part":module.part_id,"points":box_points(pose,module.size_m),
			"center":pose.origin,"condition":condition(fraction),"fraction":fraction,"crew":false,
			"empty":module.kind=="ammo" and actor.gunner.inventory.racks.has(module.id) and int(actor.gunner.inventory.racks[module.id])==0,
			"burning":actor.state.fires.has(module.id),"repairing":actor.state.recovery_action=="repair" and actor.state.action_target==module.id})
	for station in layout.crew_stations:
		if not poses.has(station.part_id): continue
		var person: String=actor.state.crew_assignments.get(station.role,"")
		var alive := actor.state.role_available(station.role)
		var pose: Transform3D=poses[station.part_id]*station.local_box_transform
		items.append({"id":station.id,"kind":station.role,"part":station.part_id,"points":box_points(pose,station.size_m),
			"center":pose.origin,"condition":"crew" if alive else ("vacant" if person.is_empty() else "disabled"),
			"fraction":1.0 if alive else 0.0,"crew":true,"empty":false,"burning":false,"repairing":false})
	return {"entity_id":actor.entity_id,"life_id":actor.life_id,"generation":actor.state.generation,
		"vehicle_id":actor.definition.id,"shell":shell,"items":items,"destroyed":actor.state.destroyed,
		"gun_base":inverse*actor.turret.barrel_pivot.global_position,"muzzle":inverse*actor.turret.muzzle.global_position}
