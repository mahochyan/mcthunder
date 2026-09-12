class_name BattleObjectives
extends RefCounted
## At most three independent zones. Owned seconds add to the existing ticket ledger.
const MAX_POINTS := 3
var points: Dictionary = {}

func configure(definitions: Array) -> bool:
	# Validate before replacing a running set; caller data is never retained by reference.
	if definitions.is_empty() or definitions.size() > MAX_POINTS: return false
	var candidate := {}
	for row in definitions:
		if not row is Dictionary: return false
		var id = row.get("id")
		var center = row.get("center")
		var radius = row.get("radius")
		if not id is String or id.is_empty() or candidate.has(id): return false
		if not center is Vector3 or not center.is_finite(): return false
		if not (radius is float or radius is int) or not is_finite(float(radius)) or radius <= 0: return false
		for existing in candidate.values():
			if Vector2(center.x,center.z).distance_to(Vector2(existing.center.x,existing.center.z)) <= float(radius)+existing.radius: return false
		candidate[id] = {"center":center,"radius":float(radius),"state":CapturePointState.new()}
	points = candidate
	return true

func step(match_state: TeamMatchState, occupants: Array, delta: float) -> Dictionary:
	var owned := {1:0.0,2:0.0}
	var player_seconds := 0.0
	if match_state.phase != "playing" or delta <= 0 or not is_finite(delta): return {"owned":owned,"player_seconds":0.0}
	for id in points:
		var point: Dictionary = points[id]
		var state: CapturePointState = point.state
		var teams: Array = []
		var player_inside := false
		for occupant in occupants:
			var offset: Vector3 = occupant.position-point.center
			# Excludes deep water / vehicles far above a zone; ground footprint remains horizontal.
			if absf(offset.y)>12 or Vector2(offset.x,offset.z).length()>point.radius: continue
			teams.append(occupant.team)
			if occupant.id == "A": player_inside = true
		var previous_owner := state.capture_owner
		var previous_contested := state.contested
		var duration := CapturePoint.step(state,teams,delta)
		for team in [1,2]: owned[team] += duration[team]
		if player_inside and not state.contested: player_seconds += delta
		if previous_owner != state.capture_owner:
			match_state.record("objective_owner",{"objective_id":id,"previous_owner":previous_owner,"owner":state.capture_owner})
		if previous_contested != state.contested:
			match_state.record("objective_contested",{"objective_id":id,"contested":state.contested})
	return {"owned":owned,"player_seconds":player_seconds}

func snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in points:
		var point: Dictionary = points[id]
		var state: CapturePointState = point.state
		rows.append({"id":id,"center":point.center,"radius":point.radius,"owner":state.capture_owner,"progress":state.capture_progress,"contested":state.contested})
	return rows
