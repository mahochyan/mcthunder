class_name CapturePoint
extends RefCounted
## Returns exact owned durations; capture that finishes at the end of this step drains no earlier time.
static func step(state: TeamMatchState, teams: Array, delta: float) -> Dictionary:
	var owned := {1:0.0,2:0.0}
	if delta <= 0 or not is_finite(delta): return owned
	var unique := {}
	for team in teams:
		if team in [1,2]: unique[team] = true
	state.contested = unique.size()>1
	if unique.size() != 1:
		if state.capture_owner != 0: owned[state.capture_owner] = delta
		return owned
	var team: int = unique.keys()[0]
	var direction := 1.0 if team == 1 else -1.0
	var left := delta
	for stage in 3:
		if left <= 1e-8: break
		if is_equal_approx(state.capture_progress,direction):
			state.capture_owner = team
			owned[team] += left
			break
		var boundary := 0.0 if state.capture_owner != 0 and state.capture_owner != team else direction
		var duration := absf(boundary-state.capture_progress)*TeamMatchState.CAPTURE_SECONDS
		var used := minf(left,duration)
		if state.capture_owner != 0: owned[state.capture_owner] += used
		state.capture_progress = clampf(state.capture_progress+direction*used/TeamMatchState.CAPTURE_SECONDS,-1,1)
		left -= used
		if used >= duration-1e-8:
			state.capture_progress = boundary
			state.capture_owner = 0 if boundary == 0 else team
		else: break
	return owned
