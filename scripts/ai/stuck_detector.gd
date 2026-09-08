class_name StuckDetector
extends RefCounted
var elapsed := 0.0
var origin := Vector3.ZERO
var initialized := false
func reset(position: Vector3) -> void:
	elapsed = 0
	origin = position
	initialized = true
func observe(position: Vector3, wants_progress: bool, delta: float) -> bool:
	if not initialized or not wants_progress:
		reset(position)
		return false
	elapsed += delta
	if position.distance_to(origin) >= GameConfig.AI_STUCK_PROGRESS_M:
		reset(position)
		return false
	if elapsed >= GameConfig.AI_STUCK_WINDOW_S:
		reset(position)
		return true
	return false
