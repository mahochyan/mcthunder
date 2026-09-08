class_name ShellEffectPolicy
extends RefCounted
## Deliberately nonphysical game rule. No explosive or fuze engineering parameters.
const VERSION := "021-toy-inside-v1"
const INSIDE_PATH_M := 0.8
const MAX_FRAGMENTS := 12
const FRAGMENT_RANGE_M := 3.0
const FRAGMENT_CONTACTS := 8
const FRAGMENT_BUDGET_MM := 12.0
const EPS := 0.0001

static func target_snapshot(event: Dictionary, snapshots: Array) -> Dictionary:
	for snapshot in snapshots:
		if DamageResolver.target_key(snapshot) == DamageResolver.target_key(event): return snapshot
	return {}

static func _triangles(snapshot: Dictionary, part_id: String) -> Array:
	var out: Array = []
	var layout: VehicleLayoutDefinition = snapshot.get("layout")
	if layout == null: return out
	for patch in layout.armor_patches:
		if patch.part_id != part_id: continue
		for i in range(0,patch.triangles.size(),3):
			out.append([patch.vertices_local_m[patch.triangles[i]],patch.vertices_local_m[patch.triangles[i+1]],patch.vertices_local_m[patch.triangles[i+2]]])
	# Caps define the limit of inside travel through real openings. They are not armor and never consume penetration.
	for opening in layout.declared_openings:
		if opening.get("part","") != part_id: continue
		var loop: Array = opening.get("boundary_loop",[])
		for i in range(1,loop.size()-1): out.append([loop[0],loop[i],loop[i+1]])
	return out

static func _distances(point: Vector3, direction: Vector3, triangles: Array) -> Array[float]:
	var out: Array[float] = []
	for tri in triangles:
		var hit: Variant = Geometry3D.ray_intersects_triangle(point,direction,tri[0],tri[1],tri[2])
		if hit == null: continue
		var distance := point.distance_to(hit)
		var duplicate := false
		for other in out:
			if absf(other-distance) < EPS: duplicate = true; break
		if not duplicate: out.append(distance)
	out.sort()
	return out

static func inside(snapshot: Dictionary, point: Vector3) -> bool:
	var transforms: Dictionary = snapshot.get("part_world_transforms",{})
	for part_id in ["hull","turret"]:
		if not transforms.has(part_id): continue
		var local: Vector3 = (transforms[part_id] as Transform3D).affine_inverse()*point
		var distances := _distances(local,Vector3(0.713,0.421,0.561).normalized(),_triangles(snapshot,part_id))
		if distances.size()%2 == 1: return true
	return false

static func exit_distance(snapshot: Dictionary, point: Vector3, direction: Vector3, maximum: float) -> float:
	if snapshot.is_empty(): return 0.0
	var transforms: Dictionary = snapshot.get("part_world_transforms",{})
	var candidates: Array[float] = []
	for part_id in ["hull","turret"]:
		if not transforms.has(part_id): continue
		var inverse: Transform3D = (transforms[part_id] as Transform3D).affine_inverse()
		for distance in _distances(inverse*point,inverse.basis*direction,_triangles(snapshot,part_id)):
			if distance <= maximum+EPS: candidates.append(distance)
	candidates.sort()
	for distance in candidates:
		if not inside(snapshot,point+direction*(distance+EPS*2)): return distance
	return INF

static func on_inside_path(st: ProjectileState, snapshots: Array, direction: Vector3, maximum: float) -> Dictionary:
	if st.effect_policy != "internal_burst" or st.burst_target.is_empty(): return {}
	var snapshot := target_snapshot(st.burst_target,snapshots)
	if snapshot.is_empty():
		st.burst_target.clear(); return {}
	var at_inside := inside(snapshot,st.position_world+direction*EPS*2)
	if not st.burst_inside_started:
		if at_inside:
			st.burst_inside_started=true; st.burst_entry_distance=st.travelled_m
		else:
			# An exterior shield can authorize the target before the ray reaches its compartment.
			# Count only the later actual inside travel, never the air gap behind that shield.
			var transforms: Dictionary = snapshot.get("part_world_transforms",{})
			var entries: Array[float] = []
			for part_id in ["hull","turret"]:
				if not transforms.has(part_id): continue
				var inverse: Transform3D = (transforms[part_id] as Transform3D).affine_inverse()
				for distance in _distances(inverse*st.position_world,inverse.basis*direction,_triangles(snapshot,part_id)):
					if distance <= maximum and inside(snapshot,st.position_world+direction*(distance+EPS*2)): entries.append(distance)
			entries.sort()
			return {"kind":"entry","distance_m":entries[0]} if not entries.is_empty() else {}
	if not at_inside:
		st.burst_target.clear(); return {}
	var remaining := maxf(0,INSIDE_PATH_M-(st.travelled_m-st.burst_entry_distance))
	var leave := exit_distance(snapshot,st.position_world,direction,maximum)
	if leave <= remaining+EPS and leave <= maximum:
		# Return a synthetic boundary so no later part of this segment can count as inside.
		return {"kind":"exit","distance_m":leave}
	if remaining <= maximum: return {"kind":"burst","distance_m":remaining}
	return {}
