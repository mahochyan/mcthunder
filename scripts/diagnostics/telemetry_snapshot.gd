class_name TelemetrySnapshot
extends RefCounted
## Diagnostic snapshots never feed battle decisions or player intelligence.
static func capture(scene: TeamRange) -> Dictionary:
	var live := 0
	var local_controllers := 0
	var ai_controllers := 0
	var vehicle_cameras := 0
	for actor in scene.combat_actors():
		if not actor.state.destroyed: live += 1
		if actor.controller is PlayerController: local_controllers += 1
		if actor.controller is AITankController: ai_controllers += 1
		if actor.cam_rig.cam.current: vehicle_cameras += 1
	return {"seconds":scene.director.state.elapsed,"phase":scene.director.state.phase,"actors":scene.combat_actors().size(),"live":live,"wrecks":scene.wrecks.count(),"projectiles":scene.projectiles.active_count(),"records":scene.projectiles.shot_records.count(),"accepted_shots":scene.projectiles._accepted_launches.size(),"local_controllers":local_controllers,"ai_controllers":ai_controllers,"vehicle_cameras":vehicle_cameras,"observer_camera":scene.spectator.current,"nodes":scene.get_tree().get_node_count(),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))}

static func frame_summary(samples_ms: PackedFloat64Array) -> Dictionary:
	if samples_ms.is_empty(): return {"count":0}
	var sorted := samples_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted: total += sample
	return {"count":sorted.size(),"mean_ms":total/sorted.size(),"fps_from_mean":sorted.size()*1000.0/total,"p50_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.50)-1)],"p95_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.95)-1)],"p99_ms":sorted[mini(sorted.size()-1,ceili(sorted.size()*0.99)-1)],"max_ms":sorted[-1]}
