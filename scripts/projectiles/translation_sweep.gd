class_name TranslationSweep
extends RefCounted
## Bounded constant-translation motion between adjacent authority snapshots.
## Geometry is unchanged: query endpoints move into each part's frame at the
## corresponding time. Rotation and discontinuities retain static end poses.

const MAX_TRANSLATION_M := 8.0
const MAX_INTERVAL_S := 0.1
const PREVIOUS_KEY := "motion_previous_transforms"

static func identity(snapshot: Dictionary) -> String:
	return JSON.stringify([snapshot.get("entity_id", ""), snapshot.get("life_id", 0),
		snapshot.get("target_generation", -1), snapshot.get("definition_id", ""),
		snapshot.get("layout_id", ""), snapshot.get("layout_revision", 0)])

static func bind(previous: Array, current: Array, adjacent: bool, delta: float) -> Array:
	var earlier := {}
	if adjacent and is_finite(delta) and delta > 0.0 and delta <= MAX_INTERVAL_S:
		for snapshot in previous:
			if snapshot is Dictionary:
				earlier[identity(snapshot)] = snapshot
	var result: Array = []
	for snapshot in current:
		if not snapshot is Dictionary:
			result.append(snapshot)
			continue
		var copy: Dictionary = snapshot.duplicate(true)
		copy.erase(PREVIOUS_KEY)
		var old: Dictionary = earlier.get(identity(copy), {})
		var prior := {}
		var diagnostics: Array[String] = []
		if not old.is_empty() and old.get("layout") == copy.get("layout"):
			var current_parts: Dictionary = copy.get("part_world_transforms", {})
			var old_parts: Dictionary = old.get("part_world_transforms", {})
			for part_id in current_parts:
				if not old_parts.has(part_id):
					continue
				var start: Transform3D = old_parts[part_id]
				var finish: Transform3D = current_parts[part_id]
				if not LayoutMath.is_rigid(start) or not LayoutMath.is_rigid(finish):
					continue
				if start.basis != finish.basis:
					diagnostics.append("motion: %s/%s rotation uses static end pose" % [copy.get("entity_id", ""), part_id])
				elif start.origin.distance_to(finish.origin) > MAX_TRANSLATION_M:
					diagnostics.append("motion: %s/%s displacement exceeds translation bound" % [copy.get("entity_id", ""), part_id])
				elif start.origin != finish.origin:
					prior[part_id] = start
		copy[PREVIOUS_KEY] = prior
		copy["motion_diagnostics"] = diagnostics
		result.append(copy)
	return result

static func part_transform(snapshot: Dictionary, part_id: String, fraction: float) -> Transform3D:
	var current: Transform3D = snapshot.part_world_transforms[part_id]
	var previous: Dictionary = snapshot.get(PREVIOUS_KEY, {})
	if not previous.has(part_id):
		return current
	var start: Transform3D = previous[part_id]
	return Transform3D(current.basis, start.origin.lerp(current.origin, fraction))

static func local_segment(snapshot: Dictionary, part_id: String, from: Vector3, to: Vector3, fractions: Vector2) -> PackedVector3Array:
	var start := part_transform(snapshot, part_id, fractions.x).affine_inverse() * from
	var finish := part_transform(snapshot, part_id, fractions.y).affine_inverse() * to
	return PackedVector3Array([start, finish, start.min(finish), start.max(finish)])

static func box_query(from: Vector3, to: Vector3, size: Vector3) -> Dictionary:
	# Equal-velocity projectile/target pairs can be stationary in the part frame.
	# Their clearly outside/inside occupancy is defined without inventing a
	# crossing or enlarging the box. Boundary uncertainty remains unresolved.
	if from.is_finite() and to.is_finite() and size.is_finite() and size.x > QueryGeometry.EPS_M and size.y > QueryGeometry.EPS_M and size.z > QueryGeometry.EPS_M and from.distance_to(to) <= QueryGeometry.EPS_M:
		var half := size * 0.5
		var inside := true
		for axis in 3:
			if minf(from[axis], to[axis]) > half[axis] + QueryGeometry.EPS_M or maxf(from[axis], to[axis]) < -half[axis] - QueryGeometry.EPS_M:
				return {"ok": true, "hit": false, "relation": "relative_stationary_outside"}
			inside = inside and maxf(absf(from[axis]), absf(to[axis])) < half[axis] - QueryGeometry.EPS_M
		if inside:
			return {"ok": true, "hit": true, "t_enter": 0.0, "t_exit": 1.0, "starts_inside": true,
				"grazing": false, "has_entry_boundary": false, "has_exit_boundary": false}
	return QueryGeometry.segment_box_local(from, to, size)

static func frame_at(snapshots: Array, fraction: float) -> Array:
	var result: Array = []
	for snapshot in snapshots:
		if not snapshot is Dictionary:
			continue
		var copy: Dictionary = snapshot.duplicate(true)
		for part_id in copy.get(PREVIOUS_KEY, {}):
			copy.part_world_transforms[part_id] = part_transform(snapshot, part_id, fraction)
		copy.erase(PREVIOUS_KEY)
		copy.erase("motion_diagnostics")
		result.append(copy)
	return result
